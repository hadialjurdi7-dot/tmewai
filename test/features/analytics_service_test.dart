import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-analytics-');
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
                'timestamp_ms': DateTime.utc(
                  2019,
                  5,
                  10,
                  9,
                  30,
                ).millisecondsSinceEpoch,
                'content': 'a 2019 message',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': DateTime.utc(
                  2020,
                  3,
                  15,
                  14,
                ).millisecondsSinceEpoch,
                'content': 'a 2020 afternoon message',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': DateTime.utc(
                  2020,
                  3,
                  15,
                  23,
                ).millisecondsSinceEpoch,
                'content': 'a 2020 late message',
              },
            ],
          }),
        ),
      );
    final file = File('${tempDirectory.path}/analytics.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'unfiltered months, hours and types come from every stored event',
    () async {
      final snapshot =
          await AnalyticsService(
            OverviewRepository(database),
            EventSearchRepository(database),
          ).load();

      expect(snapshot.selectedYear, isNull);
      expect(snapshot.years, [2020, 2019]);
      expect(snapshot.months.length, 12);
      expect(snapshot.hours.length, 24);
      // March 2020 has two messages, May 2019 one.
      expect(snapshot.months[2].count, 2);
      expect(snapshot.months[4].count, 1);
      expect(snapshot.busiestMonth, 3);
      expect(snapshot.hours[14].count, 1);
      expect(snapshot.hours[23].count, 1);
      expect(snapshot.hours[9].count, 1);
      expect(snapshot.typeTotal, 3);
      expect(snapshot.types.first.type, 'message');
      expect(snapshot.people.first.count, 3);

      // The rebuilt cards: longest thread, busiest year, words and shares.
      expect(snapshot.longestConversationCount, 3);
      expect(snapshot.busiestYear, 2020);
      expect(snapshot.busiestYearCount, 2);
      expect(snapshot.recordTypeCount, 1);
      expect(snapshot.shareTypes, isEmpty);
      expect(snapshot.dailyAverage, 1);
      expect(snapshot.terms, isNotEmpty);
    },
  );

  test('a year filter narrows every card', () async {
    final snapshot =
        await AnalyticsService(
          OverviewRepository(database),
          EventSearchRepository(database),
        ).load(year: 2020);

    expect(snapshot.selectedYear, 2020);
    expect(snapshot.totals.messages, 2);
    expect(snapshot.months[2].count, 2);
    expect(snapshot.months[4].count, 0);
    expect(snapshot.hours[9].count, 0);
    expect(snapshot.hours[23].count, 1);
    expect(snapshot.typeTotal, 2);
    expect(snapshot.people.first.count, 2);
    expect(snapshot.dailyAverage, 2);
  });

  test('the year filter narrows the longest-conversation KPI', () async {
    final service = AnalyticsService(
      OverviewRepository(database),
      EventSearchRepository(database),
    );

    // The thread holds three messages: one in 2019 and two in 2020. The KPI sits
    // beside cards that already narrow with the chip, so it must follow it.
    expect((await service.load()).longestConversationCount, 3);
    expect((await service.load(year: 2019)).longestConversationCount, 1);
    expect((await service.load(year: 2020)).longestConversationCount, 2);
  });
}
