# Build the upload package for a false-positive submission.
#
#   pwsh security/av-false-positive/collect-evidence.ps1 `
#        -ReleaseDir build/windows/x64/runner/Release `
#        -Version 0.3.4
#
# Writes out/tmewai-av-fp-<version>.zip containing the flagged DLL, the hashes
# file, the analysis text and the Defender engine/signature versions of this
# machine, which is what the analyst needs to reproduce the verdict.

[CmdletBinding()]
param(
    [string]$ReleaseDir = 'build/windows/x64/runner/Release',
    [string]$Version = '',
    [string]$OutDir = 'out'
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $Version) {
    $pubspec = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'pubspec.yaml'
    $Version = (Select-String -Path $pubspec -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
    $Version = ($Version -split '\+')[0]
}

$dll = Join-Path $ReleaseDir 'sqlite3.dll'
if (-not (Test-Path $dll)) { throw "sqlite3.dll not found in $ReleaseDir — build the release first" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stage = Join-Path $OutDir ("fp-stage-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item $dll $stage
Copy-Item (Join-Path $here 'analysis.md') $stage
Copy-Item (Join-Path $here 'RELEASE_HASHES.txt') $stage

$hash = (Get-FileHash $dll -Algorithm SHA256).Hash.ToLowerInvariant()
$engineInfo = try {
    Get-MpComputerStatus | Select-Object AMEngineVersion, AntivirusSignatureVersion, AntivirusSignatureLastUpdated |
        Format-List | Out-String
} catch { "Defender status unavailable: $($_.Exception.Message)" }

@"
Tmewai false-positive evidence
version           $Version
file              sqlite3.dll
size              $((Get-Item $dll).Length) bytes
sha256            $hash
submitted         $(Get-Date -Format o)

Defender on this machine
$engineInfo
"@ | Set-Content (Join-Path $stage 'MACHINE.txt') -Encoding utf8

$zip = Join-Path $OutDir "tmewai-av-fp-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
Remove-Item -Recurse -Force $stage

Write-Host "package ready: $zip"
Write-Host "sha256: $((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Host 'Upload it at https://www.microsoft.com/en-us/wdsi/filesubmission ("software developer" persona).'
