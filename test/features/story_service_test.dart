import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/data/repositories/attachment_repository.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/features/story/story_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-story-');
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
                'timestamp_ms': 1560000000000, // 2019
                'content': 'الله كريم الله',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1561000000000, // 2019
                'content': 'صباح الخير يا الله',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1690000000000, // 2023
                'content': 'الله يعطيك العافية',
              },
            ],
          }),
        ),
      );
    final file = File('${tempDirectory.path}/story.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('an undated-only archive is not empty', () async {
    await database.delete(database.events).go();
    final source = await database.select(database.sourceFiles).getSingle();
    await database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            importId: source.importId,
            sourceFileId: source.id,
            sourceLocator: 'undated#1',
            platform: 'facebook',
            eventType: 'post',
            timezoneStatus: TimezoneStatus.unknown,
          ),
        );

    final snapshot = await StoryService(
      OverviewRepository(database),
      EventSearchRepository(database),
      AttachmentRepository(database),
    ).load();

    expect(snapshot.totals.events, 1);
    expect(snapshot.isEmpty, isFalse);
    expect(snapshot.coveragePercent, 0);
    expect(snapshot.busiestMonth, isNull);
    expect(snapshot.people, isEmpty);
  });

  test('the busiest year and word ranking come from stored rows', () async {
    final snapshot = await StoryService(
      OverviewRepository(database),
      EventSearchRepository(database),
      AttachmentRepository(database),
    ).load();

    expect(snapshot.totals.messages, 3);
    expect(snapshot.years.map((year) => year.year), [2019, 2023]);
    expect(snapshot.busiestYear, 2019);
    expect(snapshot.busiestTotals?.messages, 2);
    expect(snapshot.topPersonName, 'Fixtures Person');
    expect(snapshot.topPersonCount, 3);

    // Every figure the rebuilt screen prints, from the same stored rows.
    expect(snapshot.people.single.name, 'Fixtures Person');
    expect(snapshot.people.single.count, 3);
    expect(snapshot.longestConversationCount, 3);
    expect(snapshot.busiestMonth, 6);
    expect(snapshot.recordTypes, 1);
    expect(snapshot.datedEvents, 3);
    expect(snapshot.undatedEvents, 0);
    expect(snapshot.coveragePercent, 100);
    expect(snapshot.memories, isEmpty);
    expect(snapshot.memoryMonth, isNull);

    // «الله» is in all three messages, so it ranks first; the transient
    // vocabulary table left no trace in the database.
    expect(snapshot.terms.first.term, 'الله');
    expect(snapshot.terms.first.occurrences, 4);
    final leftover = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'event_search_terms'",
        )
        .get();
    expect(leftover, isEmpty);
  });
}
