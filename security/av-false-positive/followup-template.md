# Re-submission template (after a SQLite / sqlite3 package upgrade)

Every new `sqlite3.dll` is a new hash, so a fix for one file does not cover the
next. Send this short form each time the dependency moves, instead of the full
analysis.

---

**Subject:** False positive re-report — `sqlite3.dll` (new hash), same upstream
component

We previously reported `Trojan:Win32/Bearfoos.A!ml` (ThreatID 2147731250) against
`sqlite3.dll`, an unmodified SQLite build redistributed by the `sqlite3` Dart
package. That file was cleared. Our next release ships a newer build of the same
upstream library and needs the same treatment.

```
file        sqlite3.dll
size        {{SIZE}} bytes
sha256      {{SHA256}}
sqlite      {{SQLITE_VERSION}}   (source id {{SOURCE_ID}})
package     sqlite3 {{PACKAGE_VERSION}}  (pinned asset hash matches our file)
detection   {{DETECTION_NAME}}   ThreatID {{THREAT_ID}}
signature   {{SIGNATURE_VERSION}} on Windows {{WINDOWS_VERSION}}
```

The file is byte-identical to the asset published by
`simolus3/sqlite3.dart` (verifiable: the SHA-256 is compiled into
`lib/src/hook/asset_hashes.dart` of the package version above, and the release
carries SLSA level 3 attestations — `gh attestation verify --repo
simolus3/sqlite3.dart`).

Same profile as the previously cleared file: AMD64 DLL, single import
(KERNEL32), ~340 `sqlite3_*` exports, no network/process/shell APIs, no packer,
no overlay. Our application only calls it through the public SQLite API.

Please reclassify as clean and confirm the definition version that carries the
correction.

---

Fill the placeholders from:

```powershell
Get-FileHash build\windows\x64\runner\Release\sqlite3.dll -Algorithm SHA256
Get-MpComputerStatus | Select-Object AntivirusSignatureVersion
(Get-Item build\windows\x64\runner\Release\sqlite3.dll).Length
```

`SQLITE_VERSION` / `SOURCE_ID` are the strings in `.rdata`
(`strings sqlite3.dll | Select-String '^\d\.\d+\.\d+$'` and the
`20xx-xx-xx xx:xx:xx <40 hex>` banner). `PACKAGE_VERSION` comes from
`pubspec.lock`.
