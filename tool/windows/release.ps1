# Release pipeline for the Windows x64 build.
#
# One script, four steps, so the same code runs on a developer machine and in
# CI (.github/workflows/release-windows.yml). Every step is idempotent.
#
#   pwsh tool/windows/release.ps1 -Step prepare    # flutter create runner + rename to tmewai
#   pwsh tool/windows/release.ps1 -Step finalize   # VERSIONINFO on every shipped PE + hashes + zip
#   pwsh tool/windows/release.ps1 -Step sign       # Authenticode (needs a certificate, see README)
#   pwsh tool/windows/release.ps1 -Step verify     # build gate: metadata present, signature valid
#   pwsh tool/windows/release.ps1 -Step selftest   # platform-independent checks (runs on Linux too)
#
# Signing is skipped, loudly, when no certificate is configured. Nothing here
# ever touches Defender, the AV exclusion list, or packs/compresses a binary.

[CmdletBinding()]
param(
    [ValidateSet('prepare', 'finalize', 'sign', 'verify', 'selftest')]
    [string]$Step = 'finalize',

    [string]$ReleaseDir = 'build/windows/x64/runner/Release',
    [string]$OutDir = 'dist',
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$MetadataPath = (Join-Path $PSScriptRoot 'pe-metadata.json'),

    # prepare
    [string]$Org = 'com.tmewai',

    # finalize
    [string]$RCEditPath = '',
    [string]$AppVersion = '',
    [switch]$NoStamp,
    [switch]$NoZip,

    # sign / verify
    [string]$CertificatePfx = $env:WINDOWS_CERT_PFX,
    [string]$CertificatePassword = $env:WINDOWS_CERT_PASSWORD,
    [string]$CertificateThumbprint = $env:WINDOWS_CERT_THUMBPRINT,
    [string]$TimestampUrl = 'http://timestamp.digicert.com',
    [switch]$RequireSignature
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProductName = 'Tmewai'
$ExeName = 'tmewai.exe'

# CI sets this from whether a certificate was found; keeps the workflow free of
# PowerShell boolean quirks (-RequireSignature:$true vs :True).
if ($env:TMEWAI_REQUIRE_SIGNATURE -eq 'true') { $RequireSignature = $true }

function Write-Step($text) { Write-Host "`n=== $text" -ForegroundColor Cyan }

# -ReleaseDir may be absolute (CI) or repo-relative (developer).
function Resolve-ReleaseDir {
    if ([System.IO.Path]::IsPathRooted($ReleaseDir)) { return $ReleaseDir }
    return (Join-Path $ProjectRoot $ReleaseDir)
}

# ---------------------------------------------------------------- versioning

# pubspec carries "0.3.4+8"; PE FILEVERSION wants four 16-bit integers.
function ConvertTo-FileVersion([string]$Version) {
    if ([string]::IsNullOrWhiteSpace($Version)) { throw 'empty version' }
    $split = $Version -split '\+', 2
    $main = $split[0]
    $build = if ($split.Count -gt 1) { $split[1] } else { '0' }
    $parts = @($main -split '\.')
    while ($parts.Count -lt 3) { $parts += '0' }
    $numbers = @()
    foreach ($p in @($parts[0], $parts[1], $parts[2], $build)) {
        $n = 0
        if (-not [int]::TryParse(($p -replace '[^0-9].*$', ''), [ref]$n)) { $n = 0 }
        $numbers += [Math]::Min([Math]::Max($n, 0), 65535)
    }
    return ($numbers -join '.')
}

function ConvertTo-MarketingVersion([string]$Version) {
    return (($Version -split '\+', 2)[0])
}

function Get-PubspecVersion {
    $pubspec = Join-Path $ProjectRoot 'pubspec.yaml'
    $match = Select-String -Path $pubspec -Pattern '^version:\s*(\S+)' | Select-Object -First 1
    if (-not $match) { throw "no version: line in $pubspec" }
    return $match.Matches[0].Groups[1].Value.Trim()
}

# ------------------------------------------------------------------ prepare

function Step-Prepare {
    Write-Step 'prepare: generate the Windows runner'
    Push-Location $ProjectRoot
    try {
        # windows/ is generated, never committed: flutter create is the source of
        # truth for the runner skeleton and the engine-specific CMake glue.
        & flutter create --platforms=windows --project-name personal_data_agent --org $Org .
        if ($LASTEXITCODE -ne 0) { throw "flutter create failed ($LASTEXITCODE)" }

        # flutter create names the binary after the Dart package.
        Get-ChildItem -Path (Join-Path $ProjectRoot 'windows') -Recurse -File |
            Where-Object { $_.Extension -in '.txt', '.cpp', '.h', '.rc', '.manifest', '.tmpl' } |
            ForEach-Object {
                $text = Get-Content -Raw -LiteralPath $_.FullName
                if ($text -match 'personal_data_agent') {
                    $text.Replace('personal_data_agent', 'tmewai') | Set-Content -NoNewline -LiteralPath $_.FullName
                }
            }
        $mainCpp = Join-Path $ProjectRoot 'windows/runner/main.cpp'
        if (Test-Path $mainCpp) {
            (Get-Content -Raw -LiteralPath $mainCpp).Replace('L"tmewai"', 'L"Tmewai"') |
                Set-Content -NoNewline -LiteralPath $mainCpp
        }
        $icon = Join-Path $ProjectRoot 'assets/branding/tmewai.ico'
        $iconTarget = Join-Path $ProjectRoot 'windows/runner/resources/app_icon.ico'
        if ((Test-Path $icon) -and (Test-Path (Split-Path $iconTarget))) { Copy-Item $icon $iconTarget -Force }
        Write-Host 'runner prepared'
    }
    finally { Pop-Location }
}

# ------------------------------------------------------------------ hashing

function Get-Sha256Sums([string]$Root) {
    $lines = Get-ChildItem -Path $Root -Recurse -File |
        Sort-Object { $_.FullName.Substring($Root.Length).Replace('\', '/') } |
        ForEach-Object {
            $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
            '{0} *{1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $rel
        }
    return @($lines)
}

# ----------------------------------------------------------------- metadata

function Get-PeMetadata([string]$Version) {
    $raw = Get-Content -Raw -LiteralPath $MetadataPath | ConvertFrom-Json
    $tokens = @{
        '{version}'        = $Version
        '{marketing}'      = (ConvertTo-MarketingVersion $Version)
        '{fileVersion}'    = (ConvertTo-FileVersion $Version)
        '{shortVersion}'   = (ConvertTo-FileVersion $Version).Substring(0, (ConvertTo-FileVersion $Version).LastIndexOf('.'))
    }
    $resolved = [ordered]@{}
    foreach ($entry in $raw.files.PSObject.Properties) {
        $fields = [ordered]@{}
        foreach ($field in $entry.Value.PSObject.Properties) {
            $value = [string]$field.Value
            foreach ($k in $tokens.Keys) { $value = $value.Replace($k, $tokens[$k]) }
            $fields[$field.Name] = $value
        }
        $resolved[$entry.Name] = $fields
    }
    return $resolved
}

function Find-RCEdit {
    if ($RCEditPath -and (Test-Path $RCEditPath)) { return (Resolve-Path $RCEditPath).Path }
    $onPath = Get-Command rcedit-x64.exe, rcedit.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    throw 'rcedit not found: pass -RCEditPath (CI downloads a pinned build) — see tool/windows/README.md'
}

function Set-PeVersionInfo([string]$File, [System.Collections.IDictionary]$Fields) {
    $rcedit = Find-RCEdit
    $stringFields = @('CompanyName', 'FileDescription', 'InternalName', 'LegalCopyright',
                      'OriginalFilename', 'ProductName')
    $argList = @($File)
    foreach ($name in $stringFields) { if ($Fields.Contains($name)) { $argList += @('--set-version-string', $name, $Fields[$name]) } }
    if ($Fields.Contains('FileVersion')) { $argList += @('--set-file-version', $Fields['FileVersion']) }
    if ($Fields.Contains('ProductVersion')) { $argList += @('--set-product-version', $Fields['ProductVersion']) }
    & $rcedit @argList | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "rcedit failed on $File ($LASTEXITCODE)" }
}

# ---------------------------------------------------------------- finalize

function Step-Finalize {
    Write-Step 'finalize: VERSIONINFO + hashes + archive'
    $release = Resolve-ReleaseDir
    if (-not (Test-Path $release)) { throw "release folder not found: $release (run flutter build windows --release)" }

    $version = if ($AppVersion) { $AppVersion } else { Get-PubspecVersion }
    Write-Host "version: $version  ->  file version $((ConvertTo-FileVersion $version))"

    if (-not $NoStamp) {
        $metadata = Get-PeMetadata $version
        foreach ($name in $metadata.Keys) {
            $file = Join-Path $release $name
            if (-not (Test-Path $file)) { Write-Host "skip (not shipped): $name" -ForegroundColor DarkYellow; continue }
            Set-PeVersionInfo -File $file -Fields $metadata[$name]
            Write-Host "stamped $name"
        }
    }
    else { Write-Host 'stamping skipped (-NoStamp)' }

    $out = Join-Path $ProjectRoot $OutDir
    New-Item -ItemType Directory -Force -Path $out | Out-Null

    $sums = Get-Sha256Sums $release
    $sumsPath = Join-Path $out 'SHA256SUMS.txt'
    Set-Content -LiteralPath $sumsPath -Value $sums -Encoding utf8
    Write-Host "wrote $sumsPath ($($sums.Count) files)"

    if ($NoZip) { Write-Host 'archive skipped (-NoZip)'; return }

    $zip = Join-Path $out 'tmewai-windows-x64.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zip -CompressionLevel Optimal
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    Add-Content -LiteralPath $sumsPath -Value ('{0} *{1}' -f $zipHash, (Split-Path -Leaf $zip)) -Encoding utf8
    Write-Host "wrote $zip ($zipHash)"
}

# -------------------------------------------------------------------- sign

function Get-SignTool {
    $candidates = @()
    if ($env:SIGNTOOL_PATH) { $candidates += $env:SIGNTOOL_PATH }
    $kits = @("${env:ProgramFiles(x86)}\Windows Kits\10\bin", "$env:ProgramFiles\Windows Kits\10\bin")
    foreach ($kit in $kits) {
        if (Test-Path $kit) {
            $candidates += Get-ChildItem -Path $kit -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending | ForEach-Object { $_.FullName }
        }
    }
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    $onPath = Get-Command signtool.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    throw 'signtool.exe not found — install the Windows SDK or set SIGNTOOL_PATH'
}

function Invoke-Sign {
    $release = Resolve-ReleaseDir
    $files = Get-ChildItem -Path $release -Recurse -File | Where-Object { $_.Extension -in '.exe', '.dll' }
    if (-not $files) { throw "nothing to sign in $release" }

    $signtool = Get-SignTool
    $identity = @('/fd', 'SHA256', '/tr', $TimestampUrl, '/td', 'SHA256')
    if ($CertificatePfx) {
        if (-not (Test-Path $CertificatePfx)) { throw "PFX not found: $CertificatePfx" }
        $identity += @('/f', $CertificatePfx)
        if ($CertificatePassword) { $identity += @('/p', $CertificatePassword) }
    }
    elseif ($CertificateThumbprint) {
        $identity += @('/sha1', $CertificateThumbprint)
    }
    else {
        Write-Warning 'No certificate configured (WINDOWS_CERT_PFX / WINDOWS_CERT_THUMBPRINT). Skipping signing.'
        Write-Warning 'The build stays unsigned until a code-signing certificate is available: see tool/windows/README.md'
        return
    }

    foreach ($f in $files) {
        Write-Host "sign $($f.Name)"
        & $signtool sign @identity /v $f.FullName
        if ($LASTEXITCODE -ne 0) { throw "signtool sign failed on $($f.Name) ($LASTEXITCODE)" }
    }
}

# ------------------------------------------------------------------ verify

function Step-Verify {
    Write-Step 'verify: build gate'
    $release = Resolve-ReleaseDir
    if (-not (Test-Path $release)) { throw "release folder not found: $release" }
    $version = if ($AppVersion) { $AppVersion } else { Get-PubspecVersion }
    $metadata = Get-PeMetadata $version
    $required = @('CompanyName', 'ProductName', 'FileVersion', 'FileDescription', 'InternalName',
                  'OriginalFilename', 'LegalCopyright', 'ProductVersion')
    $failures = @()
    $shipped = @()

    foreach ($f in Get-ChildItem -Path $release -Recurse -File | Where-Object { $_.Extension -in '.exe', '.dll' }) {
        $shipped += $f.Name
        $info = (Get-Item -LiteralPath $f.FullName).VersionInfo
        if (-not $info.FileVersion) { $failures += "$($f.Name): no VERSIONINFO resource"; continue }
        foreach ($field in $required) {
            if ([string]::IsNullOrWhiteSpace($info.$field)) { $failures += "$($f.Name): $field is empty" }
        }
        if ($f.Name -eq $ExeName -and $info.CompanyName -match 'example') {
            $failures += "${ExeName}: CompanyName still the flutter default ($($info.CompanyName))"
        }
        if ($RequireSignature) {
            $signtool = Get-SignTool
            & $signtool verify /pa /all $f.FullName | Out-Null
            if ($LASTEXITCODE -ne 0) { $failures += "$($f.Name): signature missing or invalid" }
        }
    }

    foreach ($expected in $metadata.Keys) {
        if ($shipped -notcontains $expected) { $failures += "expected $expected in the release folder but it is absent" }
    }
    if ($RequireSignature -and -not ($CertificatePfx -or $CertificateThumbprint)) {
        $failures += 'RequireSignature set but no certificate was configured, so nothing was signed'
    }

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
        throw "$($failures.Count) release check(s) failed"
    }
    Write-Host "OK — $($shipped.Count) binaries carry complete metadata$(if ($RequireSignature) { ' and valid signatures' })" -ForegroundColor Green
}

# ----------------------------------------------------------------- self-test

function Step-SelfTest {
    Write-Step 'selftest'
    $cases = @{
        '0.3.4+8'     = '0.3.4.8'
        '1.0.0'       = '1.0.0.0'
        '2.10+17'     = '2.10.0.17'
        '0.2.1+3'     = '0.2.1.3'
    }
    foreach ($sample in $cases.Keys) {
        $got = ConvertTo-FileVersion $sample
        if ($got -ne $cases[$sample]) { throw "ConvertTo-FileVersion('$sample') = '$got', expected '$($cases[$sample])'" }
    }
    if ((ConvertTo-MarketingVersion '0.3.4+8') -ne '0.3.4') { throw 'ConvertTo-MarketingVersion failed' }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tmewai-selftest-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        New-Item -ItemType Directory -Path (Join-Path $tmp 'data') | Out-Null
        Set-Content -LiteralPath (Join-Path $tmp 'a.dll') -Value 'x' -NoNewline
        Set-Content -LiteralPath (Join-Path $tmp 'data/b.bin') -Value 'y' -NoNewline
        $sums = Get-Sha256Sums $tmp
        if ($sums.Count -ne 2) { throw "expected 2 hashed files, got $($sums.Count)" }
        if (-not ($sums[0] -match '^[0-9a-f]{64} \*(a\.dll|data/b\.bin)$')) { throw "bad sums line: $($sums[0])" }
        if (-not (($sums -join "`n") -match 'data/b\.bin')) { throw 'nested path not recorded with forward slashes' }
    }
    finally { Remove-Item -Recurse -Force $tmp }

    $metadata = Get-PeMetadata '0.3.4+8'
    if ($metadata['tmewai.exe']['FileVersion'] -ne '0.3.4.8') { throw 'token substitution failed for {fileVersion}' }
    if ($metadata['sqlite3.dll']['ProductVersion'] -ne '3.54.1') { throw 'sqlite3 ProductVersion should stay pinned to 3.54.1' }
    Write-Host 'selftest passed' -ForegroundColor Green
}

switch ($Step) {
    'prepare' { Step-Prepare }
    'finalize' { Step-Finalize }
    'sign' { Invoke-Sign }
    'verify' { Step-Verify }
    'selftest' { Step-SelfTest }
}
