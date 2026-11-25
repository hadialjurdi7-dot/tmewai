# BRIEF — v0.3.5 (import actually reads the files)

Read this file, then `AGENTS.md` and `PROGRESS.md`. Work in `.`.
Do not ask questions — decide and record the decision in `PROGRESS.md`.

## The defect (verified by the maintainer, do not re-diagnose)

The import screen in `lib/src/app/app.dart` only ever **inspects** a picked
folder/ZIP (`ExportInspector.inspect`) or builds a **preview**
(`FacebookJsonImporter.previewSource`). Nothing in the UI ever calls
`ImportCoordinator.importSource`, so:

- the user picks a folder, sees a report, and **the archive stays empty**;
- every screen (home / messages / media / people / analytics / search) shows zero.

`lib/src/features/import/import_controller.dart` (untracked today) already wraps
the coordinator correctly — it is simply **not referenced by any widget**.
`flutter analyze` currently fails on one line in it:
`PersonSelectionController` has no `reset()`.

There is also stale prototype copy at `app.dart` ~lines 230-232 claiming the app
"does not extract files or analyze contents" — that is now false.

## Phase 1 — wire the real import (the fix)

1. `lib/src/features/people/person_controller.dart`: add
   `void reset() => state = null;` to `PersonSelectionController` (mirror the
   existing `MessagesSelectionController.reset`). This clears the analyze error.
2. `lib/src/app/app.dart`, import screen: after a successful inspection, show a
   primary `FilledButton.icon` "استيراد الآن / Import now":
   - enabled only when inspection succeeded and the source has supported files;
   - `onPressed` → `ref.read(importRunProvider.notifier).run(archive.path)` —
     the same `source.path` that was inspected, folder or ZIP, no copy;
   - while `importRunProvider.running`: `LinearProgressIndicator` driven by
     `progress.filesDone / progress.filesTotal` plus `progress.recordsWritten`,
     and a cancel button → `ref.read(importRunProvider.notifier).cancel()`;
   - on `outcome != null`: show the real counts
     (`events`, `people`, `conversations`, `attachments`, `skippedRecords`) and
     say plainly when `reusedExistingImport` is true;
   - on `errorCode != null`: show a localized message and keep the previous
     "no data was saved" guarantee only when nothing was written;
   - on `cancelled`: state that the partial import was rolled back (verify that
     claim against the coordinator before writing the copy).
3. Delete the prototype disclaimer at ~230-232 and replace it with one honest
   line: the app reads the picked folder on this device and writes it to the
   local archive.
4. All new user-visible text goes into **both** locales: `appStringKeys` +
   `AppStringsEn` + `AppStringsAr` in `lib/src/core/l10n/app_strings.dart`
   (`test/core/app_strings_test.dart` enforces parity — it must stay green).
   Do not hardcode Arabic/English literals in the widget.

## Phase 2 — tests (acceptance)

Add `test/features/import_flow_test.dart`:
- build a temp folder with the Facebook-shaped tree (copy the fixture pattern from
  `tool/probe/import_probe_test.dart`), run the app widget on a temp workspace,
  pick nothing — drive the controller directly:
  `ImportRunController.run(tempFolder)` → assert `recordsWritten > 0`,
  `outcome.events > 0`, and that the home/messages snapshot providers were
  invalidated / now see the imported rows.
- one test for the failure path: a folder of unrelated JSON → `errorCode` set,
  no rows written.
- one test that pressing the "Import now" button in the widget tree triggers the
  controller (pump, tap by label text, expect running state).

## Phase 3 — release prep

- `pubspec.yaml`: `version: 0.3.5+9`.
- `CHANGELOG.md`: new `## 0.3.5` section at the top, three bullets max: real
  import wired (files are now read and stored), honest import copy, app icon
  from the approved mark.
- `PROGRESS.md`: append a `## v0.3.5` block naming what changed and the exact
  verification commands you ran.

## Hard constraints

- Do **not** push and do **not** tag — the maintainer tags and CI publishes.
- Do **not** touch `windows/`, `build/`, or the release workflow.
- Do **not** add dependencies. Everything needed is already in `pubspec.yaml`.
- Do **not** rename existing providers or move files; wire what exists.
- Keep the diff small and readable. No new abstraction layers, no state machine
  beyond `ImportRunState`.

## Verify before you report done

```bash
export PATH=$FLUTTER_ROOT/bin:$PATH
cd .
flutter analyze                      # must be clean
flutter test                         # must be green
flutter test tool/probe/import_probe_test.dart   # PROBE_FAILURES 0
git add -A && git commit -m "feat(import): the import screen actually imports; v0.3.5 prep"
```

Report: files touched, the test counts, and the commit sha.
