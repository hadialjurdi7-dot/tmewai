# Person screen — implementation notes

Branch: `auto/person`. Scope: `TASK_PERSON.md`. Commit once; nothing pushed.

## What already existed and what changed

The repo already contained the owner-reference person profile
(`lib/src/features/people/person_screen.dart`, committed earlier from
`design/reference/user-2026-10-30/06-person.jpg`). Per AGENTS.md rule 0 the
layout was **not** redesigned or rebuilt: the three columns, the hero, the four
cards and the yearly chart keep the reference's shape, order and density. This
branch adds the missing behaviour on top of that screen:

- identity now also shows the exported **platform id** (`people.platform_person_id`)
  under the display name, and only when the export recorded one;
- the «آخر اللي حكيته» card is now a **paginated** newest-first message list
  (20 rows per page) that appends older pages through the existing `events`
  query helpers, with an honest “loaded N of M” line and a load-older control;
- all copy moves into the shared catalog `lib/src/core/l10n/app_strings.dart`
  (`person.*`, Arabic + English, guarded by `test/core/app_strings_test.dart`);
  formatting (months, dates, plurals, thousands) lives in
  `lib/src/features/people/person_strings.dart`;
- entry points: a search result's person line and a conversation participant's
  name in the open thread now open that person's profile through the shell.

## Conservative choices (and why)

1. **“Messages exchanged” = the messages that person authored.** The archive
   stores `events.actor_id` and never marks which person row is the account
   owner. Showing the other side would mean guessing who “you” are, which
   AGENTS.md §1 forbids. The card therefore lists provable rows only, exactly
   like the previous implementation, and the label still reads “آخر اللي حكيته”.
2. **“Attachments” stays the reference's «صورة» count.** The reference profile
   card states `1,284 رسالة · 214 صورة · أول تواصل …` and the stats row repeats
   four tiles. `photoCount` counts image attachment rows for that person; no
   fifth tile or relabelled tile was invented to show other media types.
3. **Paging controls are additive, not a redesign.** The loaded-count line and
   the load-older button appear only when the archive holds more text messages
   than the loaded page (or after a page was appended / failed). With a single
   page the card renders exactly like the reference.
4. **Page size 20.** Matches the profile's screen budget; the first page is part
   of `PersonService.load`, older pages come from
   `personMessagePageProvider` (family keyed by person + offset) so switching
   the open profile cannot mix two people's rows.
5. **Strings in `app_strings.dart`.** The other screens read this catalog, and
   its test asserts both locales carry exactly `appStringKeys`. Feature-local
   files (`messages_strings.dart`, `search_strings.dart`) still own their own
   copy; the person feature adds only its formatting helper, because month
   names and placeholders are formatting, not catalogue sentences. The one new
   participant-link tooltip went to `MessagesStrings` (ar + en) since the
   messages screen owns that widget.
6. **Unknown actors stay plain text.** A search hit or bubble whose `actor_id`
   is null keeps its current metadata line; there is no profile to open, so no
   dead link is rendered.

## Tests added/updated

- `test/features/person_screen_test.dart`: live fixture database (imports,
  people, 25 events, one image attachment) asserts the header, platform id,
  counts (messages, photos, first/last seen), newest-first page, the load-older
  append and the empty state; plus English/LTR render and a golden-free
  three-column order check.
- `test/features/person_repository_test.dart`: query tests for
  `messagePage` (ordering, undated rows last, no repeats across pages,
  `textMessageCount`, platform id, argument guards).
- `test/features/person_service_test.dart`: first-page expectation updated to
  the new page size.
- `test/features/search_screen_test.dart`: a result's person line calls the
  host with the stored person id.
- `test/features/messages_screen_test.dart`: a sender name in the thread calls
  the host with the bubble's actor id.

## Gates

Run on this branch before committing:

- `flutter analyze` → **No issues found!**
- `flutter test --reporter=compact` → **421 passed, 3 skipped, 0 failing**
  (baseline was 410 passed / 3 skipped / 0 failing).
