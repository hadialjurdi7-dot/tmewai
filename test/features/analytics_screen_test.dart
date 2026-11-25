import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_controller.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_screen.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_service.dart';

AnalyticsSnapshot _snapshotFor(int? year) {
  final isAll = year == null;
  final events = isAll ? 4500 : 700;
  final messages = isAll ? 4000 : 600;
  final days = isAll ? 1000 : 200;
  final months = [
    for (var month = 1; month <= 12; month++)
      (
        month: month,
        count: isAll ? (month == 3 ? 1200 : 100) : (month == 3 ? 400 : 20),
      ),
  ];
  final hours = [
    for (var hour = 0; hour < 24; hour++)
      (
        hour: hour,
        count: isAll ? (hour == 21 ? 900 : hour % 4) : (hour == 21 ? 300 : 2),
      ),
  ];
  return AnalyticsSnapshot(
    selectedYear: year,
    years: const [2023, 2021, 2020, 2019],
    totals: ArchiveTotals(
      messages: messages,
      photos: isAll ? 120 : 30,
      people: isAll ? 40 : 12,
      days: days,
      events: events,
      first: DateTime.utc(2011, 5, 3),
      last: DateTime.utc(2023, 6, 1),
    ),
    months: months,
    hours: hours,
    types: isAll
        ? const [
            AnalyticsType(type: 'message', count: 4000),
            AnalyticsType(type: 'post', count: 300),
            AnalyticsType(type: 'comment', count: 200),
            AnalyticsType(type: 'reaction', count: 100),
            AnalyticsType(type: 'attachment', count: 50),
          ]
        : const [
            AnalyticsType(type: 'message', count: 600),
            AnalyticsType(type: 'post', count: 60),
            AnalyticsType(type: 'comment', count: 40),
          ],
    people: isAll
        ? const [
            AnalyticsPerson(id: 1, name: 'ليلى خالد', count: 1200),
            AnalyticsPerson(id: 2, name: 'عمر بيطار', count: 800),
          ]
        : const [AnalyticsPerson(id: 2, name: 'عمر بيطار', count: 300)],
    terms: const [
      AnalyticsTerm(term: 'الله', occurrences: 6420),
      AnalyticsTerm(term: 'تمام', occurrences: 4550),
      AnalyticsTerm(term: 'تسلم', occurrences: 3910),
      AnalyticsTerm(term: 'وينك', occurrences: 2510),
      AnalyticsTerm(term: 'مافي', occurrences: 2120),
      AnalyticsTerm(term: 'بيعطيك', occurrences: 1820),
    ],
    longestConversationCount: 2140,
    busiestYear: 2023,
    busiestYearCount: 3000,
  );
}

const _emptyAnalytics = AnalyticsSnapshot(
  selectedYear: null,
  years: [],
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  months: [],
  hours: [],
  types: [],
  people: [],
);

Future<void> pumpAnalytics(
  WidgetTester tester, {
  AnalyticsSnapshot Function(int? year)? snapshot,
}) async {
  tester.view.physicalSize = const Size(1600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The fake reads the controller's filter, so the test exercises the
        // same path the real provider uses: tap a chip, results change.
        analyticsSnapshotProvider.overrideWith((ref) async {
          final year = ref.watch(analyticsYearProvider);
          return (snapshot ?? _snapshotFor)(year);
        }),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: AnalyticsScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the filter strip offers the three newest years plus All', (
    tester,
  ) async {
    await pumpAnalytics(tester);

    expect(find.byKey(const Key('analytics-filters')), findsOneWidget);
    expect(find.byKey(const Key('analytics-year-all')), findsOneWidget);
    for (final year in [2019, 2020, 2021]) {
      expect(find.byKey(Key('analytics-year-$year')), findsOneWidget);
    }
    expect(find.byKey(const Key('analytics-year-2023')), findsNothing);
    expect(find.text('كل السنوات'), findsOneWidget);
  });

  testWidgets('the four indicator cards read real aggregates', (tester) async {
    await pumpAnalytics(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-kpi-longest')),
        matching: find.text('2,140'),
      ),
      findsOneWidget,
    );
    // 4000 messages over 1000 covered days.
    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-kpi-daily')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-kpi-year')),
        matching: find.text('2023'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-kpi-types')),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('monthly and hourly charts keep every bar and the peak', (
    tester,
  ) async {
    await pumpAnalytics(tester);

    expect(find.byKey(const Key('analytics-months')), findsOneWidget);
    expect(find.text('المجموع: 2,300 رسالة'), findsOneWidget);
    for (var month = 1; month <= 12; month++) {
      expect(find.byKey(Key('analytics-month-$month')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-month-3')),
        matching: find.text('1,200'),
      ),
      findsOneWidget,
    );

    expect(find.byKey(const Key('analytics-hours')), findsOneWidget);
    for (var hour = 0; hour < 24; hour++) {
      expect(find.byKey(Key('analytics-hour-$hour')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-hour-21')),
        matching: find.text('900'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ذروة اليوم: 9م'), findsOneWidget);
  });

  testWidgets('the words card lists the indexed terms in order', (
    tester,
  ) async {
    await pumpAnalytics(tester);

    expect(find.byKey(const Key('analytics-words')), findsOneWidget);
    expect(find.text('أكثر الكلمات اللي كتبتها'), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-word-الله')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-word-بيعطيك')), findsOneWidget);
    expect(find.text('6,420'), findsOneWidget);
  });

  testWidgets('the shares card excludes messages and totals its categories', (
    tester,
  ) async {
    await pumpAnalytics(tester);

    expect(find.byKey(const Key('analytics-shares')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-share-post')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-share-message')), findsNothing);
    // 300 of 650 shares are posts: 46%.
    expect(find.text('300 (46%)'), findsOneWidget);
    expect(find.text('إجمالي المشاركات: 650'), findsOneWidget);
    expect(find.byKey(const Key('analytics-local-footer')), findsOneWidget);
  });

  testWidgets('tapping a year chip changes the results', (tester) async {
    await pumpAnalytics(tester);

    await tester.tap(find.byKey(const Key('analytics-year-2020')));
    await tester.pumpAndSettle();

    expect(find.text('المجموع: 620 رسالة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('analytics-kpi-daily')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(find.text('60 (60%)'), findsOneWidget);
  });

  testWidgets('a filtered year with no rows says so and can be reset', (
    tester,
  ) async {
    await pumpAnalytics(
      tester,
      snapshot: (year) => year == 2021
          ? AnalyticsSnapshot(
              selectedYear: 2021,
              years: const [2023, 2021],
              totals: const ArchiveTotals(
                messages: 0,
                photos: 0,
                people: 0,
                days: 0,
                events: 0,
              ),
              months: const [],
              hours: const [],
              types: const [],
              people: const [],
            )
          : _snapshotFor(year),
    );

    await tester.tap(find.byKey(const Key('analytics-year-2021')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
    expect(find.text('ما في بيانات لهذه السنة'), findsOneWidget);

    await tester.tap(find.byKey(const Key('analytics-show-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analytics-empty')), findsNothing);
    expect(find.text('المجموع: 2,300 رسالة'), findsOneWidget);
  });

  testWidgets('an empty archive shows one honest card', (tester) async {
    await pumpAnalytics(tester, snapshot: (_) => _emptyAnalytics);

    expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
    expect(find.text('ما في تحليلات بعد'), findsOneWidget);
    expect(find.byKey(const Key('analytics-months')), findsNothing);
    expect(find.byKey(const Key('analytics-local-footer')), findsNothing);
  });

  testWidgets('Arabic renders right-to-left and chips keep 44px targets', (
    tester,
  ) async {
    await pumpAnalytics(tester);

    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('analytics-screen'))),
      ),
      TextDirection.rtl,
    );
    expect(
      tester.getSize(find.byKey(const Key('analytics-year-all'))).height,
      greaterThanOrEqualTo(44),
    );
  });
}
