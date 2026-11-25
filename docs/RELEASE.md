# Release Guide

How a version of Tmewai goes from a tagged commit to a downloadable
Windows build, and what to do if a release goes wrong.

Release builds run on GitHub-hosted Windows runners. Nothing in the workflow sends
user data anywhere: the runner compiles the app and uploads the resulting build
folder to a GitHub Release.

## Before tagging

1. Confirm the branch is green locally:
   ```sh
   export PATH=$FLUTTER_ROOT/bin:$PATH
   flutter pub get
   flutter analyze        # No issues found!
   flutter test           # All tests passed!
   ```
2. Bump `version:` in `pubspec.yaml` (for example `0.2.0+2`) and update
   `CHANGELOG.md` with the same version.
3. Merge the release commit to the default branch. The tag must point at a commit
   that already contains the version bump and the changelog entry.

## Cutting a release

1. Tag the release commit and push the tag (maintainers only):
   ```sh
   git tag -a v0.2.0 -m "v0.2.0"
   git push origin v0.2.0
   ```
   The tag name must start with `v`; it is used verbatim in the artifact name.
2. The tag push starts **Release Windows x64**
   (`.github/workflows/release-windows.yml`). The job checks out the source,
   sets up Flutter stable, generates the Windows runner, runs analyze and tests,
   builds `--release`, and zips `build/windows/x64/runner/Release/` into
   `tmewia-<tag>-windows-x64.zip`.
3. The workflow then publishes a public GitHub Release for that tag with
   auto-generated release notes and the ZIP attached. The runner needs
   `contents: write`; if releases fail with a permissions error, check
   **Repository Settings → Actions → General → Workflow permissions**.
4. To retry without a new tag, run the workflow manually from the Actions tab
   (`workflow_dispatch`) on the tagged ref.

## Verifying a release

1. Open the repository's **Releases** page and confirm the release, the
   `tmewai-X.Y.Z-setup.exe` installer, the portable ZIP and `SHA256SUMS.txt`
   are listed for the expected tag.
2. Download `tmewai-windows-x64.zip`, extract it to a clean folder, and confirm
   `tmewai.exe` plus the neighbouring DLLs and `data` folder are present.
   The build is a portable folder; the installer is the same folder, copied
   into `%LOCALAPPDATA%\Programs\tmewai`.
3. Check the binaries carry metadata and (when a certificate is configured) a
   valid signature — this is what the `Gate` step of the workflow asserts:
   ```powershell
   pwsh tool/windows/release.ps1 -Step verify
   signtool verify /pa /all build\windows\x64\runner\Release\*.dll
   ```
4. Launch the executable and check the main flows: opening a workspace, importing
   a synthetic or de-identified export, search, timeline, overview, settings, and
   switching between Arabic and English.
5. Confirm the release asset name matches the tag and that the changelog entry for
   that version is accurate. Do not attach real personal data, databases, keys or
   test exports to a release.

## Windows binary metadata, signing and antivirus

The release pipeline is `tool/windows/release.ps1` (see
[its README](../tool/windows/README.md) for the certificate setup and the
OV-vs-EV tradeoff):

- `prepare` generates the Windows runner and renames the binary to `tmewai.exe`.
- `finalize` writes VERSIONINFO onto every shipped PE (`tmewai.exe`,
  `sqlite3.dll`, `dartjni.dll`, `flutter_windows.dll`) and emits
  `SHA256SUMS.txt` plus the ZIP.
- `sign` runs `signtool sign /fd SHA256 /tr <timestamp> /td SHA256` over every
  `.exe` and `.dll`, and is skipped with a warning when no certificate is set.
- `verify` is the build gate: missing metadata fails the build, and a missing
  signature fails it too once signing is configured.

Antivirus false positives are handled outside the build:
`security/av-false-positive/` holds the evidence pack and the report filed with
Microsoft. Re-file the short template there after any `sqlite3` upgrade, because
Microsoft clears per file hash, not per product.


## Rollback

A published release can be withdrawn without deleting history:

1. Edit the GitHub Release and mark it as a draft (or delete the release). The tag
   and its commit stay intact, so the code that shipped is still auditable.
2. If the tag itself was wrong, delete it explicitly and re-tag the correct commit:
   ```sh
   git tag -d v0.2.0
   git push origin :refs/tags/v0.2.0
   git tag -a v0.2.0 -m "v0.2.0" <correct-commit>
   git push origin v0.2.0
   ```
   Only do this before users depend on the tag; never move a tag that has already
   been downloaded widely.
3. For a bad build with a good commit, publish a follow-up patch version
   (for example `0.2.1+3`) rather than replacing the existing asset.
4. Re-run `flutter analyze` and `flutter test` on the reverted commit before
   tagging again.

## Open decision: LICENSE

The project does not ship a `LICENSE` file yet. This is deliberate: choosing a
license is a legal decision, not a repository chore.

- **Apache-2.0** is permissive, includes an explicit patent grant, and is friendly
  to commercial and closed-source reuse.
- **AGPL-3.0** is copyleft and extends to network use, which keeps deployments of
  modified versions open.

The trade-off between adoption and reciprocity has to be settled with the project
owners and their legal advice. Until that decision is recorded, do not add a
`LICENSE` file, do not state a license in `pubspec.yaml`, and do not claim one in
the README or release notes. When the decision is made, add the license file and
update this section in the same change.

## Scope notes

- AI dispatch is not implemented: the provider interface and consent gate exist,
  but no request is sent.
- Facebook export support is partial; only recognized JSON shapes are imported.
- Releases are Windows x64 only for now. Linux and macOS runners are not part of
  the release workflow.
