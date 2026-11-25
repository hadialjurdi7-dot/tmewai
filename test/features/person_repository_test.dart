import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/person_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';

/// Query tests for the paged per-person read the profile list uses.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;
  late PersonRepository repository;
  late int personId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = PersonRepository(database);
    final importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'fingerprint',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: 'test',
            status: ImportStatus.completed,
          ),
        );
    final sourceFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'messages/inbox/leila/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    personId = await database
        .into(database.people)
        .insert(
          PeopleCompanion.insert(
            platform: 'facebook',
            platformPersonId: const Value('fb-1'),
            displayName: 'ليلى',
          ),
        );
    // Five dated messages and one undated, plus a message with no body that the
    // page must skip exactly like the count.
    final rows = <({DateTime? at, String? text})>[
      (at: DateTime.utc(2020, 1, 1), text: 'أ'),
      (at: DateTime.utc(2020, 1, 2), text: 'ب'),
      (at: DateTime.utc(2020, 1, 3), text: 'ج'),
      (at: DateTime.utc(2020, 1, 4), text: 'د'),
      (at: DateTime.utc(2020, 1, 5), text: 'ه'),
      (at: null, text: 'و'),
      (at: DateTime.utc(2020, 1, 6), text: null),
    ];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      await database
          .into(database.events)
          .insert(
            EventsCompanion.insert(
              importId: importId,
              sourceFileId: sourceFileId,
              sourceLocator: 'locator-$index',
              platform: 'facebook',
              eventType: 'message',
              timestampNormalized: Value(row.at),
              timezoneStatus: TimezoneStatus.utc,
              actorId: Value(personId),
              textContent: Value(row.text),
            ),
          );
    }
  });

  tearDown(() async {
    await database.close();
  });

  test('the page is newest first and drops undated rows last', () async {
    final rows = await repository.messagePage(personId, limit: 10);

    expect([for (final row in rows) row.text], ['ه', 'د', 'ج', 'ب', 'أ', 'و']);
  });

  test('pages never repeat or skip a row', () async {
    final first = await repository.messagePage(personId, limit: 2);
    final second = await repository.messagePage(
      personId,
      limit: 2,
      offset: 2,
    );
    final third = await repository.messagePage(
      personId,
      limit: 2,
      offset: 4,
    );

    expect([for (final row in first) row.text], ['ه', 'د']);
    expect([for (final row in second) row.text], ['ج', 'ب']);
    expect([for (final row in third) row.text], ['أ', 'و']);
    final ids = {
      for (final row in [...first, ...second, ...third]) row.id,
    };
    expect(ids.length, 6);
  });

  test('the total counts exactly the rows the page can return', () async {
    expect(await repository.textMessageCount(personId), 6);
  });

  test('the profile carries the exported platform id', () async {
    final profile = await repository.profile(personId);

    expect(profile, isNotNull);
    expect(profile!.name, 'ليلى');
    expect(profile.platformPersonId, 'fb-1');
    expect(profile.messageCount, 7);
  });

  test('a non-positive limit or negative offset is rejected', () async {
    expect(
      () => repository.messagePage(personId, limit: 0),
      throwsArgumentError,
    );
    expect(
      () => repository.messagePage(personId, limit: 5, offset: -1),
      throwsArgumentError,
    );
  });
}
