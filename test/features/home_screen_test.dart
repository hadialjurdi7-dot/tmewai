import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/home/home_screen.dart';
import 'package:personal_data_agent/src/features/home/home_service.dart';

const emptySnapshot = HomeSnapshot(
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  topPeople: [],
  latest: [],
);

final populatedSnapshot = HomeSnapshot(
  totals: ArchiveTotals(
    messages: 1234,
    photos: 56,
    people: 7,
    days: 400,
    events: 1290,
    first: DateTime.utc(2011, 5, 3),
    last: DateTime.utc(2023, 6, 1),
  ),
  topPeople: const [
    HomePerson(id: 1, name: 'ليلى خالد', count: 1200),
    HomePerson(id: 2, name: 'عمر بيطار', count: 940),
  ],
  latest: [
    TimelineRow(
      eventId: 11,
      eventType: 'message',
      sourceLocator: 'messages/inbox/one.json',
      timestampNormalized: DateTime.utc(2023, 6, 1),
      textContent: 'أجمل قعدة مع العيلة',
    ),
    TimelineRow(
      eventId: 12,
      eventType: 'post',
      sourceLocator: 'posts/your_posts_1.json',
      timestampNormalized: DateTime.utc(2022, 3, 12),
      textContent: 'كل عام وانتي بخير',
    ),
  ],
);

Future<void> pumpHome(
  WidgetTester tester, {
  required HomeSnapshot snapshot,
}) async {
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [homeSnapshotProvider.overrideWith((ref) async => snapshot)],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: HomeScreen(
              importPageBuilder: (context) =>
                  const Text('import-stub', key: Key('import-stub')),
              onOpenDestination: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty archive shows the feed empty state and shortcuts', (
    tester,
  ) async {
    await pumpHome(tester, snapshot: emptySnapshot);

    expect(find.byKey(const Key('home-activity-empty')), findsOneWidget);
    expect(find.byKey(const Key('home-shortcuts')), findsOneWidget);
    expect(find.byKey(const Key('home-top-people')), findsOneWidget);
    expect(find.text('شو بدك تشوف اليوم؟'), findsOneWidget);
  });

  testWidgets('a populated archive reads every number from the snapshot', (
    tester,
  ) async {
    await pumpHome(tester, snapshot: populatedSnapshot);

    // Greeting range and the four KPI tiles.
    expect(
      find.text('عندك 1,290 حكاية محفوظة من 2011 لليوم (2023)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-kpi-رسالة')), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('13'), findsOneWidget); // 2011..2023 inclusive

    // Top people, with the count written on each bar.
    expect(find.byKey(const Key('home-top-people')), findsOneWidget);
    expect(find.text('ليلى خالد'), findsOneWidget);
    expect(find.text('1,200 رسالة'), findsOneWidget);
    expect(find.text('940 رسالة'), findsOneWidget);

    // Newest records render in the feed.
    expect(find.byKey(const Key('home-activity-11')), findsOneWidget);
    expect(find.text('أجمل قعدة مع العيلة'), findsOneWidget);
    expect(find.byKey(const Key('home-activity-12')), findsOneWidget);
    expect(find.text('كل عام وانتي بخير'), findsOneWidget);

    // Import stays available from the shortcuts column.
    expect(find.byKey(const Key('home-import')), findsOneWidget);
  });

  testWidgets('Arabic renders right-to-left and keeps 44px targets', (
    tester,
  ) async {
    await pumpHome(tester, snapshot: populatedSnapshot);

    expect(
      Directionality.of(tester.element(find.byKey(const Key('home-screen')))),
      TextDirection.rtl,
    );
    final importSize = tester.getSize(find.byKey(const Key('home-import')));
    expect(importSize.height, greaterThanOrEqualTo(44));
    final shortcutSize = tester.getSize(
      find.byKey(const ValueKey('home-shortcut-الرسائل')),
    );
    expect(shortcutSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('owner reference content is present with six shortcuts', (
    tester,
  ) async {
    await pumpHome(tester, snapshot: populatedSnapshot);

    expect(find.text('مساء الخير'), findsOneWidget);
    expect(find.text('أرشيف محلي مفتوح'), findsOneWidget);
    expect(find.byKey(const Key('home-feed-tab-messages')), findsOneWidget);
    expect(find.byKey(const Key('home-feed-tab-media')), findsOneWidget);
    expect(find.byKey(const Key('home-feed-tab-posts')), findsOneWidget);
    expect(find.text('الاختصارات'), findsOneWidget);
    for (final label in const [
      'ملفي',
      'الرسائل',
      'الصور',
      'الذكريات',
      'الأشخاص',
      'الإعدادات',
    ]) {
      expect(
        find.byKey(ValueKey('home-shortcut-$label')),
        findsOneWidget,
        reason: '$label shortcut must be present',
      );
    }
    expect(find.text('1,234'), findsOneWidget);
  });

  testWidgets('the import button opens the existing import page', (
    tester,
  ) async {
    await pumpHome(tester, snapshot: emptySnapshot);

    await tester.tap(find.byKey(const Key('home-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-stub')), findsOneWidget);
  });
}
