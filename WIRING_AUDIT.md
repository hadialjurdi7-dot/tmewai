# WIRING AUDIT — Thread C (2026-10-31, branch `auto/qa`)

Method: read every screen's provider → `*_service` → repository → SQL for 12 screens; verdict is WIRED only when the drawn values come from that chain. `TASKS_AUTO.md` scope: report defects, do not fix screens/repositories here.

| Screen | Chain (proof) | Verdict |
|---|---|---|
| home | `home_screen.dart:25` → `home_controller.dart:11-19` → `home_service.dart:53` → `overview_repository.dart:240` + `timeline_repository.dart:70` | WIRED |
| story | `story_screen.dart:32` → `story_controller.dart:9-17` → `story_service.dart:147` → `overview_repository.dart:240`, `event_search_repository.dart:183`, `attachment_repository.dart:101` | WIRED |
| analytics | `analytics_screen.dart:22` → `analytics_controller.dart:23-30` → `analytics_service.dart:124` → `overview_repository.dart:149/178/207`, `event_search_repository.dart:183` | WIRED |
| messages | `messages_screen.dart:40` → `messages_controller.dart:8/31` → `messages_service.dart:115` → `conversation_repository.dart:74/131/146` | WIRED |
| media | `media_screen.dart:50` → `media_controller.dart:8/28` → `media_service.dart:92` → `attachment_repository.dart:78/101/159` | WIRED |
| person | `person_screen.dart:42` → `person_controller.dart:10/31` → `person_service.dart:143` → `person_repository.dart:61/110/128` | WIRED |
| people | no roster screen: `app_shell.dart:204` renders `PersonScreen`; only list is `snapshot.people` at `person_screen.dart:146/1004` fed by `overview_repository.dart:120` | WIRED (profile only) — defect D2 |
| search | `search_screen.dart:31` → `search_controller.dart:151/125` → `event_search_repository.dart:22` | WIRED |
| timeline | `timeline_screen.dart:38` → `timeline_controller.dart:103` → `timeline_service.dart:76` → `timeline_repository.dart:39/97` | WIRED |
| settings | `settings_screen.dart:46` → `settings_controller.dart:26` → `workspace_service.dart:83/219`, `ai_consent_repository.dart:31` | WIRED |
| import | `app.dart:179-190` → `import_controller.dart:17/84` → `import_coordinator.dart:165-178` → `facebook_json_importer.dart` | WIRED |
| overview | `overview_screen.dart:17` → `overview_controller.dart:14` → `overview_service.dart:98` → `overview_repository.dart:40`; drill-down `overview_screen.dart:234` → `event_search_repository.dart:99` | WIRED |

No screen displays a literal number or a mock list: every numeric widget takes a snapshot field (e.g. `home_screen.dart:251-254`, `analytics_screen.dart:148`), and no numeric `Text('…')` literal exists in `lib/src/features/**/*_screen.dart`. Media tiles are metadata-only by design (`media_screen.dart:12-17`), not mock rows.

## Defects (not fixed here)

- **D1 (medium, wrong number)** — `media_screen.dart:220` labels `MediaSnapshot.selectedCount` «صورة», but `media_service.dart:93` sums `attachment_repository.countsByYear()` which has **no `media_type` filter** (`attachment_repository.dart:78-90`), while the grid it labels filters `image` (`media_service.dart:107`). Any video/audio attachment inflates the header and year-chip counts above the images shown. Unit mismatch at the service boundary, same class as fixed #61/#62.
- **D2 (medium, dead surface)** — «الأشخاص» has no people screen: `app_shell.dart:204` renders one person's profile; the only list is the 5-row sidebar (`person_screen.dart:1004`) with no "view all" route. The `people` tab cannot browse the archive.
- **D3 (medium, navigation)** — `overview` and `timeline` are reachable only from `ImportHomePage`'s sidebar (`app.dart:207-211`); the shell (`app_shell.dart`) has no entry, so they are unreachable unless the import page is open.
- **D4 (low, dead affordance)** — home feed tabs `home_screen.dart:615-645` and the pill at `:609` do nothing; `app_shell.dart:347` notification button is `onPressed: () {}`.
- **D5 (low, stale after delete)** — deletion resets only the messages selection and marks `workspaceDeletedProvider` (`settings_controller.dart:67-70`); it invalidates no snapshot. Home/analytics/media/messages rebuild empty because they watch that flag (`home_controller.dart:20`, `analytics_controller.dart:34`, `media_controller.dart:30`, `messages_controller.dart:33`), but `person_controller.dart:31`, `story_controller.dart:17` and `overview_controller.dart:14` do not, so those three keep pre-delete rows on screen until an import runs `_refreshArchiveScreens` (`import_controller.dart:126-135`).
