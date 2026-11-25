# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.5.6 — 2026-11-20

- **A failed start now says so.** `startup.log` in the application support folder records
  `boot`, the first frame, and every error Flutter or the root zone reports, with its stack.
  Before this, a release build that stopped before the first frame showed an empty window and
  nothing else — indistinguishable from a hang, and undebuggable from the field.

## 0.5.5 — 2026-11-20

- **Three more sources import into the same workspace.** Alongside the Facebook export, the
  importer now reads a WhatsApp chat export (`.txt`, or the ZIP that carries it), a Telegram
  Desktop JSON export (`result.json`) and an Instagram direct-message export. All four reach
  the same writer and the same `events` table; the source platform is recorded per row, so a
  mixed workspace stays queryable.
- WhatsApp: the Android 24-hour, US 12-hour and iOS bracket timestamp shapes all parse,
  continuation lines join their message, `<attached: …>` records the file name without reading
  media bytes, and system lines are counted instead of being stored as messages.
- Telegram: `text` arrives either as a string or as a list of strings and entity objects, both
  flatten to the literal sentence, `date_unixtime` wins over `date`, and `type: "service"`
  entries never become messages.
- Instagram: `timestamp_ms` converts to UTC, attachment names and `share` links are kept, and
  the double-encoded Arabic Meta writes in its exports is repaired back to real Arabic instead
  of showing up as `Ã˜Â£`.
- CI now pins Flutter 3.47.9: the analyzer on 3.50 deprecates `package:flutter/material.dart`
  in favour of `material_ui`, and the `--fatal-infos` gate turned those into a red build.

## 0.5.1 — 2026-11-09

- **One bad value no longer discards a real archive.** `people.display_name` and the other
  bounded text columns are declared with `withLength(min: 1, …)`, and drift enforces the
  **minimum** too. A real Facebook export contains `"sender_name": ""`, so the insert threw
  inside the transaction and all 139,531 records were rolled back with only "a record
  contains a value the local database cannot store" shown.
- Every write path now routes through `normalizeImportText` and the `ImportTextColumns`
  registry: blank values become `null` where the column allows it, oversized values are
  clipped or skipped, and a record that still violates a bound is skipped, counted and
  named by file + field + bound instead of aborting the import.
- `display_name` is an identity key, so it is stored **verbatim** — senders that differ
  only in surrounding whitespace stay distinct and an existing person row is reused
  rather than duplicated.
- The completed-import report renders the skip warnings (Arabic and English, capped, with
  a safe fallback for unknown codes), so the user can see which file and field was skipped.

## 0.4.2 — 2026-11-06

- **Encrypted portable vault** (#48): a workspace backup sealed with Argon2id and
  AES-256-GCM (`lib/src/services/vault/`), so the archive leaves the machine as one
  encrypted file instead of a folder of plaintext JSON and images.
- **Windows build is green again.** The Test step failed on every branch since 31/10 on
  `workspace_size_test.dart`: it deleted the workspace folder while SQLite still held the
  database file (`PathAccessException`, errno 32 — Windows only; Linux unlinks open files).
  The test now closes the workspace first; the behaviour under test is unchanged. This is
  what kept the 0.4.0 tag from ever producing a release.
- Includes everything shipped in 0.4.1/0.4.0: the six screens rebuilt against the owner's
  reference design, three logic fixes (year-filtered longest conversation, search ranked by
  occurrences, media counting only images), the `?demo=fx` synthetic archive, and the
  real-export limits with their audits.

## 0.5.0 — 2026-11-06

Three sessions in parallel on one real 816 MB export. The archive that used to
import-but-not-read is now legible, searchable in the Arabic people actually
type, and holds 139,531 records without freezing the app.

- **Sender names come from the archive itself.** `_PeopleIndex` collects names
  from `friends*`/`followers*`/`profile*` files and every `participants` list, and
  `_resolveSender` fills a missing `sender_name` from the thread title, the
  conversation folder, or an unambiguous single participant. A real `sender_name`
  is never overwritten and a crowded thread with no evidence stays "unknown" —
  no invented names.
- **A message with no text is no longer a blank record.** Unsent placeholders,
  calls (with their duration), shares, photos, videos, GIFs, audio, files,
  stickers, polls and plans each get their own stored event type and a bilingual
  label, with attachment metadata and SHA-256 kept and no bytes copied. A
  genuinely empty record is stored and counted, not dropped. Every message
  aggregate now matches all `message_*` types, so a photo-only thread cannot
  vanish from a count.
- **Known Facebook folders are classified, not called "unsupported".** 20
  bilingual categories map the documented export roots (`ads_information`,
  `friends_and_followers`, `your_activity_across_facebook`, …) with per-category
  file and record counts, plus old 2018 spellings. `unsupported_json_files_present`
  now fires only for genuinely unknown paths; known-but-not-imported folders get
  their own honest warning.
- **Arabic search folds what the keyboard produces.** One rune table drives both
  the Dart normaliser and the generated SQL: harakat removed, `أ إ آ ٱ`→`ا`,
  `ى`→`ي`, `ة`→`ه`, tatweel removed. `احمد` now finds `أحمد`, `مصطفي` finds
  `مصطفى`. Stored text keeps its original spelling, and a schema migration
  rebuilds the FTS rows once so an existing archive becomes searchable without
  re-importing.
- **Search explains itself.** Multi-word queries are AND and say so, the total
  hit count and the searched term are shown, active filters are removable chips,
  an empty result names the filters and offers one widening action, and every row
  names its conversation, person and date so a hit stays auditable.
- **The timeline and a long thread survive a real archive.** The timeline is a
  lazy sliver list: one SQL aggregate for the counts, a page of rows per visible
  group (measured: 3 of 45 groups and 13 rows built on a 5,044-record archive).
  Messages open on 50 rows, append older pages on scroll, show "loaded N of M",
  and search the whole thread in SQL — a hit at the far end is found even when its
  page was never loaded.

## 0.4.5 — 2026-11-06

- **One long value no longer throws away a whole import.** The write phase inserted
  exported values straight into fixed-width columns: a group-thread folder name past
  the 128-character conversation id, or a display name past 512, made the database
  layer throw while inserting. The throw rolled back the transaction, so a 139,531-record
  export saved **nothing** and the screen only said "the import could not be saved".
  - Names, thread keys, titles, paths and metadata are clipped to their column.
  - A record the schema still cannot hold is skipped and counted, not fatal.
  - A message body past the ceiling is skipped and counted - user text is evidence,
    so it is never silently truncated.
- **The failure names itself.** `import_write_failed` was one opaque code for every
  cause; the app now reports `import_write_invalid_value`, `import_write_conflict`,
  `import_write_busy`, `import_disk_full` and `import_write_io_error`, each with its
  own guidance, so the next report is a diagnosis instead of a riddle.

## 0.4.4 — 2026-11-06

- **A real export's files are all recognised now, whatever Facebook called them.**
  File names decided whether a JSON file was read at all, and Facebook renamed
  them between export versions: a root `likes_and_reactions_1.json` (older) versus
  `likes_and_reactions/likes_and_reactions.json` (newer), `your_posts.json` versus
  `your_posts__check_ins__photos_and_videos_1.json`. Any name the list did not know
  was counted as "unsupported JSON" and never parsed, which left zero supported
  files - and an import with zero supported files is refused, so nothing reached
  the dashboard.
  - Every JSON entry is read; the kind is decided by the name and, when the name
    matches nothing, by the record shape itself.
  - Old-layout comments (a top-level list) are parsed, not only the `comments_v2`
    object.
  - The record ceiling is 1,000,000, so a large export is not refused for size.
- The import screen now lists the paths of the files it could not read, instead of
  only counting them.

## 0.4.3 — 2026-11-06

- **A real Facebook export (800 MB+) now imports directly.** The ZIP was read whole
  into memory and refused over a 600 MB ceiling ("extract it and choose the folder"),
  which is why a full export could not be opened at all. The inspector now reads the
  archive through its central directory (`lib/src/services/importing/zip_random_access.dart`)
  and decompresses only the JSON entries it needs; media is skipped, never read.
  Measured on a 707 MB export: 3,033 entries, 11.5 MB of JSON, **140 ms**, peak RSS
  ~160 MB. The in-memory ceiling still applies to the browser picker, which has no file
  to seek in.
- Password-protected archives are refused with their own message instead of being
  reported as corrupt.

## 0.3.9 — 2026-10-31

- **«الأشخاص»** rebuilt on the owner's exported design: cover and profile card, counters, «آخر اللي حكيته», shared-photo gallery, per-year bars, related people, local archive card, memory quote. **Six of the seven screens now match the owner reference** — only settings is still on the older mockup.

## 0.3.8 — 2026-10-31

- **«الصور»** rebuilt on the owner's exported design: year filters, thumbnail grid with the year on each item, memories banner, «أكثر الناس بالصور», local-files note. Five of the seven screens now match the owner reference (home · story · analytics · messages · media).
- Web build turns on Flutter accessibility semantics, so the page is reachable by screen readers and browser automation instead of being one opaque canvas.

## 0.3.7 — 2026-10-31

Three more screens rebuilt against the owner's exported design, so four of the
seven now match the reference instead of the older generated mockups:

- **«الرسائل»** — shortcuts rail, conversation list with unread badges, read-only thread with grouped date separators, attachments, and the disabled archive composer.
- **«قصتك بالأرقام»** — peak-year card, per-year bar chart with the value on every bar, top-words list from the local index, monthly memories, quick-stat strip.
- **«التحليلات»** — year filter, KPI cards, messages per month, per hour of day, what you share most, most written words, local-data footer.
- Nothing invented: every number comes from the local archive, and screens say so when the archive has nothing.

Web build fixes (the browser build is how the app is reviewed before install):
- Self-hosted CanvasKit instead of pulling it from gstatic, which is a silent blank screen on a filtered connection.
- Cross-origin isolation headers on the dev server so drift's wasm worker can open the database.

## 0.3.6 — 2026-10-30

- Home screen rebuilt against the owner's own exported design (`design/reference/user-2026-10-30/01-home.jpg`): three-column desktop layout, shortcuts rail, composer, feed cards, privacy strip.
- The owner's six screens are now the binding UI reference, committed to the repo; generated reference art is secondary only (`AGENTS.md` rule 0, `TASKS.md`).
- Build briefs for the five remaining screens ship with the release (`TASK_SCREENS_1..3.md`).
- Release pipeline: the Windows job no longer fails when GitHub Actions artifact storage is full — the artifact upload is a convenience, the release asset is the deliverable.

## 0.3.5 — 2026-10-30

- Wire the import screen to read supported Facebook files and store records in the local archive, with progress, cancellation, and actual result counts.
- Replace prototype import copy with an accurate local-read and local-storage explanation.
- Ship the app icon using the approved Tmewai mark.

## [0.3.0] - 2026-10-29

The release where the app becomes usable: six reviewed screens over the local
archive, on the approved design, with every number traceable to a stored row.

### Added

- **Seven-section navigation shell.** الرئيسية · قصتك بالأرقام · التحليلات · الرسائل ·
  الصور · الأشخاص · الإعدادات, each face built lazily on first visit, on the
  approved Tmewai tokens. The approved screen references ship with the repo
  (`design/reference/stitch/`), so the UI is matched, not reinvented.
- **Home dashboard** — «حصيلة سنينك» (messages · photos · people · years), the
  people you wrote to most as labelled bars, and «آخر النشاط» with the three
  newest events.
- **«قصتك بالأرقام»** — busiest year, messages per year with the value on every
  bar, your three most used words read from the FTS5 index, and quick numbers.
- **Analytics** — year filter, messages per month, per hour of day, share of
  each event type, and the people ranking; every bar carries its number.
- **Messages** — conversation list and a read-only thread with day separators.
  The composer is disabled on purpose: the app never writes back to Facebook.
- **Photos** — a metadata-only gallery with year badges and a memories filter.
  Media bytes are never opened, copied or uploaded.
- **A person's profile** — cover, avatar, counts, last lines and shared photos.

### Changed

- Photo counts mean photos: the KPI now filters `media_type = 'image'` instead
  of counting every attachment, so videos, voice notes and files no longer
  inflate «صور» on home, story, analytics, media and person.
- A year filter offers every year the archive holds dated events for, not only
  years that contain messages.

### Fixed

- **«آخر النشاط» shows the newest events.** It used to be derived from the
  oldest 5,000 timeline rows, so a large archive showed years-old activity.
  It is now an explicit newest-first query.
- Archive-wide totals no longer drop undated rows; an archive whose messages
  carry no timestamps is no longer reported as empty.
- Deleting the workspace clears the home, analytics, messages and media
  snapshots, so deleted names, counts and message text stop being displayed.
- The pushed search screen and the pushed import page both have a visible way
  back; neither can strand the user outside the navigation.
- A requested conversation, thread or person is read by its own id. A selection
  outside the capped list used to open the first row instead — which showed
  another person's numbers under the requested name.
- Labels say what their queries compute: «أكثر مُرسِل» (the exported sender may
  be your own account), «رسائل أرسلها هذا الشخص» instead of «رسائل متبادلة»,
  and «أكثر المُرسِلين في أرشيفك» instead of claiming closeness.

### Reviews

- `docs/REVIEW_six-screens.md` — an independent review of the six screens.
- `docs/MERGE_TRIAGE.md` — 50 findings from five review bots, arbitrated: 16
  blocking (all fixed here), 2 already covered, 4 waived with proof against the
  code, 25 nits deferred to a single follow-up chore.

## [Unreleased]

### Added

- Encrypted portable vault (`.tmewia`): a workspace can be sealed into one
  authenticated file with a passphrase and restored byte-for-byte. Argon2id
  derives the key, AES-256-GCM seals the payload, file names and hashes are
  encrypted alongside the data, and the header is authenticated as associated
  data so parameter tampering is rejected.
- The import source can be a folder the user already extracted, not only a ZIP
  archive. A folder is read in place, one JSON file at a time, so an export of
  several hundred megabytes no longer has to fit in memory. The folder passes
  the same checks the archive path applies: no symbolic links, no paths leaving
  the chosen root, the same entry, path-length and size limits, and no
  duplicate paths.
- `ExportInspector` picks the right scanner from the path, so the importer and
  the import coordinator never branch on source kind. A folder's import
  fingerprint is the hash of its sorted `path:size` listing.
- A committed brand mark: `assets/branding/` holds the logo, the app tile and
  the Windows `.ico`, the sidebar shows the mark and the tagline, and both
  Windows workflows put the icon on the generated runner. Regenerate with
  `python3 tool/make_brand_assets.py` (needs Pillow).

### Changed

- The main import action is now 'Choose folder'; opening a ZIP is the secondary
  action. The selected-source chip shows which kind is open.
- The product is named **Tmewai** everywhere it is shown to a user: the window
  title, both README halves and the project documents. The Dart package name
  (`personal_data_agent`) is unchanged, so no import paths moved.

### Fixed

- An empty archive and an oversized one used to share one error and one message
  ("empty or exceeds the compressed-size limit"), which told the user nothing.
  They are now `archive_empty` and `archive_size_limit`, and the size message
  names the limit and the action that works.

## [0.2.1] - 2026-10-27

### Fixed

- Upgrading a version 1 workspace now indexes events that existed before the
  FTS5 index, so previously imported records are searchable immediately.
- Search sorts undated events after dated ones instead of treating a missing
  timestamp as the Unix epoch.
- Arabic search normalization strips U+0656–U+065F, so words carrying those
  marks match their plain spelling.
- Imported events no longer claim a UTC timestamp when the source had none or
  could not be parsed; `TimezoneStatus.invalid` is distinct from `unknown`.
- Declared Dart/Flutter minimums now match the resolved dependency graph in
  `pubspec.lock`.
- The workspace database path is always absolute, even when the root is given
  as a relative directory.
- Overlapping workspace opens share one handle, and a close that starts while
  an open is in flight leaves the workspace closed instead of publishing the
  new database.
- The workspace provider registers teardown before awaiting the open, so a
  provider disposed mid-open cannot leak a database handle.

### Changed

- ZIP test fixtures set general-purpose bit 11 for non-ASCII entry names.
- `AGENTS.md` forbids `git add -A` and documents the merge gate for Cubic
  review before any merge to `main`.
- Added `docs/STATUS_AND_PLAN_2026-10-26.md`, `docs/TESTING_STRATEGY.md`,
  `docs/UI_DIRECTION.md`, `.mcp.json` and `tool/verify.sh`.

## [0.2.0] - 2026-10-26

First versioned milestone of the local-first desktop app. Everything below runs
entirely on the user's device; no feature in this release opens a network
connection.

### Added

- Green CI baseline: `flutter analyze` and `flutter test` pass on the current
  stable toolchain, and the Windows CI workflow is narrowed to relevant source
  and configuration changes.
- Drift schema, domain models and migration foundation for imports, source
  files, people, conversations, events, attachments, derived insights and AI
  consents.
- FTS5 full-text search index with transactional synchronization and an
  Arabic-friendly tokenizer that normalizes diacritics and letter variants.
- Local workspace with an open/close lifecycle and a safe, idempotent delete
  that is refused while the workspace is open and never removes data outside
  the workspace directory.
- Transactional import pipeline with duplicate detection and safe cancellation:
  an import either commits completely or leaves nothing behind, and a cancelled
  run rolls back rather than persisting partial state.
- Per-file coverage report that classifies every archive entry (supported,
  malformed JSON, unsupported JSON shape, media, unknown extension, or blocked)
  using content-free reason codes that never echo archive paths.
- Facebook importers for messages, comments, reactions and posts, each with
  synthetic fixtures and its own test file.
- Attachment metadata records with SHA-256 hashes and an allowlist of fields;
  attachment bytes are never copied into the workspace.
- Bilingual safe error catalog returning Arabic and English messages that are
  safe to display, log and store without leaking user content.
- AI provider interface with a strict consent gate: the evidence bundle is
  bounded and shown before any approval, consent is recorded, and dispatch is
  not wired to a network client yet.
- Search screen with query and type/date filters, timeline screen with
  deterministic day/month bucketing, overview dashboard with auditable counts
  and drill-down, and settings screen for privacy controls.
- Arabic RTL layout and an accessibility pass: locale-aware directionality,
  matching Arabic/English string catalogs with a test that keeps both key sets
  identical, semantic labels, and scalable text.

### Changed

- `pubspec.yaml` version bumped to `0.2.0+2`.
- README now describes the implemented feature set, links to release downloads
  and keeps the remaining limitations explicit.

### Known limitations

- AI dispatch is not implemented: the provider interface and consent gate exist,
  but no request is sent and no HTTP client is configured.
- Facebook export support is partial: formats vary by export settings and
  platform version, and only the recognized JSON shapes are parsed.
- No LICENSE file is included yet; the Apache-2.0 versus AGPL-3.0 decision is
  still open (see `docs/RELEASE.md`).

[Unreleased]: ../../compare/v0.2.0...HEAD
[0.2.0]: ../../releases/tag/v0.2.0