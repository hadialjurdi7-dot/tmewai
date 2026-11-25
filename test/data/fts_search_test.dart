import 'dart:io';

import 'package:drift/drift.dart'
    show MigrationStrategy, Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/database/event_search_schema.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';

/// The schema as it shipped in version 1: every declared table, but no FTS5
/// index yet.
class _SchemaV1Database extends AppDatabase {
  _SchemaV1Database(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
  );
}

/// The schema as it shipped in version 4, before the Arabic fold/reindex.
class _SchemaV4Database extends AppDatabase {
  _SchemaV4Database(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await createEventSearchIndex(this);
    },
  );
}

void main() {
  late AppDatabase database;
  late EventSearchRepository repository;
  late int importId;
  late int sourceFileId;

  setUpAll(() {
    // Tests open several connections on purpose (one per test plus two
    // sequential ones on a file for the migration test).
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = EventSearchRepository(database);
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:fixture',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    sourceFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> insertEvent({
    required String locator,
    required String eventType,
    String? text,
    DateTime? timestamp,
  }) {
    return database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            importId: importId,
            sourceFileId: sourceFileId,
            sourceLocator: locator,
            platform: 'facebook',
            eventType: eventType,
            timezoneStatus: TimezoneStatus.explicitOffset,
            textContent: Value(text),
            timestampNormalized: Value(timestamp?.toUtc()),
          ),
        );
  }

  test('matches an Arabic word with and without diacritics', () async {
    final diacritized = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'مَرْحَبًا بِالْعَالَمِ',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'رسالة عادية بدون الكلمة',
    );

    // Without diacritics in the query.
    final plain = await repository.searchEvents('مرحبا');
    expect(plain.map((hit) => hit.eventId), [diacritized]);
    expect(plain.single.sourceLocator, 'messages/inbox/message_1.json#0');

    // With diacritics in the query.
    final withDiacritics = await repository.searchEvents('مَرْحَبًا');
    expect(withDiacritics.map((hit) => hit.eventId), [diacritized]);

    // The unrelated Arabic event is not returned by either spelling.
    expect(await repository.searchEvents('رسالة'), hasLength(1));
  });

  test('folds common Arabic spellings while preserving stored text', () async {
    final originals = <String>[
      'أحمد',
      'إسلام',
      'قرآن',
      'مصطفى',
      'حياة',
      'مـرحـبا',
    ];
    final queries = <String>['احمد', 'اسلام', 'قران', 'مصطفي', 'حياه', 'مرحبا'];
    final ids = <int>[];
    for (var index = 0; index < originals.length; index++) {
      ids.add(
        await insertEvent(
          locator: 'messages/inbox/message_1.json#$index',
          eventType: 'message',
          text: originals[index],
        ),
      );
    }

    for (var index = 0; index < queries.length; index++) {
      final hits = await repository.searchEvents(queries[index]);
      expect(hits.map((hit) => hit.eventId), [
        ids[index],
      ], reason: 'plain spelling ${queries[index]} finds ${originals[index]}');
    }
    final stored = await (database.select(
      database.events,
    )..where((event) => event.id.equals(ids.first))).getSingle();
    expect(stored.textContent, 'أحمد');
  });

  test('Arabic folds do not collapse حية and حياة', () async {
    final hayah = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'حية',
    );
    final life = await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'حياة',
    );

    expect((await repository.searchEvents('حيه')).map((hit) => hit.eventId), [
      hayah,
    ]);
    expect((await repository.searchEvents('حياه')).map((hit) => hit.eventId), [
      life,
    ]);
  });

  test(
    'strips an Arabic subscript alef from the index and the query',
    () async {
      // U+0656 is not one of the common harakat and used to survive
      // normalization, splitting the word into two tokens.
      final indexed = await insertEvent(
        locator: 'messages/inbox/message_1.json#0',
        eventType: 'message',
        text: 'مٖرحبا بالعالم',
      );

      final hits = await repository.searchEvents('مرحبا');

      expect(hits.map((hit) => hit.eventId), [indexed]);
    },
  );

  test('matches an English word and ignores irrelevant events', () async {
    final birthday = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'Happy birthday to you',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'unrelated text',
    );

    final hits = await repository.searchEvents('birthday');

    expect(hits.map((hit) => hit.eventId), [birthday]);
    expect(hits.single.textContent, 'Happy birthday to you');
    expect(await repository.searchEvents('birthdayyy'), isEmpty);
    expect(await repository.searchEvents(''), isEmpty);
    expect(await repository.searchEvents('   '), isEmpty);
  });

  test('a multi-word query requires every word', () async {
    final both = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'alpha synthetic record',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'alpha only record',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#2',
      eventType: 'message',
      text: 'synthetic only record',
    );

    final hits = await repository.searchEvents('alpha synthetic');

    expect(hits.map((hit) => hit.eventId), [both]);
  });

  test('filters by date range and by event type', () async {
    final old = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'shared word from a message',
      timestamp: DateTime.utc(2024, 1, 1),
    );
    final recent = await insertEvent(
      locator: 'posts/your_posts.json#0',
      eventType: 'post',
      text: 'shared word from a post',
      timestamp: DateTime.utc(2026, 1, 1),
    );

    final all = await repository.searchEvents('shared');
    expect(all.map((hit) => hit.eventId), [recent, old]);

    final ranged = await repository.searchEvents(
      'shared',
      from: DateTime.utc(2025, 1, 1),
    );
    expect(ranged.map((hit) => hit.eventId), [recent]);

    final byType = await repository.searchEvents('shared', eventType: 'post');
    expect(byType.map((hit) => hit.eventId), [recent]);

    final emptyRange = await repository.searchEvents(
      'shared',
      from: DateTime.utc(2026, 2, 1),
      to: DateTime.utc(2026, 3, 1),
    );
    expect(emptyRange, isEmpty);
  });

  test('respects limit and offset', () async {
    for (var index = 0; index < 3; index++) {
      await insertEvent(
        locator: 'messages/inbox/message_1.json#$index',
        eventType: 'message',
        text: 'paged word $index',
        timestamp: DateTime.utc(2026, 1, 1 + index),
      );
    }

    final firstPage = await repository.searchEvents('paged', limit: 2);
    expect(firstPage, hasLength(2));
    expect(firstPage.map((hit) => hit.eventId), [3, 2]);

    final secondPage = await repository.searchEvents(
      'paged',
      limit: 2,
      offset: 2,
    );
    expect(secondPage.map((hit) => hit.eventId), [1]);
  });

  test('reindexes an event when its text is updated', () async {
    final eventId = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'first wording',
    );

    expect(await repository.searchEvents('wording'), hasLength(1));

    await (database.update(database.events)
          ..where((row) => row.id.equals(eventId)))
        .write(const EventsCompanion(textContent: Value('second phrasing')));

    expect(await repository.searchEvents('wording'), isEmpty);
    final hits = await repository.searchEvents('phrasing');
    expect(hits.map((hit) => hit.eventId), [eventId]);
  });

  test('drops an event from the index when the event is deleted', () async {
    final eventId = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'removable marker',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'kept marker',
    );

    expect(await repository.searchEvents('marker'), hasLength(2));

    await (database.delete(
      database.events,
    )..where((row) => row.id.equals(eventId))).go();

    final hits = await repository.searchEvents('marker');
    expect(hits, hasLength(1));
    expect(hits.single.eventId, isNot(eventId));
  });

  test('treats injection-like input as text', () async {
    await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'safe content',
    );

    final hits = await repository.searchEvents("'; DROP TABLE events;--");

    expect(hits, isEmpty);
    // The schema is untouched: both tables still answer.
    expect(await database.select(database.events).get(), hasLength(1));
    final stillSearchable = await repository.searchEvents('safe');
    expect(stillSearchable, hasLength(1));
  });

  test('sorts undated events after dated events', () async {
    // A null timestamp must not be treated as the Unix epoch: an undated event
    // would then sort ahead of a pre-1970 dated event.
    final dated = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'ordering marker',
      timestamp: DateTime.utc(1960, 1, 1),
    );
    final undated = await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'ordering marker',
    );

    final hits = await repository.searchEvents('ordering');

    expect(hits.map((hit) => hit.eventId), [dated, undated]);
  });

  test('adds the search index when upgrading a version 1 database', () async {
    final directory = await Directory.systemTemp.createTemp('pda-fts-upgrade-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/schema.sqlite';

    final version1 = _SchemaV1Database(NativeDatabase(File(path)));
    await version1.customSelect('SELECT 1').get();
    final untracked = await version1
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'event_search'",
        )
        .get();
    expect(untracked, isEmpty);

    // Seed the v1 database with events that existed before the index did.
    final legacyImport = await version1
        .into(version1.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:legacy',
            startedAt: DateTime.utc(2020, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    final legacyFile = await version1
        .into(version1.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: legacyImport,
            relativePath: 'messages/inbox/legacy.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    await version1
        .into(version1.events)
        .insert(
          EventsCompanion.insert(
            importId: legacyImport,
            sourceFileId: legacyFile,
            sourceLocator: 'messages/inbox/legacy.json#0',
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.explicitOffset,
            textContent: const Value('legacy archived note'),
          ),
        );
    await version1.close();

    final upgraded = AppDatabase(NativeDatabase(File(path)));
    await upgraded.customSelect('SELECT 1').get();
    expect(upgraded.schemaVersion, greaterThan(1));

    // Rows that predate the trigger must be indexed by the migration, not
    // only rows inserted after it.
    final legacyHits = await EventSearchRepository(upgraded)
        .searchEvents('legacy');
    expect(legacyHits, hasLength(1));
    expect(legacyHits.single.sourceLocator, 'messages/inbox/legacy.json#0');

    final import = await upgraded
        .into(upgraded.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:fixture',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    final file = await upgraded
        .into(upgraded.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: import,
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    await upgraded
        .into(upgraded.events)
        .insert(
          EventsCompanion.insert(
            importId: import,
            sourceFileId: file,
            sourceLocator: 'messages/inbox/message_1.json#0',
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.explicitOffset,
            textContent: const Value('upgraded index works'),
          ),
        );

    final hits = await EventSearchRepository(upgraded).searchEvents('upgraded');
    expect(hits, hasLength(1));

    await upgraded.close();
  });

  test('v5 rebuilds stale Arabic index rows once from stored events', () async {
    final directory = await Directory.systemTemp.createTemp('pda-fts-v5-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/schema.sqlite';

    final version4 = _SchemaV4Database(NativeDatabase(File(path)));
    await version4.customSelect('SELECT 1').get();
    final legacyImport = await version4
        .into(version4.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:legacy-v4',
            startedAt: DateTime.utc(2020, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    final legacyFile = await version4
        .into(version4.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: legacyImport,
            relativePath: 'messages/inbox/legacy.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    final eventId = await version4
        .into(version4.events)
        .insert(
          EventsCompanion.insert(
            importId: legacyImport,
            sourceFileId: legacyFile,
            sourceLocator: 'messages/inbox/legacy.json#0',
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.explicitOffset,
            textContent: const Value('أحمد legacy'),
          ),
        );
    // Simulate the v4 index containing pre-fold text for the event.
    await version4.customStatement(
      'DELETE FROM event_search WHERE event_id = ?',
      [eventId],
    );
    await version4.customStatement(
      'INSERT INTO event_search (event_id, text_content, source_locator) '
      'VALUES (?, ?, ?)',
      [eventId, 'أحمد legacy', 'messages/inbox/legacy.json#0'],
    );
    await version4.close();

    final upgraded = AppDatabase(NativeDatabase(File(path)));
    await upgraded.customSelect('SELECT 1').get();
    final legacyHits = await EventSearchRepository(upgraded)
        .searchEvents('احمد');
    expect(legacyHits.map((hit) => hit.eventId), [eventId]);
    final stored = await (upgraded.select(
      upgraded.events,
    )..where((event) => event.id.equals(eventId))).getSingle();
    expect(stored.textContent, 'أحمد legacy');
    expect(
      await upgraded
          .customSelect(
            'SELECT COUNT(*) AS n FROM event_search WHERE event_id = ?',
            variables: [Variable<int>(eventId)],
          )
          .map((row) => row.read<int>('n'))
          .getSingle(),
      1,
    );
    await upgraded.close();

    // Opening the already-upgraded database again must not append another FTS row.
    final reopened = AppDatabase(NativeDatabase(File(path)));
    await reopened.customSelect('SELECT 1').get();
    expect(
      await reopened
          .customSelect(
            'SELECT COUNT(*) AS n FROM event_search WHERE event_id = ?',
            variables: [Variable<int>(eventId)],
          )
          .map((row) => row.read<int>('n'))
          .getSingle(),
      1,
    );
    await reopened.close();
  });

  test('ranks terms by occurrences, matching the count the card prints', () async {
    // One message repeats a word three times; another word appears once in each
    // of two messages. The cards show occurrence counts, so the repeated word
    // must lead instead of losing to the word with more documents.
    await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      eventType: 'message',
      text: 'عيد عيد عيد',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#1',
      eventType: 'message',
      text: 'سفر',
    );
    await insertEvent(
      locator: 'messages/inbox/message_1.json#2',
      eventType: 'message',
      text: 'سفر',
    );

    final terms = await repository.topTerms(limit: 2);

    expect(terms.first.term, 'عيد');
    expect(terms.first.occurrences, 3);
    expect(terms.first.documents, 1);
    expect(terms.last.term, 'سفر');
    expect(terms.last.occurrences, 2);
    expect(terms.last.documents, 2);
  });
}
