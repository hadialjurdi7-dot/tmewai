# Windows release tooling

Everything that turns `flutter build windows --release` into a distributable,
stamped, (optionally) signed release lives here. The same script runs locally
and in CI — there is no second code path to keep in sync.

| File | Purpose |
| --- | --- |
| `release.ps1` | Four steps: `prepare`, `finalize`, `sign`, `verify` (+ `selftest`) |
| `pe-metadata.json` | VERSIONINFO written onto every shipped PE |
| `tmewai.iss` | Inno Setup 6 installer (per-user, no admin) |

```powershell
pwsh tool/windows/release.ps1 -Step prepare
flutter build windows --release
pwsh tool/windows/release.ps1 -Step finalize -RCEditPath C:\tools\rcedit-x64.exe
pwsh tool/windows/release.ps1 -Step sign                     # no-op without a cert
pwsh tool/windows/release.ps1 -Step verify                   # build gate
```

## Why VERSIONINFO matters for antivirus

`sqlite3.dll` as shipped by `package:sqlite3` has **no VERSIONINFO resource and
no Authenticode signature**. So does `dartjni.dll`, and so does
`flutter_windows.dll`. A folder containing an unsigned app plus three unsigned,
metadata-free native DLLs is exactly the shape Defender's ML classifier scores
as "dropped payload" — which is why `Trojan:Win32/Bearfoos.A!ml` was raised
against a byte-for-byte unmodified SQLite 3.54.1.

`finalize` stamps all four binaries. It does **not** touch code, sections,
linker flags or the SQLite version: `rcedit` only rewrites the `.rsrc` section.
The DLL hash therefore changes, but behaviour cannot.

Third-party binaries keep their **real** vendor identity (SQLite, Google,
dartjni). Stamping "Tmewai" onto Google's engine would be misattribution and
buys nothing — the AV signal is the *absence* of metadata, not the name in it.

`rcedit` is pinned and hash-verified in CI:

```
version 2.0.0
sha256  3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a
```

## Code signing

Without a certificate `-Step sign` prints a warning and exits 0: the release is
still built, hashed and published, but unsigned. `-Step verify` only requires a
signature when `TMEWAI_REQUIRE_SIGNATURE=true` (CI sets it from whether the
secret exists).

### What to buy

| | OV (organization validation) | EV (extended validation) |
| --- | --- | --- |
| Cost / year | roughly $200–400 | roughly $400–700 |
| Validation | business documents, 1–5 days | documents + phone + sometimes hardware |
| SmartScreen | **no** instant trust; starts at zero reputation and warms up over downloads | **instant** trust for the certificate's reputation |
| Defender/SmartScreen effect on a small app | warning for the first weeks; recovers as install counts rise | no warning from day one |
| Delivery | `.pfx` file (or token) | usually a hardware token / cloud HSM |

For an app with a few hundred users, OV + the Microsoft false-positive
submission (`security/av-false-positive/`) is the cheaper path: the FP report
fixes the *detection*, the OV certificate fixes *reputation* over time. Buy EV
only if "no SmartScreen warning on day one" is a hard requirement.

Do **not** buy a self-signed or "code signing" certificate from an untrusted
reseller: SmartScreen ignores it, and it actively annoys users because Windows
cannot chain it to a trusted root.

### Wiring the certificate

CI expects one of:

- **PFX in secrets** — `WINDOWS_CERT_PFX_BASE64` (base64 of the `.pfx`) and
  `WINDOWS_CERT_PASSWORD`. Convert on Windows:
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\cert\tmewai.pfx')) | Set-Clipboard
  ```
- **Thumbprint + hardware token / machine store** — `WINDOWS_CERT_THUMBPRINT`.
  Only works on a runner that already has the token or the imported cert, i.e.
  a self-hosted runner; a GitHub-hosted runner will not see your token.

Local use:

```powershell
$env:WINDOWS_CERT_PFX      = 'C:\cert\tmewai.pfx'
$env:WINDOWS_CERT_PASSWORD = '...'
pwsh tool/windows/release.ps1 -Step sign
```

Never commit a `.pfx`, its password, or a base64 blob of either. `.gitignore`
already excludes `*.pfx`; the `security/` folder is docs only.

Timestamping (`/tr http://timestamp.digicert.com /td SHA256`) is mandatory:
without it the signature dies when the certificate expires.

### Verifying

```powershell
pwsh tool/windows/release.ps1 -Step verify -RequireSignature
signtool verify /pa /all build\windows\x64\runner\Release\*.exe
```

## Installer: Inno Setup, not MSIX

MSIX requires the *package* to be signed by a certificate the machine already
trusts. A self-signed MSIX is worse than an unsigned `.exe`, because the user
must install a root certificate by hand before Windows will open the file.
An Authenticode-signed Inno installer is a single `.exe`, installs per-user
into `%LOCALAPPDATA%\Programs\tmewai` with no UAC prompt, and inherits the
certificate's reputation. Revisit MSIX when there is an EV certificate **and**
a Store listing.

## Reproducibility, honestly

`sqlite3.dll` is not compiled here: `package:sqlite3` downloads a prebuilt
library from `simolus3/sqlite3.dart` releases and verifies it against a SHA-256
pinned in the package (`sqlite3.x64.windows.dll`,
`3a29878d…b590` in 3.8.0). That is why the hash was identical across v0.2.1 and
v0.3.0 — same package version, same file.

Two consequences:

1. The binary is byte-stable for as long as the pinned
   `sqlite3` version is unchanged, verified upstream with SLSA level 3
   attestations (`gh attestation verify --repo simolus3/sqlite3.dart`).
2. After we stamp VERSIONINFO and add an RFC 3161 timestamp, the shipped bytes
   differ on every release by design. "One whitelist hash for every future
   build" is therefore not achievable while signing; what stays stable is the
   **pre-stamp source hash** the FP report references.

## Local self-check

`pwsh tool/windows/release.ps1 -Step selftest` runs the platform-independent
logic (version mapping, hash-list formatting, metadata token substitution) and
works on Linux/macOS too — useful in CI before the Windows job.
