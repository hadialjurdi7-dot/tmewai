import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/features/overview/overview_service.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;
  late OverviewStats stats;
  late int importId;
  late int messageFileId;
  late int postFileId;
  late int conversationA;
  late int conversationB;
  late int personA;
  late int personB;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:overview',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    messageFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'messages/inbox/friends/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    postFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'posts/your_posts_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    conversationA = await database
        .into(database.conversations)
        .insert(
          ConversationsCompanion.insert(
            importId: importId,
            sourceConversationId: const Value('friends'),
            title: const Value('Friends'),
          ),
        );
    conversationB = await database
        .into(database.conversations)
        .insert(
          ConversationsCompanion.insert(
            importId: importId,
            sourceConversationId: const Value('family'),
            title: const Value('Family'),
          ),
        );
    personA = await database
        .into(database.people)
        .insert(
          PeopleCompanion.insert(platform: 'facebook', displayName: 'Ali'),
        );
    personB = await database
        .into(database.people)
        .insert(
          PeopleCompanion.insert(platform: 'facebook', displayName: 'Sara'),
        );

    Future<void> addEvent({
      required String type,
      required int fileId,
      DateTime? timestamp,
      int? conversationId,
      int? actorId,
      required String text,
    }) async {
      await database
          .into(database.events)
          .insert(
            EventsCompanion.insert(
              importId: importId,
              sourceFileId: fileId,
              sourceLocator: '$fileId#/$text',
              platform: 'facebook',
              eventType: type,
              timezoneStatus: timestamp == null
                  ? TimezoneStatus.unknown
                  : TimezoneStatus.utc,
              timestampNormalized: Value(timestamp?.toUtc()),
              actorId: Value(actorId),
              conversationId: Value(conversationId),
              textContent: Value(text),
            ),
          );
    }

    await addEvent(
      type: 'message',
      fileId: messageFileId,
      timestamp: DateTime.utc(2023, 11, 1, 9),
      conversationId: conversationA,
      actorId: personA,
      text: 'a1',
    );
    await addEvent(
      type: 'message',
      fileId: messageFileId,
      timestamp: DateTime.utc(2023, 11, 1, 10),
      conversationId: conversationA,
      actorId: personB,
      text: 'a2',
    );
    await addEvent(
      type: 'message',
      fileId: messageFileId,
      timestamp: DateTime.utc(2023, 11, 2, 8),
      conversationId: conversationB,
      actorId: personA,
      text: 'b1',
    );
    await addEvent(
      type: 'post',
      fileId: postFileId,
      timestamp: DateTime.utc(2023, 11, 2, 12),
      text: 'p1',
    );
    await addEvent(
      type: 'comment',
      fileId: postFileId,
      actorId: personA,
      text: 'c1',
    );

    stats = await OverviewService(OverviewRepository(database)).load();
  });

  tearDown(() => database.close());

  Future<int> referenceCount(String where) async {
    final row = await database
        .customSelect('SELECT COUNT(*) AS c FROM events WHERE $where')
        .getSingle();
    return row.read<int>('c');
  }

  test(
    'totals, period and unknown timestamps match reference queries',
    () async {
      expect(stats.totalEvents, await referenceCount('1 = 1'));
      expect(
        stats.datedCount,
        await referenceCount('timestamp_normalized IS NOT NULL'),
      );
      expect(
        stats.unknownCount,
        await referenceCount('timestamp_normalized IS NULL'),
      );
      expect(stats.unknownCount, 1);
      expect(stats.unknownCard.value, 1);
      expect(stats.unknownCard.drillDown.hasTimestamp, isFalse);
      expect(stats.activityCard.value, 4);
      expect(stats.firstTimestamp, DateTime.utc(2023, 11, 1, 9));
      expect(stats.lastTimestamp, DateTime.utc(2023, 11, 2, 12));
    },
  );

  test('archive-wide totals include undated events but yearly totals do not', () async {
    final repository = OverviewRepository(database);
    final all = await repository.archiveTotals();
    final year = await repository.archiveTotals(year: 2023);

    expect(all.events, 5);
    expect(all.messages, 3);
    expect(all.people, 2);
    expect(year.events, 4);
    expect(year.messages, 3);
  });

  test('photo totals count images and exclude video/audio', () async {
    final eventId = await database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            importId: importId,
            sourceFileId: messageFileId,
            sourceLocator: 'messages/inbox/friends/message_1.json#/photo-test',
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.utc,
            timestampNormalized: Value(DateTime.utc(2023, 4, 1)),
          ),
        );
    for (final mediaType in ['image', 'video', 'audio']) {
      await database
          .into(database.attachments)
          .insert(
            AttachmentsCompanion.insert(
              eventId: Value(eventId),
              sourceFileId: messageFileId,
              mediaType: mediaType,
              sizeBytes: 1,
            ),
          );
    }

    final repository = OverviewRepository(database);
    expect((await repository.archiveTotals()).photos, 1);
    expect((await repository.archiveTotals(year: 2023)).photos, 1);
  });

  test('daily and event-type counts match reference queries', () async {
    expect(
      {for (final day in stats.dayBuckets) day.key: day.count},
      {'2023-11-01': 2, '2023-11-02': 2},
    );
    expect(
      {for (final type in stats.eventTypes) type.label: type.value},
      {'message': 3, 'post': 1, 'comment': 1},
    );

    for (final type in stats.eventTypes) {
      expect(type.value, await referenceCount("event_type = '${type.label}'"));
    }
  });

  test('top conversations, people and files match reference queries', () async {
    expect(
      {for (final item in stats.conversations) item.label: item.value},
      {'Friends': 2, 'Family': 1},
    );
    expect(
      {for (final item in stats.people) item.label: item.value},
      {'Ali': 2, 'Sara': 1},
    );
    expect(
      {for (final item in stats.sourceFiles) item.label: item.value},
      {
        'messages/inbox/friends/message_1.json': 3,
        'posts/your_posts_1.json': 2,
      },
    );

    final friends = stats.conversations.first;
    final messagesInFriends = await database
        .customSelect(
          'SELECT COUNT(*) AS c FROM events WHERE conversation_id = ? '
          "AND event_type = 'message'",
          variables: [Variable<int>(conversationA)],
        )
        .getSingle();
    expect(friends.value, messagesInFriends.read<int>('c'));
  });

  test('every card predicate reproduces exactly its counted records', () async {
    final search = EventSearchRepository(database);
    final cards = <OverviewStat>[
      stats.activityCard,
      stats.unknownCard,
      ...stats.eventTypes,
      ...stats.conversations,
      ...stats.people,
      ...stats.sourceFiles,
    ];

    for (final card in cards) {
      final drill = card.drillDown;
      final records = await search.filterEvents(
        from: drill.from,
        to: drill.to,
        eventType: drill.eventType,
        conversationId: drill.conversationId,
        actorId: drill.actorId,
        sourceFileId: drill.sourceFileId,
        hasTimestamp: drill.hasTimestamp,
      );
      expect(
        records.length,
        card.value,
        reason: '${card.label} counts ${card.value}',
      );
    }

    for (final day in stats.dayBuckets) {
      final records = await search.filterEvents(
        from: day.drillDown.from,
        to: day.drillDown.to,
        hasTimestamp: true,
      );
      expect(records.length, day.count, reason: day.key);
    }
  });
}
