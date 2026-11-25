# False positive report pack — `Trojan:Win32/Bearfoos.A!ml` on `sqlite3.dll`

Everything needed to get Microsoft to fix a heuristic detection against an
**unmodified upstream SQLite binary** that we merely redistribute.

- Detection: `Trojan:Win32/Bearfoos.A!ml` — **ThreatID 2147731250**
- File: `sqlite3.dll`, 1,729,024 bytes
- SHA-256: `3a29878d0936510af0f563dfc7668c561c92f7ebe1d9fef95975f721dc01b590`
- Verdict: false positive. The file is byte-identical to the asset published by
  `package:sqlite3` 3.8.0, whose SHA-256 is pinned in the package source.

## Where to submit

1. **Microsoft Security Intelligence — file submission** (the form that reaches
   the antimalware team):
   <https://www.microsoft.com/en-us/wdsi/filesubmission>
   Choose **"I am a software developer"** / "Submit for analysis", then
   **"Report incorrect detection"**, and attach:
   - `sqlite3.dll` itself (or `tmewai-windows-x64.zip`, see `collect-evidence.ps1`)
   - `analysis.md` content pasted into the description box
   - the URL of this folder in the public repository
2. **Defender for Endpoint portal** (if the tenant has it):
   Security portal → *Reports → Submission* is the same queue, faster if you
   are an enterprise customer.
3. **SmartScreen / reputation** is a different system: no form, only a
   certificate plus download volume. See `tool/windows/README.md`.

Turnaround is normally 24–72 h for a heuristic (`!ml`) detection. Microsoft
ships corrected signatures within hours of the analyst agreeing.

## What to put in the description box

Use the text of [`analysis.md`](analysis.md) verbatim — it is written to be
pasted as-is: what the file is, where it comes from, why the hash is provable,
and what it does *not* contain (no VERSIONINFO, but also no packer, no network
imports, no injector behaviour).

## After every SQLite upgrade

Microsoft whitelists per-file, so a new `sqlite3.dll` (new hash) is a new
subject. `followup-template.md` is the short form to send again; the analysis
only needs updating for the version and source-id lines.

## Evidence files

| File | What it proves |
| --- | --- |
| `analysis.md` | Technical analysis of the flagged binary (imports, exports, sections, provenance) |
| `RELEASE_HASHES.txt` | Hashes of the exact published archive and every file in it |
| `followup-template.md` | Re-submission text for future SQLite bumps |
| `collect-evidence.ps1` | Builds the upload zip from a local release folder |

## Reproducing the detection

```powershell
# 1. build the app the way users get it
flutter pub get
flutter build windows --release

# 2. the flagged file is at the root of the release folder
Get-FileHash build\windows\x64\runner\Release\sqlite3.dll -Algorithm SHA256
# 3a29878d0936510af0f563dfc7668c561c92f7ebe1d9fef95975f721dc01b590

# 3. ask Defender what it thinks
Get-MpThreatDetection | Where-Object { $_.ThreatID -eq 2147731250 }
# record AMEngineVersion / AntivirusSignatureVersion from:
Get-MpComputerStatus | Select-Object AMEngineVersion, AntivirusSignatureVersion
```

Report the **signature version** in the submission: the analyst needs to know
which definition set produced the detection, and a re-check after the fix is
only meaningful against a newer set.
