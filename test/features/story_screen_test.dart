import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/features/story/story_controller.dart';
import 'package:personal_data_agent/src/features/story/story_screen.dart';
import 'package:personal_data_agent/src/features/story/story_service.dart';

const emptyStory = StorySnapshot(
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  years: [],
  terms: [],
);

StorySnapshot populatedStory() => StorySnapshot(
  totals: ArchiveTotals(
    messages: 4000,
    photos: 120,
    people: 40,
    days: 1000,
    events: 4500,
    first: DateTime.utc(2011, 5, 3),
    last: DateTime.utc(2023, 6, 1),
  ),
  years: const [
    StoryYear(year: 2011, count: 100),
    StoryYear(year: 2019, count: 2500),
    StoryYear(year: 2023, count: 400),
  ],
  terms: const [
    StoryTerm(term: 'الله', occurrences: 640),
    StoryTerm(term: 'الخير', occurrences: 300),
    StoryTerm(term: 'صباح', occurrences: 120),
  ],
  people: const [
    StoryPerson(id: 1, name: 'ليلى خالد', count: 1200),
    StoryPerson(id: 2, name: 'عمر بيطار', count: 800),
  ],
  memories: [
    StoryMemory(id: 7, at: DateTime.utc(2017, 10, 14), mediaType: 'image'),
    StoryMemory(id: 8, at: DateTime.utc(2017, 10, 28), mediaType: 'image'),
  ],
  memoryMonth: 10,
  busiestYear: 2019,
  busiestTotals: ArchiveTotals(
    messages: 2500,
    photos: 60,
    people: 20,
    days: 300,
    events: 2600,
    first: DateTime.utc(2019, 1, 2),
    last: DateTime.utc(2019, 12, 30),
  ),
  topPersonName: 'ليلى خالد',
  topPersonCount: 1200,
  longestConversationCount: 2140,
  busiestMonth: 3,
  recordTypes: 9,
  datedEvents: 4500,
  undatedEvents: 0,
);

Future<void> pumpStory(
  WidgetTester tester, {
  required StorySnapshot snapshot,
  ValueChanged<int>? onOpenYear,
}) async {
  tester.view.physicalSize = const Size(1600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [storySnapshotProvider.overrideWith((ref) async => snapshot)],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StoryScreen(
              importPageBuilder: (context) =>
                  const Text('import-stub', key: Key('import-stub')),
              onOpenYear: onOpenYear,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the hero names the busiest year and its own numbers', (
    tester,
  ) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(find.byKey(const Key('story-hero')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('story-hero-year'))).data,
      'سنة 2019 كانت أكثر سنة حكيت فيها',
    );
    // 2500 messages over 300 covered days.
    expect(
      tester.widget<Text>(find.byKey(const Key('story-hero-daily'))).data,
      'بمعدل 8 رسالة كل يوم',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('story-hero-messages'))).data,
      '2,500',
    );
    expect(find.text('محسوبة من 2,600 حدث مؤرّخ'), findsOneWidget);
  });

  testWidgets('every year is a bar with its own label', (tester) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(find.byKey(const Key('story-year-bars')), findsOneWidget);
    for (final year in ['2011', '2019', '2023']) {
      expect(find.byKey(ValueKey('story-year-$year')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('story-year-2011')),
        matching: find.text('100'),
      ),
      findsOneWidget,
    );
    expect(find.text('المجموع: 3,000 رسالة'), findsOneWidget);
  });

  testWidgets('the people ranking shows a row and a bar per person', (
    tester,
  ) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(find.byKey(const Key('story-people')), findsOneWidget);
    expect(find.text('مع مين كنت تحكي'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-person-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-person-2')), findsOneWidget);
    expect(find.text('ليلى خالد'), findsOneWidget);
    expect(find.text('1,200 رسالة'), findsOneWidget);
    expect(find.text('800 رسالة'), findsOneWidget);
  });

  testWidgets('the memories card shows the month and its two images', (
    tester,
  ) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(find.byKey(const Key('story-memories')), findsOneWidget);
    expect(find.text('ذكريات تشرين الأول'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-memory-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-memory-8')), findsOneWidget);
  });

  testWidgets('quick numbers come from the archive totals', (tester) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(find.byKey(const Key('story-quick-numbers')), findsOneWidget);
    expect(find.text('2011'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
    expect(find.text('2,140 رسالة'), findsOneWidget);
    expect(find.text('آذار'), findsOneWidget);
    // 4000 messages over 1000 covered days.
    expect(find.text('4 رسالة/اليوم'), findsOneWidget);
    expect(find.text('9 أنواع'), findsOneWidget);
  });

  testWidgets('the coverage card reports the dated share', (tester) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(find.byKey(const Key('story-coverage')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('story-coverage-percent'))).data,
      '100%',
    );
    expect(find.byKey(const Key('story-coverage-bar')), findsOneWidget);
    expect(find.byKey(const Key('story-local-only')), findsOneWidget);
  });

  testWidgets('an empty archive shows one import card that opens the page', (
    tester,
  ) async {
    await pumpStory(tester, snapshot: emptyStory);

    expect(find.byKey(const Key('story-empty')), findsOneWidget);
    expect(find.text('ما في أرقام بعد'), findsOneWidget);
    expect(find.byKey(const Key('story-hero')), findsNothing);

    await tester.tap(find.byKey(const Key('story-empty-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-stub')), findsOneWidget);
  });

  testWidgets('the hero link opens the busiest year in analytics', (
    tester,
  ) async {
    int? opened;
    await pumpStory(
      tester,
      snapshot: populatedStory(),
      onOpenYear: (year) => opened = year,
    );

    await tester.tap(find.byKey(const Key('story-hero-open-year')));
    await tester.pumpAndSettle();

    expect(opened, 2019);
  });

  testWidgets('Arabic renders right-to-left and keeps 44px targets', (
    tester,
  ) async {
    await pumpStory(tester, snapshot: populatedStory());

    expect(
      Directionality.of(tester.element(find.byKey(const Key('story-screen')))),
      TextDirection.rtl,
    );
    expect(
      tester.getSize(find.byKey(const Key('story-hero-open-year'))).height,
      greaterThanOrEqualTo(44),
    );
  });
}
