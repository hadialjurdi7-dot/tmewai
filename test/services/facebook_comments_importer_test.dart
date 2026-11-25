import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/import_coverage_report.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-comments-test-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> writeZip(
    Map<String, String> entries, {
    String name = 'a.zip',
  }) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  test('normalizes comments as comment events with stable locators', () async {
    final file = await writeZip({
      'your_facebook_activity/comments/comments.json':
          '{"comments":['
          '{"author":"ليلى","text":"مَرْحَبًا","timestamp":1700000000},'
          '{"author":"Sam","text":"nice"},'
          '{"author":42,"text":"bad author"}]}',
    });

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(2));
    expect(result.supportedFiles, 1);
    expect(result.skippedRecords, 1);
    expect(result.warnings, contains('invalid_comment_record'));
    expect(result.warnings, isNot(contains('no_supported_files_found')));

    final first = result.records.first;
    expect(first.eventType, 'comment');
    expect(first.sourcePath, 'your_facebook_activity/comments/comments.json');
    expect(
      first.sourceLocator,
      'your_facebook_activity/comments/comments.json#/comments/0',
    );
    expect(first.senderName, 'ليلى');
    expect(first.text, 'مَرْحَبًا');
    expect(
      first.conversationKey,
      isNull,
      reason: 'comments do not belong to a conversation',
    );
    // Comments export Unix seconds; the normalized value is that instant.
    expect(first.timestampRaw, '1700000000');
    expect(
      first.timestampUtc,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );

    expect(result.records.last.eventType, 'comment');
    expect(result.records.last.timestampUtc, isNull);
  });

  test('accepts the comments_v2 list key used by Meta exports', () async {
    final file = await writeZip({
      'your_activity_across_facebook/comments/comments.json':
          '{"comments_v2":[{"author":"ليلى","text":"تعليق تجريبي",'
          '"timestamp":1700000000}]}',
    });

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(1));
    expect(result.records.single.eventType, 'comment');
    expect(
      result.records.single.sourceLocator,
      'your_activity_across_facebook/comments/comments.json#/comments_v2/0',
    );
    expect(result.files.single.status, FacebookPreviewFileStatus.parsed);
    expect(result.warnings, isNot(contains('unsupported_comments_json')));
  });

  test(
    'reports an invalid comments timestamp without inventing a date',
    () async {
      final file = await writeZip({
        'comments/comments.json':
            '{"comments":['
            '{"author":"A","text":"ok","timestamp":9999999999999999}]}',
      });

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, hasLength(1));
      expect(result.records.single.timestampUtc, isNull);
      expect(result.records.single.timestampRaw, isNull);
      expect(result.warnings, contains('invalid_comment_timestamp'));
    },
  );

  test('rejects an oversized comments payload', () async {
    final file = await writeZip({
      'comments/comments.json': '{"comments":[{"author":"A","text":"ok"}]}',
    });

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

    // Several comment records in one file: the count limit is enforced too.
    final manyComments = jsonEncode({
      'comments': [
        for (var index = 0; index < 3; index++)
          {'author': 'A', 'text': 'comment $index'},
      ],
    });
    final tooMany = await writeZip({
      'comments/comments.json': manyComments,
    }, name: 'many.zip');
    await expectLater(
      const FacebookJsonImporter(maxRecords: 0).preview(tooMany),
      throwsArgumentError,
      reason: 'a limit below one is a caller error',
    );
    await expectLater(
      const FacebookJsonImporter(maxRecords: 2).preview(tooMany),
      throwsA(
        isA<FacebookImportException>().having(
          (error) => error.code,
          'code',
          'record_count_limit',
        ),
      ),
    );
  });

  test(
    'classifies a comments file without its key by its known folder',
    () async {
      final file = await writeZip({
        'comments/comments.json': '{"data":[]}',
        'messages/inbox/message_1.json':
            '{"messages":[{"sender_name":"A","content":"hi"}]}',
      });

      final result = await const FacebookJsonImporter().preview(file);

      final commentsFile = result.files.firstWhere(
        (entry) => entry.path == 'comments/comments.json',
      );
      expect(
        commentsFile.status,
        FacebookPreviewFileStatus.knownNotImported,
      );
      expect(commentsFile.errorCode, 'unsupported_comments_json');
      expect(result.warnings, contains('unsupported_comments_json'));
      expect(result.warnings, contains('known_folders_not_imported'));
      expect(result.records.single.eventType, 'message');

      // Through the coordinator the reason surfaces as known_not_imported, and
      // the comments file is stored as skipped rather than crashing.
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final coordinator = ImportCoordinator(database: database);

      await coordinator.importArchive(file) as ImportOutcome;

      final coverage = coordinator.lastCoverageReport;
      expect(coverage, isNotNull);
      final commentsEntry = coverage!.entries.firstWhere(
        (entry) => entry.relativePath == 'comments/comments.json',
      );
      expect(commentsEntry.supported, isFalse);
      expect(commentsEntry.reason, ImportCoverageReason.knownNotImported);

      final stored =
          await (database.select(database.sourceFiles)..where(
                (row) => row.relativePath.equals('comments/comments.json'),
              ))
              .getSingle();
      expect(stored.parseStatus.name, 'skipped');
      // The stored code is the coverage classification, not the importer's
      // internal code, so a stored row and a report always agree.
      expect(stored.errorCode, 'known_not_imported');
    },
  );

  test('imports a mixed archive and marks comments files as supported', () async {
    final file = await writeZip({
      'comments/comments.json':
          '{"comments":[{"author":"A","text":"a comment","timestamp":1700000000}]}',
      'messages/inbox/message_1.json':
          '{"messages":[{"sender_name":"B","content":"a message","timestamp_ms":1700000500000}]}',
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final coordinator = ImportCoordinator(database: database);

    final outcome = await coordinator.importArchive(file) as ImportOutcome;

    expect(outcome.conversations, 1, reason: 'only the message has a thread');
    final events = await database.select(database.events).get();
    expect(
      events.map((event) => event.eventType),
      containsAll(['comment', 'message']),
    );
    expect(events.map((event) => event.sourceLocator), [
      'comments/comments.json#/comments/0',
      'messages/inbox/message_1.json#/messages/0',
    ]);

    final coverage = coordinator.lastCoverageReport!;
    expect(coverage.supportedFiles, 2);
    expect(coverage.supportedPercent, 100);
    expect(coverage.unsupportedFiles, 0);
    expect(
      coverage.entries.every((entry) => entry.reason.code == 'supported'),
      isTrue,
      reason: 'comments files are supported files now',
    );
    expect(coverage.counts['records_parsed'], 2);
  });
}
