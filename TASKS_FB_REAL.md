# TASKS_FB_REAL — make a real 2018-era Facebook export legible

You are working in a Dart/Flutter repo (`.`). Build the three
phases below, in order, committing after each. Do not ask questions — decide and
record the decision in `PROGRESS.md`.

## The problem, from a real user archive

A real 2018-era Facebook export (816 MB, 139,531 records) imports but is not
legible:

1. The import preview shows message records with **"مرسل غير معروف" / "Unknown
   sender"** — the older `message_*.json` layouts and many modern ones do not
   carry `sender_name` on every message object.
2. Records show **"بلا نص" / no text** — a message that is only a photo, share,
   sticker, call or unsent placeholder parses to an empty body and is displayed
   as a blank record.
3. 180 files under `ads_information/` and other known Facebook folders are
   reported as **"unsupported"**, so the coverage report tells the user nothing
   about most of their archive.

Fix all three. This is the difference between "the import ran" and "I can read my
own history".

## Hard constraints

- **No new dependencies.** No network calls anywhere in the import path — this
  is a local-first, privacy-first product. Nothing may be uploaded.
- Do not change `lib/src/core/design/tokens.dart`, `theme.dart`, or any visual
  styling. Another session owns the design.
- Do not change the database schema unless a phase genuinely requires it; if it
  does, add a migration and say so in `PROGRESS.md`.
- Every user-visible string must exist in **both** Arabic and English
  (`lib/src/core/l10n/`), with the Arabic reading naturally.
- Errors stay bounded and catalogued (`lib/src/core/errors/import_error_catalog.dart`);
  no raw exception text on screen.

## Existing code you must read first (do not re-invent)

- `lib/src/services/importing/facebook_json_importer.dart` — the whole parser
  (`_FileKind`, `_entryListOf`, `_kindForPath`, `_parse*`, warning codes at the
  end of the preview build).
- `lib/src/services/importing/import_coordinator.dart` — the write phase.
- `lib/src/services/importing/import_coverage_report.dart` — coverage model.
- `lib/src/app/facebook_import_preview_summary.dart` — the preview UI
  (`record.senderName ?? 'مرسل غير معروف'` is line ~80).
- `test/fixtures/make_export.py` — the fixture generator; extend it rather than
  hand-writing JSON.
- `test/services/facebook_export_layouts_test.dart` — existing layout tests.

## Phase 1 — Resolve sender names from the archive itself

Facebook exports carry names elsewhere than on each message: thread-level
participants, `friends_and_followers/friends.json`, profile/contact files, and
the `message_*.json` header object. Build a people index in one pass and use it:

- Index names from every place the archive states them.
- When a message object lacks `sender_name`, resolve the sender from the thread's
  participant list and file path (`messages/inbox/<thread>/message_*.json`).
- Keep the raw value when present; never overwrite a real `sender_name` with a
  guess.
- Unknown stays unknown — do not fabricate a name.

**Acceptance:** a fixture whose messages carry **no** per-message `sender_name`
but do carry thread participants and a friends file previews with the real
names, and the preview shows **zero** "مرسل غير معروف". A test asserts this,
and a control test asserts a name-less, participant-less fixture still says
unknown rather than inventing one.

## Phase 2 — Non-text records get a real label, not an empty body

A record with empty `content` is not an empty record. Parse the typed payloads
Facebook actually uses and give each one a label plus its attachment references:

`share`, `photos`, `videos`, `gifs`, `audio_files`, `files`, `sticker`,
`call_duration` / call placeholders, `unsent` (message deleted at source), and
poll/plan entries if present in the fixture.

- Label each in Arabic and English ("صورة", "فيديو", "رابط مشارَك", "ملصق",
  "مكالمة — 42 ثانية", "رسالة محذوفة" …).
- Wire the attachment metadata (path + SHA-256) the way attachments are already
  handled — metadata only, bytes never copied into the workspace.
- A record that is genuinely empty (no content and no payload) is still counted
  and reported as such, not silently dropped.

**Acceptance:** a fixture with one record of each type previews with the right
label and count; the number of records with no label is zero; a test covers each
type. The event type must be distinguishable in stored data, not only in the
label — the timeline needs to tell a photo from a link.

## Phase 3 — Classify the known Facebook folders in the coverage report

The coverage report currently buckets anything unrecognised as "unsupported".
Facebook's export layout is documented by the folder names themselves. Map the
known roots to human categories with counts:

`ads_information`, `friends_and_followers`, `personal_information`,
`your_activity_across_facebook`, `your_places`, `logged_information`,
`security_and_login_information`, `preferences`, `facebook_profile_information`,
`apps_and_websites_off_your_facebook_activity`, `your_facebook_activity` (and
whatever else the real layout uses).

- Each category gets an Arabic + English label and a plain-language line saying
  what it is ("بيانات الإعلانات التي جمعتها فيسبوك عنك").
- The report shows **how many files and how many records** fell in each category,
  and keeps "unsupported" for paths that are genuinely unknown.
- The `unsupported_json_files_present` warning must fire only for the genuinely
  unknown ones — the known-and-not-imported ones get their own honest warning
  (e.g. "known folders not imported yet") so the number stops being meaningless.

**Acceptance:** a fixture containing `ads_information/…` and
`friends_and_followers/…` produces category rows with correct counts and no
"unsupported" for those paths; a test asserts both the mapping and that a truly
unknown path still lands in "unsupported".

## Verification — run this yourself, it must pass before you commit each phase

```bash
export PATH=$FLUTTER_ROOT/bin:$PATH
cd .
flutter pub get
flutter analyze
flutter test --reporter=compact
```

Baseline is green: **279 passing, 3 skipped, 0 failing**. Keep it green and add
tests; a phase whose tests are red is not done.

## Closing rule

After each phase:

1. `flutter analyze` clean, `flutter test` green.
2. `git add -A && git commit -m "phase N: <what changed>"`
3. Append to `PROGRESS.md`: the phase, the files touched, the acceptance check
   result, and any decision you made.
4. Continue straight into the next phase. Finish all three in this session.
