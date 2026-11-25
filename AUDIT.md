# AUDIT — logic layer (thread A)

Ordered by daily-use impact. `flutter analyze`: clean · `flutter test`: 227 passed, 1 skipped at start.

## Fixed in this pass

1. **Photo counters include video/audio/files.** `lib/src/features/media/media_service.dart:93` sums
   `AttachmentRepository.countsByYear()` (`lib/src/data/repositories/attachment_repository.dart:78`), which
   has no media filter, while the grid asks for `mediaType: 'image'`. A single video makes the «الصور» header,
   the year chips and «تظهر أحدث N من M» disagree with the tiles. Fix: filter the count/year queries to
   `image` and derive `total`/`matched` from them.
2. **The «أطول محادثة» KPI ignores the year filter.** `lib/src/features/analytics/analytics_service.dart:148`
   calls `topConversations(limit: 1)` with no year, so every other card narrows with the chip while this one
   keeps its archive-wide value. Fix: `year` on `OverviewRepository.topConversations` + pass it.
3. **Words rank by documents but the card prints occurrences.**
   `lib/src/data/repositories/event_search_repository.dart:197` orders by `doc DESC, cnt DESC`; a word said
   100 times in one message loses to a word said twice in two messages, and the bar length contradicts the rank.
   Fix: `ORDER BY cnt DESC, doc DESC, term ASC`.
4. **A reused import reports every person in the database.**
   `lib/src/services/importing/import_coordinator.dart:710` (`_outcomeForExisting`) counts `people` with a null
   import scope, so re-importing archive A after archive B claims B's people. Fix: count only the actors of
   this import's events.
5. **An unparsable timestamp is stored as «no date».** The importer keeps `timestampRaw` only when parsing
   succeeded (`facebook_json_importer.dart:620,685,880,1059`), so `ImportCoordinator:610` can never pick
   `TimezoneStatus.invalid` and a corrupt export line silently looks like a record with no timestamp. Fix: keep
   the bounded raw value and leave `timestampUtc` null.
6. **A vanished or unreadable source escapes uncoded.** `ImportCoordinator._fingerprint` reads the path before
   any guard, so a folder deleted between picking and importing throws `FileSystemException`, reaches
   `ImportRunController` as `unknown_error` and shows the generic message. Fix: report it as the catalogued
   `folder_unreadable` code (mapped to `invalidArchive` coverage).
7. **Undated images appear in the grid but not in the counter.** With «كل السنين», `media()` keeps undated
   attachment rows while `countsByYear()` drops them. Fix: `total` counts image rows regardless of date, year
   buckets stay dated.

## Deliberately left out (no deterministic check here, or out of scope)

- Date filters pass a local picker value into UTC comparisons (`search_controller.dart`, `timeline_controller.dart`
  → `to.toUtc().add(1 day)`); off by the device offset. The CI timezone is UTC, so a test cannot fail before the
  change; fix belongs with a shared date-range helper.
- `EventSearchRepository.topTerms` creates and drops one transient `fts5vocab` table; two screens loading at the
  same instant can race the drop. Needs a serialization policy, not a silent retry.
- Conversation/person caps (100 threads, 200 messages, 4 people) are product decisions, not defects; disclosed in
  the UI. Sender-side ranking (bubbles) is already honest about who is «primary».
- `lib/src/features/**/*_screen.dart` layouts are owned by the visual session and were not touched.
