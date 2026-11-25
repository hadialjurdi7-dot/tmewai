# Analysis: `sqlite3.dll` in the Tmewai Windows release

Submission text for Microsoft (paste as-is into the false-positive form).

## Summary

`sqlite3.dll` from Tmewai for Windows x64 is flagged as
`Trojan:Win32/Bearfoos.A!ml` (ThreatID 2147731250). The file is **not our code**:
it is an unmodified SQLite 3.54.1 shared library produced by the
`sqlite3` Dart package's release pipeline, whose SHA-256 is pinned inside the
package source. The identical bytes ship in every Dart/Flutter desktop
application that depends on `sqlite3` 3.8.0.

`!ml` denotes a machine-learning heuristic, not a signature of known malware.
The classifier is reacting to packaging signals — an unsigned DLL with no
VERSIONINFO resource sitting next to an unsigned executable — not to behaviour.

## File under report

```
name      sqlite3.dll
size      1,729,024 bytes
sha256    3a29878d0936510af0f563dfc7668c561c92f7ebe1d9fef95975f721dc01b590
machine   AMD64 (0x8664)
subsystem Windows GUI (2)
linker    14.51  (MSVC 2022 toolchain)
sections  .text (1,396,736)  .rdata (235,520)  .data (27,136)
          .pdata (62,976)    .fptable (512)    .reloc (5,120)
imports   KERNEL32.dll   (only import)
exports   343, all sqlite3_* / sqlite3session_* / sqlite3changeset_* / sqlite3_preupdate_*
resource dir none   (this is why there is no VERSIONINFO at all)
TLS / overlay none  (resource directory, TLS directory, delay imports and
                     appended data are all empty; 0 bytes past the last section)
checksum      0
Authenticode  none (security directory size 0)
```

The only loader APIs imported are `LoadLibraryW`, `LoadLibraryExW` and
`GetProcAddress` — standard static-CRT startup/encoding paths. There is no
network stack (`WS2_32`/`WININET`/`WINHTTP` absent), no process manipulation
(`VirtualAllocEx`, `WriteProcessMemory`, `CreateRemoteThread` absent), no shell
or persistence APIs (`WinExec`, `ShellExecute`, `CreateProcess`,
`RegSetValue*` absent), and no packed or encrypted section — `.text` entropy is
6.53 bits/byte, 6.04 for `.rdata`: ordinary compiled C, not packed data (packers
push this above 7.5). Reading `.rdata` yields the SQLite version banner
`3.54.1` and the source id `2026-10-16 14:45:20 555e07ef33f69a0957d24d8e555b702464a131d6`,
which is SQLite's own build stamp.

## Provenance

1. `pubspec.lock` pins `sqlite3` **3.8.0** (sha256
   `5340531ad17f386ae444873f643f281060b6238cc702edeee6b1e90bc4c6874e`).
2. The package ships prebuilt binaries and verifies each download against a hash
   compiled into `lib/src/hook/asset_hashes.dart`. For the Windows x64 asset:

   ```
   'sqlite3.x64.windows.dll': '3a29878d0936510af0f563dfc7668c561c92f7ebe1d9fef95975f721dc01b590'
   ```

   That is byte-for-byte the reported file.
3. Those assets are built in GitHub Actions from upstream sqlite.org sources by
   `simolus3/sqlite3.dart`, published as immutable releases with SLSA level 3
   provenance attestations:
   `gh attestation verify --repo simolus3/sqlite3.dart sqlite3.dll`.
4. Compile-time options (from the package docs): `SQLITE_ENABLE_FTS5`,
   `SQLITE_ENABLE_RTREE`, `SQLITE_ENABLE_MATH_FUNCTIONS`, `SQLITE_ENABLE_SESSION`,
   `SQLITE_ENABLE_PREUPDATE_HOOK`, `SQLITE_ENABLE_DBSTAT_VTAB`, `SQLITE_DQS=0`,
   `SQLITE_OMIT_DEPRECATED`, `SQLITE_OMIT_SHARED_CACHE`, `SQLITE_THREADSAFE` default
   (serialized). None of these are malware-relevant; FTS5 is the full-text index
   the application actually uses.

## Why the same hash appears in many releases

Upstream pins one binary per (package version, architecture). Applications that
did not change the `sqlite3` dependency ship the exact same file — which is why
the hash was identical across Tmewai v0.2.1, v0.3.0 and every later build, and
why the detection is not specific to this application.

## What changed on our side (and why it should lower the score)

Starting with the next release every shipped PE carries a VERSIONINFO resource
(CompanyName, ProductName, FileVersion, FileDescription, OriginalFilename,
LegalCopyright) and, once a code-signing certificate is available, an
Authenticode signature with an RFC 3161 timestamp. Code, sections and the SQLite
version are untouched — only the `.rsrc` section is rewritten.

## Request

Reclassify `3a29878d0936510af0f563dfc7668c561c92f7ebe1d9fef95975f721dc01b590`
as clean / remove the `Trojan:Win32/Bearfoos.A!ml` classification for this file,
in the current definition set. Please also confirm the definition version that
carries the correction so we can verify on our side.
