# BRIEF — web build that actually runs (Tmewai in the browser)

Goal: the app runs at a URL on the server with a real import path, so the owner can
test it from a browser without downloading anything and give UI/UX feedback.

Verified state (do not re-investigate): `flutter build web --release` **succeeds**
with zero source changes, the shell renders (header + tabs from `design/reference`),
then the Home screen hangs on a spinner because the data layer never opens.

## Why it hangs

1. `AppDatabase.atPath` uses `driftDatabase(...)` **without** `web:` — on web that
   needs `DriftWebOptions(sqlite3Wasm: ..., driftWorker: ...)` plus the two assets
   copied into `web/` (`sqlite3.wasm`, `drift_worker.js` from the `sqlite3`/`drift`
   packages' `assets/` — find them with
   `find $HOME/.pub-cache -name 'sqlite3.wasm' -o -name 'drift_worker.js'`).
2. `WorkspaceService` and both importers use `dart:io` (`Directory`, `File`,
   `readAsBytesSync`) — unavailable on web.
3. `file_picker`: `getDirectoryPath` does not exist on web; `pickFile` returns
   **bytes**, not a path.

## Phase 1 — database on web

- In `AppDatabase.atPath`, keep the native path as-is and add
  `web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js'))`.
  On web the database name selects an IndexedDB/OPFS file, so ignore `databasePath`.
- Confirm the FTS5 virtual table (`createEventSearchIndex`) still runs on the wasm
  build. If it does not, guard it: on web fall back to `LIKE`-based search and record
  the trade-off in `PROGRESS.md`. **Do not silently drop search.**

## Phase 2 — one source abstraction, two implementations

- Introduce `abstract interface class SourceReader` in
  `lib/src/services/importing/source_reader.dart`:
  `Stream<String> listJsonPaths()`, `Future<String> readText(String relPath)`,
  `Future<Uint8List> readBytes(String relPath)`, `String get fingerprintSeed`.
- `DiskSource` = today's `dart:io` behaviour, moved not rewritten (folder and ZIP).
- `MemoryZipSource` = extract an uploaded ZIP **in memory** with the existing
  `archive` dependency and serve the same paths.
- Route `ArchiveInspector`, `FacebookJsonImporter` and `ImportCoordinator` through
  the interface. Keep the public method signatures unchanged so the 200+ existing
  tests keep compiling; only the internals swap.

## Phase 3 — picker + persistence on web

- `file_picker` web returns bytes: on web the import screen shows one button
  "رفع ملف ZIP" → `MemoryZipSource`. The folder button is hidden on web
  (`kIsWeb` guard), not left broken.
- Workspace: on web there is no application-support directory — use
  `driftDatabase(name: 'personal_data_agent')` (IndexedDB) and keep everything else
  in memory. No `path_provider` calls on web (`kIsWeb` guard in
  `_resolveWorkspaceDirectory`).

## Phase 4 — ship it as a normal Dockerfile (no VNC)

- `docker/Dockerfile.web`: `debian:bookworm-slim` + nginx only,
  `COPY build/web /usr/share/nginx/html`, `COPY docker/nginx.conf` with
  `gzip on` and correct MIME types, `EXPOSE 80`, healthcheck `curl -f localhost/`.
- `docker/compose.web.yaml`: one service, port 8080, no volumes needed.
- Build and run it locally, then `curl` the index and `main.dart.js`, and prove the
  app opened by dumping the DOM with
  `<chromium-binary> --headless=new --no-sandbox --disable-gpu --enable-unsafe-swiftshader --virtual-time-budget=22000 --screenshot=/tmp/shot.png <url>`
  — a spinner-only screenshot is a FAIL, the Home screen must show real content.

## Hard constraints

- Do not break the desktop build or any existing test.
- No new dependencies. `archive`, `drift`, `file_picker` already suffice.
- Do not push, do not tag.
- Verify: `export PATH=$FLUTTER_ROOT/bin:$PATH; flutter analyze; flutter test; flutter build web --release`.
- Commit with `feat(web): the app runs in a browser; drift/wasm + in-memory ZIP source`.
