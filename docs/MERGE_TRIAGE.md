# Merge triage — 50 bot findings

## Verdict per PR

| PR | blocker count | mergeable after fixes? | note |
|---|---:|---|---|
| #52 | 1 | Yes | Add a visible return from pushed search on `feat/screens-base`. |
| #54 | 5 | Yes | Fix import dead end, undated totals/empty state, stale home snapshot and large-text clipping; latest activity is fixed in #63. |
| #55 | 2 | Yes | Correct sender-ranking language and handle undated-only archives. |
| #56 | 2 | Yes | Clear analytics after deletion and include all event types in year choices. |
| #57 | 4 | Yes | Make older conversations reachable, prevent wrong-thread fallback/stale messages, and report the true thread start year. |
| #58 | 1 | Yes | Clear cached gallery data after deletion. |
| #59 | 5 | Yes | Fix profile/thread selection and unsupported relationship/message-count claims; image count is fixed in #63. |
| #60 | 0 | Yes | No findings in this triage set. |
| #63 | 1 | Yes | Grid rows are image-filtered, but year/total aggregates still include non-images; fix on `feat/screen-media`. |

## FIX-NOW (must land before merge)

- [F1] PR #52 `lib/src/app/app_shell.dart:89` — Search is pushed without a visible return action, stranding desktop users outside shell navigation — add a visible back/close affordance to the search route — `feat/screens-base`.
- [F2] PR #54 `lib/src/features/home/home_screen.dart:116` — The dashboard pushes the legacy import page without an in-page return control, hiding shell navigation — add a visible close/back control to `ImportHomePage` or its route — `feat/screen-home`.
- [F3] PR #54 `lib/src/data/repositories/overview_repository.dart:249` — The unconditional `timestamp_normalized IS NOT NULL` filter omits undated events from archive-wide event/message/people totals — apply timestamp filtering only when a year is selected — `feat/screen-home`.
- [F4] PR #54 `lib/src/features/home/home_controller.dart:18` — Home remains mounted with cached names/text after workspace deletion — invalidate or gate the home snapshot on successful deletion — `feat/screen-home`.
- [F5] PR #55 `lib/src/features/story/story_screen.dart:446` — “أكثر شخص راسلته” claims a correspondent, but `ImportCoordinator` stores exported sender names as `actorId`, which can be the archive owner — relabel this as the most active message sender rather than infer owner/contact identity — `feat/screen-story`.
- [F6] PR #55 `lib/src/features/story/story_service.dart:47` — An archive containing only undated messages is classified as empty because `isEmpty` uses dated-only totals — determine emptiness from all stored events, including undated rows — `feat/screen-story`.
- [F7] PR #56 `lib/src/features/analytics/analytics_controller.dart:30` — The mounted analytics screen can keep showing deleted names/counts after workspace deletion — clear/gate its snapshot on successful deletion and prevent reads through the closed workspace — `feat/screen-analytics`.
- [F8] PR #56 `lib/src/features/analytics/analytics_service.dart:80` — Year chips come from message-only `countsByYear()`, hiding years with only posts/comments/reactions though the charts include them — derive available years from all dated event types — `feat/screen-analytics`.
- [F9] PR #57 `lib/src/features/messages/messages_service.dart:143` — The 100-conversation/200-message caps hide archive content and a selected ID outside the first 100 silently falls back to another thread — load an explicitly requested thread by ID and provide a simple, honest way to reach remaining rows; no framework or dependency — `feat/screen-messages`.
- [F10] PR #57 `lib/src/features/messages/messages_controller.dart:34` — The visited Messages screen retains deleted message text after workspace deletion — clear selection/snapshot and gate repository reads on successful deletion — `feat/screen-messages`.
- [F11] PR #58 `lib/src/features/media/media_controller.dart:28` — The cached gallery continues exposing deleted dates and names after workspace deletion — clear/gate its snapshot on successful deletion — `feat/screen-media`.
- [F12] PR #59 `lib/src/features/people/person_service.dart:133` — A requested valid person outside the top-eight ranking silently opens the first person's profile — load the requested profile independently of the ranked sidebar; never substitute another person — `feat/screen-person`.
- [F13] PR #59 `lib/src/app/app_shell.dart:176` — The profile can select a conversation outside Messages' recent 100, where selection opens another thread — support selecting/loading the requested conversation ID instead of falling back — `feat/screen-person`.
- [F14] PR #59 `lib/src/features/people/person_screen.dart:677` — “رسائل ... بيناتكم” labels the selected sender's counts as exchanged messages, but repository queries count only events sent by that person — call them messages sent by the selected person — `feat/screen-person`.
- [F15] PR #59 `lib/src/features/people/person_screen.dart:825` — “ناس قريبين منّها” asserts closeness without evidence; this is the same archive-wide ranking on every profile — rename it to describe the archive-wide active-sender ranking — `feat/screen-person`.
- [F16] PR #59 `lib/src/features/people/person_screen.dart:709` — The displayed “total exchanged” value sums dated sender-only years while the profile count includes all messages, including undated — label the chart/total as dated messages sent by the selected person, or include undated rows — `feat/screen-person`.
- [F17] PR #54 `lib/src/features/home/home_service.dart:32` — With only undated events, `HomeSnapshot.isEmpty` sees zero dated events/photos and shows the no-archive/import state despite stored content — base emptiness on the all-event total from F3 — `feat/screen-home`.
- [F18] PR #54 `lib/src/features/home/home_screen.dart:777` — The count is inside a clipped, fixed-height bar and can be cut off at large accessibility text scales — move the count outside the bar or size the bar to its text — `feat/screen-home`.
- [F19] PR #57 `lib/src/features/messages/messages_service.dart:116` — The UI shows an archive-wide conversation count but only lists 100, leaving older conversations unsearchable/unreachable — provide a simple visible way beyond the cap or disclose and correct the mismatch — `feat/screen-messages`.
- [F20] PR #57 `lib/src/features/messages/messages_service.dart:202` — “From YEAR” is derived from the oldest message in the 200-message window, not the full thread, so the displayed thread start year is wrong — query the earliest message timestamp or scope the label to the loaded window — `feat/screen-messages`.
- [F21] PR #63 `lib/src/features/media/media_service.dart:94` — `total` and `countsByYear()` still count video/audio although the gallery requests image-only rows; year chips/header/matched total disagree with the grid — make the year aggregate image-only and derive total/matched from it — `feat/screen-media`.

## ALREADY FIXED

- [X1] PR #54 `lib/src/features/home/home_service.dart:57` — Fixed by #63: `HomeService` now calls `TimelineRepository.latestEvents(limit: 3)`, an explicit newest-first query, instead of reversing the oldest capped timeline page.
- [X2] PR #59 `lib/src/data/repositories/person_repository.dart:75` — Fixed by #63: the photo-count subquery now filters `a.media_type = 'image'`, so video/audio/files do not inflate “photos.”

## FALSE POSITIVE / WAIVED

- [W1] PR #58 `lib/src/features/media/media_screen.dart:499` — `MediaService.topPeople()` uses `limit = 5`, and `_PeopleCard` prints `people.length` while rendering exactly those rows; “5 people” counts the displayed ranking, not a claimed archive-wide population.
- [W2] PR #58 `test/features/media_screen_test.dart:200` — The RTL assertion reads `Directionality(rtl)` supplied by `_pumpMedia`; this is weak test coverage, not a user-visible RTL/accessibility blocker.
- [W3] PR #59 `lib/src/features/people/person_screen.dart:259` — The alleged Dart promotion/type error is false: the inspected closure compiles with `canChat ? () => openConversation(conversationId) : null`; no speculative workaround.
- [W4] PR #63 `lib/src/data/repositories/timeline_repository.dart:78` — `latestEvents()` intentionally sorts unknown timestamps last; if fewer than three dated events exist, a stored undated event may appear and Home labels its date “تاريخ غير معروف.” This is real data, not an invented value.

## NIT-BATCH (one chore PR after merge)

- [N1] PR #52 `lib/src/app/app.dart:135` — `IBMPlexSansArabic` is not bundled/registered, so fresh installs fall back to another font; decide whether to bundle the approved font without adding a dependency.
- [N2] PR #54 `lib/src/features/home/home_screen.dart:799` — The contrast threshold can choose white text while the label is over the unfilled track; fix its color/placement.
- [N3] PR #55 `lib/src/features/story/story_service.dart:79` — Common Arabic stopwords may dominate top terms; define a small evidence-based exclusion policy before filtering.
- [N4] PR #55 `lib/src/data/repositories/event_search_repository.dart:198` — Terms rank by document count but display occurrence counts; align ranking or explain the document-frequency basis.
- [N5] PR #56 `lib/src/features/analytics/analytics_service.dart:53` — `AnalyticsSnapshot.isEmpty` is unused and differs from the screen condition; remove or align it when touching analytics.
- [N6] PR #57 `lib/src/data/repositories/conversation_repository.dart:148` — Repeated conversation/attachment lookups may slow large archives; measure representative data before changing queries or adding indexes.
- [N7] PR #57 `lib/src/data/repositories/conversation_repository.dart:83` — `last_sender` is mapped but unused by service/screen; remove the unused subquery/field in a small cleanup.
- [N8] PR #58 `lib/src/features/media/media_screen.dart:157` — Gallery headings, filters, empty/error states and retry copy remain Arabic in English mode; localize this screen in a bounded follow-up, not a broad i18n refactor.
- [N9] PR #58 `lib/src/features/media/media_screen.dart:303` — The fixed side column/four-column grid may crowd tiles near 800px; verify a narrow desktop layout and stack/reduce columns if needed.
- [N10] PR #58 `lib/src/features/media/media_screen.dart:632` — The metadata note says size is displayed but tiles show type/year; remove “الحجم,” the smallest correct diff.
- [N11] PR #59 `lib/src/features/people/person_screen.dart:537` — A valid total photo count sits above a four-item preview without a “latest N of M” disclosure; add a short preview caption, not a misleading count change.
- [N12] PR #52 `lib/src/app/app_shell.dart:38` — Section names are bilingual inline switch literals rather than `AppStrings`; centralize only in a bounded strings cleanup.
- [N13] PR #54 `lib/src/features/home/home_screen.dart:61` — Inline Arabic copy remains Arabic in English mode; localize Home's strings in a bounded follow-up.
- [N14] PR #54 `lib/src/features/home/home_screen.dart:595` — Render source locators explicitly LTR and monospace for readability in RTL.
- [N15] PR #54 `lib/src/features/home/home_screen.dart:362` — “ملفي” and “الأشخاص” shortcuts share the People destination; remove or distinguish the duplicate affordance.
- [N16] PR #55 `lib/src/features/story/story_screen.dart:297` — Year/busiest/bar-max aggregation happens in the widget; move it into the snapshot only if a small cleanup improves clarity.
- [N17] PR #55 `test/features/story_screen_test.dart:79` — Add coverage for StoryScreen's error and retry state.
- [N18] PR #56 `lib/src/features/analytics/analytics_screen.dart:39` — Inline Arabic labels remain in English mode; localize analytics copy in a bounded follow-up.
- [N19] PR #56 `lib/src/features/analytics/analytics_screen.dart:569` — Fixed chart label/value heights can shrink labels through `FittedBox` at large text scales; verify readability and reflow if needed.
- [N20] PR #57 `lib/src/features/messages/messages_screen.dart:432` — Initial thread scroll may leave newest messages below the viewport; verify and scroll to newest if reproducible.
- [N21] PR #57 `lib/src/features/messages/messages_service.dart:164` — A null sender can win the primary-sender tie-break and misalign bubbles; prevent unknown from displacing a named sender.
- [N22] PR #58 `lib/src/features/media/media_screen.dart:47` — Arabic error/header/tile/empty/privacy strings remain untranslated; coordinate with N8 in the same screen-local localization chore.
- [N23] PR #59 `lib/src/features/people/person_screen.dart:60` — Person-screen errors, controls, sections and month labels remain Arabic in English mode; localize this screen in a bounded follow-up.

## Applied

- [F1] `lib/src/app/app_shell.dart` — pushed search route carries an AppBar with an RTL-aware back action (`ValueKey('search-back')`).
- [F2] `lib/src/app/app_shell.dart` — `_buildImportRoute` wraps the legacy import page in one route with a back action (`ValueKey('import-page-back')`), so the page itself is untouched.
- [F3] `lib/src/data/repositories/overview_repository.dart` — archive-wide totals no longer require a timestamp; the year filter still restricts by year.
- [F6] `lib/src/features/story/story_service.dart` — emptiness decided from all stored events, including undated rows.
- [F4] `lib/src/features/home/home_controller.dart` — home snapshot invalidated when the workspace is deleted.
- [F7] `lib/src/features/analytics/analytics_controller.dart` — analytics snapshot cleared on deletion.
- [F10] `lib/src/features/messages/messages_controller.dart` — messages snapshot and selection cleared on deletion.
- [F11] `lib/src/features/media/media_controller.dart` — media snapshot cleared on deletion.
- [F5] `lib/src/features/story/story_screen.dart` — «أكثر شخص راسلته» → «أكثر مُرسِل» + caption stating the sender is as exported and may be the owner.
- [F14] `lib/src/features/people/person_screen.dart` — chart, empty state and total now say "sent by this person" instead of "exchanged".
- [F15] `lib/src/features/people/person_screen.dart` — «ناس قريبين منّها» → «أكثر المُرسِلين في أرشيفك», chip «ترتيب عام».
- [F16] `lib/src/features/people/person_screen.dart` — «أرقام بيناتكم» → «أرقام هذا الشخص».
- [F8] `lib/src/data/repositories/overview_repository.dart` + `lib/src/features/analytics/analytics_service.dart` — `countsByYear(eventType: null)` counts every dated event; the chips use it.
- [F9] `lib/src/data/repositories/conversation_repository.dart` + `lib/src/features/messages/messages_service.dart` — conversations can be read by `id`; the service opens the requested thread instead of the first of the capped list.
- [F12] `lib/src/features/people/person_service.dart` — the requested person id is read directly; no substitution by the ranking's first row.
- [F13] same read path as F9 — a person's conversation opens the requested thread.
