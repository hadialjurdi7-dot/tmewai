import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/app_shell.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_controller.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_service.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/home/home_service.dart';
import 'package:personal_data_agent/src/features/story/story_controller.dart';
import 'package:personal_data_agent/src/features/story/story_service.dart';
import 'package:personal_data_agent/src/features/media/media_controller.dart';
import 'package:personal_data_agent/src/features/media/media_service.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_service.dart';
import 'package:personal_data_agent/src/features/people/person_controller.dart';
import 'package:personal_data_agent/src/features/people/person_service.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';

const emptyStory = StorySnapshot(
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  years: [],
  terms: [],
);

const emptyAnalytics = AnalyticsSnapshot(
  selectedYear: null,
  years: [],
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  months: [],
  hours: [],
  types: [],
  people: [],
);

const emptySnapshot = HomeSnapshot(
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  topPeople: [],
  latest: [],
);

const emptyMessages = MessagesSnapshot(
  conversations: [],
  totalConversations: 0,
  selected: null,
);

const emptyMedia = MediaSnapshot(
  total: 0,
  years: [],
  selectedYear: null,
  items: [],
  people: [],
  matched: 0,
  limit: 60,
);

/// One person with a conversation behind them, so the shell can prove the
/// profile's «افتح المحادثة» action switches to the messages section.
const personSnapshot = PersonSnapshot(
  people: [PersonSummary(id: 1, name: 'ليلى خالد', messageCount: 4)],
  selected: PersonProfile(
    id: 1,
    name: 'ليلى خالد',
    platform: 'facebook',
    messageCount: 4,
    messageTotal: 4,
    photoCount: 0,
    firstAt: null,
    lastAt: null,
    days: 0,
    conversationId: 9,
    years: [],
    lines: [],
    photos: [],
  ),
);

/// Locale that stays fixed, so the assertions are not at the mercy of the
/// machine language.
class _FixedLocaleController extends AppLocaleController {
  _FixedLocaleController(this.mode);

  final AppLocaleMode mode;

  @override
  AppLocaleMode build() => mode;
}

/// Locale store that never touches the filesystem.
class _MemoryLocaleStore extends AppLocaleStore {
  const _MemoryLocaleStore();

  @override
  Future<AppLocaleMode?> read() async => null;

  @override
  Future<void> write(AppLocaleMode mode) async {}
}

void main() {
  Future<void> pumpShell(WidgetTester tester, AppLocaleMode mode) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleModeProvider.overrideWith(
            () => _FixedLocaleController(mode),
          ),
          appLocaleStoreProvider.overrideWithValue(const _MemoryLocaleStore()),
          // The shell test is about navigation, not the archive: the home
          // section renders an empty snapshot without opening a database.
          homeSnapshotProvider.overrideWith((ref) async => emptySnapshot),
          storySnapshotProvider.overrideWith((ref) async => emptyStory),
          analyticsSnapshotProvider.overrideWith((ref) async => emptyAnalytics),
          messagesSnapshotProvider.overrideWith((ref) async => emptyMessages),
          mediaSnapshotProvider.overrideWith((ref) async => emptyMedia),
          personSnapshotProvider.overrideWith((ref) async => personSnapshot),
        ],
        child: MaterialApp(
          home: AppShell(
            importPageBuilder: (context) =>
                const Text('import-page-stub', key: ValueKey('import-stub')),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the seven sections and starts on the first one', (
    tester,
  ) async {
    await pumpShell(tester, AppLocaleMode.en);

    expect(find.byType(ShellTab), findsNWidgets(3));
    for (final section in const [
      TmSection.home,
      TmSection.story,
      TmSection.people,
    ]) {
      expect(
        find.byKey(ValueKey('shell-nav-${section.name}')),
        findsOneWidget,
        reason: '${section.name} must be visible in the top navigation',
      );
    }
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Memories'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    // The brand, search, notifications, and avatar live in the top bar.
    expect(find.text('Tmewai'), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-notifications')), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-avatar')), findsOneWidget);

    expect(find.byKey(const ValueKey('shell-page-home')), findsOneWidget);
    // The first section is the real home screen; the import page opens from it.
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    // A section the user never opened is not built at all, even off stage.
    expect(
      find.byKey(const ValueKey('shell-page-analytics'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('the memories tab opens story and keeps home alive', (
    tester,
  ) async {
    await pumpShell(tester, AppLocaleMode.ar);

    await tester.tap(find.byKey(const ValueKey('shell-nav-story')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<ShellTab>(find.byKey(const ValueKey('shell-nav-story')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('shell-page-story')), findsOneWidget);
    expect(find.byKey(const Key('story-empty')), findsOneWidget);
    expect(find.text('قيد التنفيذ'), findsNothing);
    expect(
      find.byKey(const ValueKey('shell-page-home'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the messages section is the real screen, not a placeholder', (
    tester,
  ) async {
    await pumpShell(tester, AppLocaleMode.ar);

    await tester.tap(find.byKey(const ValueKey('home-shortcut-الرسائل')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('messages-empty')), findsOneWidget);
    expect(find.text('قيد التنفيذ'), findsNothing);
  });

  testWidgets('the media section is the real gallery', (tester) async {
    await pumpShell(tester, AppLocaleMode.ar);

    await tester.tap(find.byKey(const ValueKey('home-shortcut-الصور')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('media-empty')), findsOneWidget);
    expect(find.text('قيد التنفيذ'), findsNothing);
  });

  testWidgets(
    'the person section opens and its chat action moves to messages',
    (tester) async {
      await pumpShell(tester, AppLocaleMode.ar);

      await tester.ensureVisible(
        find.byKey(const ValueKey('home-shortcut-الأشخاص')),
      );
      await tester.tap(find.byKey(const ValueKey('home-shortcut-الأشخاص')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('person-hero')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('person-name'))).data,
        'ليلى خالد',
      );
      expect(find.text('قيد التنفيذ'), findsNothing);

      await tester.tap(find.byKey(const Key('person-hero-chat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Message/detail routes remain reachable from shortcuts without adding
      // tabs beyond the reference's three top-level destinations.
      expect(find.byKey(const Key('messages-empty')), findsOneWidget);
    },
  );

  testWidgets('search route has a visible return to shell navigation', (
    tester,
  ) async {
    await pumpShell(tester, AppLocaleMode.en);

    await tester.tap(find.byKey(const ValueKey('shell-search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('search-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('shell-page-home')), findsOneWidget);
  });

  testWidgets('Arabic mode mirrors the shell and keeps 44px targets', (
    tester,
  ) async {
    await pumpShell(tester, AppLocaleMode.ar);

    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('shell-nav-home'))),
      ),
      TextDirection.rtl,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-search'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('English mode keeps the shell left-to-right', (tester) async {
    await pumpShell(tester, AppLocaleMode.en);

    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('shell-nav-home'))),
      ),
      TextDirection.ltr,
    );
  });
}
