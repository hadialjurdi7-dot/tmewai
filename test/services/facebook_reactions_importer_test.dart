import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late ImportCoordinator coordinator;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'pda-reactions-test-',
    );
    database = AppDatabase(NativeDatabase.memory());
    coordinator = ImportCoordinator(database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> writeZip(String body, {String name = 'a.zip'}) async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'your_facebook_activity/likes_and_reactions/likes_and_reactions.json',
          body,
        ),
      );
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  const actor = 'Fixtures Person';

  /// One reaction file entry, as exported: a timestamp and a data list.
  Map<String, dynamic> nestedEntry(
    int timestamp,
    List<(String, String?)> reactions,
  ) => {
    'timestamp': timestamp,
    'data': [
      for (final (token, person) in reactions)
        {
          'reaction': {'reaction': token, 'actor': ?person},
        },
    ],
  };

  test(
    'parses the list shape and keeps the emoji reaction as metadata',
    () async {
      final file = await writeZip(
        jsonEncode([
          nestedEntry(1700000000, [('👍', actor)]),
        ]),
      );

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, hasLength(1));
      final record = result.records.single;
      expect(record.eventType, 'reaction');
      expect(record.senderName, actor);
      expect(record.text, isNull, reason: 'a reaction has no text of its own');
      expect(record.metadata, {'reaction': '👍'});
      expect(record.conversationKey, isNull);
      expect(
        record.sourceLocator,
        'your_facebook_activity/likes_and_reactions/likes_and_reactions.json'
        '#/reactions/0/data/0',
      );
      expect(record.timestampRaw, '1700000000');
      expect(
        record.timestampUtc,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(result.supportedFiles, 1);
      expect(result.warnings, isNot(contains('no_supported_files_found')));
    },
  );

  test(
    'parses the newer reactions object shape with several reactions',
    () async {
      final file = await writeZip(
        jsonEncode({
          'reactions': [
            nestedEntry(1700000000, [('❤️', actor), ('👍', null)]),
            nestedEntry(1700000100, [('😂', actor)]),
          ],
        }),
      );

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, hasLength(3));
      expect(
        result.records.map((record) => record.eventType),
        everyElement('reaction'),
      );
      expect(result.records.map((record) => record.metadata?['reaction']), [
        '❤️',
        '👍',
        '😂',
      ]);
      expect(
        result.records[1].senderName,
        isNull,
        reason: 'a missing actor is left null, not invented',
      );
      expect(
        result.records.last.sourceLocator,
        endsWith('#/reactions/1/data/0'),
        reason: 'the locator points at the exact reaction',
      );
    },
  );

  test('accepts the reactions_v2 list key used by Meta exports', () async {
    final file = await writeZip(
      jsonEncode({
        'reactions_v2': [
          nestedEntry(1700000000, [('❤️', actor)]),
        ],
      }),
    );

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(1));
    expect(result.records.single.eventType, 'reaction');
    expect(
      result.records.single.sourceLocator,
      endsWith('#/reactions_v2/0/data/0'),
    );
    expect(result.files.single.status, FacebookPreviewFileStatus.parsed);
    expect(result.warnings, isNot(contains('unsupported_reactions_json')));
  });

  test('keeps an unknown reaction token without crashing', () async {
    final file = await writeZip(
      jsonEncode([
        nestedEntry(1700000000, [
          ('some_unknown_reaction', actor),
          ('🚀', actor),
        ]),
      ]),
    );

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(2));
    expect(result.records.first.metadata, {
      'reaction': 'some_unknown_reaction',
    });
    expect(result.records.last.metadata, {'reaction': '🚀'});
    expect(result.skippedRecords, 0);
    expect(result.warnings, isNot(contains('invalid_reaction_record')));
  });

  test('reports a reaction token that cannot be stored', () async {
    final oversizedToken = 'x' * 65;
    final file = await writeZip(
      jsonEncode([
        nestedEntry(1700000000, [(oversizedToken, actor)]),
        {
          'timestamp': 1700000001,
          'data': [
            {
              'reaction': {'reaction': 7, 'actor': 'A'},
            },
          ],
        },
        {'timestamp': 1700000002},
        nestedEntry(9999999999999999, [('👍', actor)]),
      ]),
    );

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(1));
    expect(result.records.single.metadata, {'reaction': '👍'});
    expect(result.records.single.timestampUtc, isNull);
    expect(result.skippedRecords, 3);
    expect(result.warnings, contains('invalid_reaction_record'));
    expect(result.warnings, contains('invalid_reaction_timestamp'));
    expect(result.warnings, isNot(contains('no_supported_files_found')));
  });

  test(
    'classifies an unusable reactions file by its known folder, not as unknown',
    () async {
      final file = await writeZip('{"likes":[]}');

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, isEmpty);
      expect(result.supportedFiles, 0);
      expect(
        result.files.single.status,
        FacebookPreviewFileStatus.knownNotImported,
      );
      expect(result.files.single.errorCode, 'unsupported_reactions_json');
      expect(result.knownNotImportedJsonFiles, 1);
      expect(result.unsupportedJsonFiles, 0);
      expect(result.warnings, contains('known_folders_not_imported'));
      expect(result.warnings, isNot(contains('unsupported_json_files_present')));
      expect(result.warnings, contains('no_supported_files_found'));
    },
  );

  test('rejects an oversized reactions payload', () async {
    final file = await writeZip(
      jsonEncode([
        nestedEntry(1700000000, [('👍', actor)]),
      ]),
    );

    await expectLater(
      const FacebookJsonImporter(maxJsonFileBytes: 4).preview(file),
      throwsA(
        isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'json_file_size_limit',
        ),
      ),
    );
  });

  test('enforces the record count limit on reaction records', () async {
    final file = await writeZip(
      jsonEncode({
        'reactions': [
          nestedEntry(1700000000, [('👍', actor), ('❤️', actor)]),
          nestedEntry(1700000100, [('😂', actor)]),
        ],
      }),
    );

    // Three reaction records, limit of two.
    await expectLater(
      const FacebookJsonImporter(maxRecords: 2).preview(file),
      throwsA(
        isA<FacebookImportException>().having(
          (error) => error.code,
          'code',
          'record_count_limit',
        ),
      ),
    );
  });

  test('persists reactions as events with bounded metadata', () async {
    final file = await writeZip(
      jsonEncode({
        'reactions': [
          nestedEntry(1700000000, [('👍', actor)]),
        ],
      }),
    );

    final outcome = await coordinator.importArchive(file) as ImportOutcome;

    expect(outcome.events, 1);
    expect(outcome.conversations, 0, reason: 'reactions have no conversation');
    expect(outcome.people, 1);
    final coverage = coordinator.lastCoverageReport!;
    expect(coverage.supportedFiles, 1);
    expect(
      coverage.entries.single.reason.code,
      'supported',
      reason: 'reaction files are supported files now',
    );
    expect(coverage.counts['records_parsed'], 1);

    final event = await database.select(database.events).getSingle();
    expect(event.eventType, 'reaction');
    expect(event.metadataJson, '{"reaction":"👍"}');
    expect(event.textContent, isNull);
    expect(event.conversationId, isNull);
    expect(event.actorId, isNotNull);
  });
}
