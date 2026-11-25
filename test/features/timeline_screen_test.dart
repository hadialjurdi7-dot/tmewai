import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_screen.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-timeline-ui-');
    database = AppDatabase(NativeDatabase.memory());
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/friends/message_1.json',
          jsonEncode({
            'title': 'Friends',
            'messages': [
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698796800000,
                'content': 'first of november',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698800000000,
                'content': 'also first of november',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698883200000,
                'content': 'second of november',
              },
              {
                'sender_name': 'Fixtures Person',
                'content': 'timestamp missing',
              },
            ],
          }),
        ),
      );
    final file = File('${tempDirectory.path}/timeline.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> pumpTimeline(
    WidgetTester tester, {
    Size size = const Size(1600, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineRepositoryProvider.overrideWith(
            (ref) async => TimelineRepository(database),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TimelineScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows exact day buckets and the unknown date bucket', (
    tester,
  ) async {
    await pumpTimeline(tester);

    expect(find.text('2023-11-01'), findsOneWidget);
    expect(find.text('2 events'), findsOneWidget);
    expect(find.text('2023-11-02'), findsOneWidget);
    expect(find.text('1 event'), findsNWidgets(2));
    expect(find.text('Unknown date'), findsOneWidget);
    expect(find.textContaining('timestamp'), findsWidgets);
  });

  testWidgets(
    'a 5,000-event archive builds only visible groups and a page of rows',
    (tester) async {
      final importRow = await (database.select(
        database.imports,
      )..limit(1)).getSingle();
      final sourceFile = await (database.select(
        database.sourceFiles,
      )..limit(1)).getSingle();
      await database.batch((batch) {
        for (var day = 0; day < 42; day++) {
          for (var index = 0; index < 120; index++) {
            final at = DateTime.utc(
              2024,
              1,
              1,
            ).add(Duration(days: day, minutes: index));
            batch.insert(
              database.events,
              EventsCompanion.insert(
                importId: importRow.id,
                sourceFileId: sourceFile.id,
                sourceLocator: 'large/$day/$index',
                platform: 'facebook',
                eventType: index.isEven ? 'post' : 'comment',
                timezoneStatus: TimezoneStatus.utc,
                timestampNormalized: Value(at),
                textContent: Value('large-event-$day-$index'),
              ),
            );
          }
        }
      });

      final watch = Stopwatch()..start();
      await pumpTimeline(tester, size: const Size(1200, 800));
      watch.stop();

      // 5,044 records: the 42 seeded days plus the three fixture buckets.
      expect(
        find.text('5,044 events across 45 groups'),
        findsOneWidget,
        reason: 'counts must come from SQL, not a built list',
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));

      final builtRows = find.byType(TimelineEventRow).evaluate().length;
      expect(builtRows, greaterThan(0));
      // The eager shape built every one of the 45 groups and 3 rows per group
      // (135 rows). A lazy sliver with 10-row pages stays well below that.
      expect(builtRows, lessThan(100));

      final builtGroups = find
          .byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'timeline-bucket-',
                ),
          )
          .evaluate()
          .length;
      debugPrint(
        'timeline 5,044 records: ${watch.elapsedMilliseconds}ms, '
        'built $builtGroups/45 groups, $builtRows rows',
      );
      expect(builtGroups, greaterThan(0));
      expect(builtGroups, lessThan(45));

      // The type filter still narrows both the counts and the groups.
      await tester.tap(find.byKey(const Key('timeline-type-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('comment').last);
      await tester.pumpAndSettle();

      expect(find.text('2,520 events across 42 groups'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('timeline-count-2024-01-01')),
            )
            .data,
        '60 events',
      );
    },
  );

  testWidgets('switching grouping shows month counts', (tester) async {
    await pumpTimeline(tester);
    expect(find.text('2023-11-01'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('2023-11'), findsOneWidget);
    expect(find.text('3 events'), findsOneWidget);
    expect(find.text('2023-11-01'), findsNothing);
    expect(find.text('Unknown date'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('2023-11-01'), findsOneWidget);
    expect(find.text('2023-11'), findsNothing);
  });
}
