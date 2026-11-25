import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late ImportCoordinator coordinator;

  setUpAll(() {
    // Each test opens its own in-memory database on purpose.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'pda-import-coordinator-',
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

  /// A real ZIP holding one supported messages file plus one media file.
  Future<File> writeArchive({String name = 'export.zip'}) async {
    final messages = jsonEncode({
      // Tied to the file name so two fixtures are two different archives.
      'title': 'Fixture thread $name',
      'messages': [
        {
          'sender_name': 'Fixtures A',
          'content': 'مَرْحَبًا بِالْعَالَمِ',
          'timestamp_ms': 1767225600000,
        },
        {
          'sender_name': 'Fixtures B',
          'content': 'birthday plans',
          'timestamp_ms': 1767225660000,
        },
        // Malformed record: counted as skipped, never guessed.
        42,
      ],
    });
    final archive = Archive()
      ..addFile(ArchiveFile.string('messages/inbox/message_1.json', messages))
      ..addFile(ArchiveFile.string('photos/image.jpg', 'fake image bytes'));
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  Future<int> countRows(String table) async {
    final row = await database
        .customSelect('SELECT COUNT(*) AS row_count FROM $table')
        .getSingle();
    return row.read<int>('row_count');
  }

  test('persists a scanned archive and its records are searchable', () async {
    final file = await writeArchive();

    final outcome = await coordinator.importArchive(file) as ImportOutcome;

    expect(outcome.reusedExistingImport, isFalse);
    expect(outcome.events, 2);
    // One row per reported file: the messages JSON plus the media file.
    expect(outcome.sourceFiles, 2);
    expect(outcome.people, 2);
    expect(outcome.conversations, 1);
    expect(outcome.skippedRecords, 1);
    expect(outcome.warnings, contains('invalid_message_record'));

    expect(await countRows('imports'), 1);
    expect(await countRows('source_files'), 2);
    expect(await countRows('people'), 2);
    expect(await countRows('conversations'), 1);
    expect(await countRows('events'), 2);

    final importRow = await database.select(database.imports).getSingle();
    expect(importRow.status.name, 'completed');
    expect(importRow.sourceFingerprint, startsWith('sha256:'));

    final sourceFiles = await (database.select(
      database.sourceFiles,
    )..orderBy([(table) => OrderingTerm.asc(table.relativePath)])).get();
    expect(sourceFiles.first.importId, outcome.importId);
    expect(sourceFiles.first.relativePath, 'messages/inbox/message_1.json');
    expect(sourceFiles.first.parseStatus.name, 'parsed');
    expect(sourceFiles.last.relativePath, 'photos/image.jpg');
    expect(sourceFiles.last.parseStatus.name, 'skipped');
    expect(sourceFiles.last.errorCode, 'unsupported_media');

    // The FTS index saw the events written in the same transaction.
    final search = EventSearchRepository(database);
    final arabic = await search.searchEvents('مرحبا');
    expect(arabic, hasLength(1));
    expect(
      arabic.single.sourceLocator,
      'messages/inbox/message_1.json#/messages/0',
    );

    final english = await search.searchEvents('birthday');
    expect(english, hasLength(1));
    expect(english.single.eventId, isNot(arabic.single.eventId));

    // Coverage of the same run, and its totals stored with the import.
    final coverage = coordinator.lastCoverageReport;
    expect(coverage, isNotNull);
    expect(coverage!.totalFiles, 2);
    expect(coverage.supportedFiles, 1);
    expect(coverage.entries.first.reason.code, 'supported');
    expect(coverage.entries.last.reason.code, 'unsupported_media');
    expect(importRow.coverageJson, contains('"supported_files":1'));
  });

  test('leaves the database empty when the archive is corrupt', () async {
    final file = File('${tempDirectory.path}/broken.zip');
    await file.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

    await expectLater(
      coordinator.importArchive(file),
      throwsA(
        isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'archive_invalid',
        ),
      ),
    );

    expect(await countRows('imports'), 0);
    expect(await countRows('source_files'), 0);
    expect(await countRows('events'), 0);
    await expectLater(
      EventSearchRepository(database).searchEvents('birthday'),
      completion(isEmpty),
    );

    // The rejected archive is still reported, by code and without any path.
    final coverage = coordinator.lastCoverageReport;
    expect(coverage, isNotNull);
    expect(coverage!.blockedFiles, 1);
    expect(coverage.supportedPercent, 0);
    expect(coverage.blockedPercent, 100);
    expect(coverage.entries.single.reason.code, 'invalid_archive');
    expect(coverage.entries.single.relativePath, isNull);
    expect(
      '${coverage.counts}${coverage.entries.single.reason.code}',
      isNot(contains(tempDirectory.path)),
    );
  });

  test('rolls back every row when the write fails part way through', () async {
    final file = await writeArchive();

    // Force the event insert to abort after the import and source file rows of
    // the same transaction have already been written.
    await database.customStatement(
      'CREATE TRIGGER test_fail_events BEFORE INSERT ON events BEGIN '
      "SELECT RAISE(ABORT, 'forced failure'); END;",
    );

    await expectLater(
      coordinator.importArchive(file),
      throwsA(
        isA<ImportException>().having(
          (error) => error.code,
          'code',
          'import_write_failed',
        ),
      ),
    );

    expect(await countRows('imports'), 0);
    expect(await countRows('source_files'), 0);
    expect(await countRows('events'), 0);
    expect(await countRows('people'), 0);
  });

  test('importing the same archive twice keeps one import row', () async {
    final file = await writeArchive();

    final first = await coordinator.importArchive(file) as ImportOutcome;
    final second = await coordinator.importArchive(file) as ImportOutcome;

    expect(first.reusedExistingImport, isFalse);
    expect(second.reusedExistingImport, isTrue);
    expect(second.importId, first.importId);
    expect(second.events, first.events);

    expect(await countRows('imports'), 1);
    expect(await countRows('events'), 2);
    expect(
      await EventSearchRepository(database).searchEvents('birthday'),
      hasLength(1),
    );

    // The reused import still reports its coverage, rebuilt from its rows.
    final coverage = coordinator.lastCoverageReport;
    expect(coverage, isNotNull);
    expect(coverage!.totalFiles, 2);
    expect(coverage.supportedFiles, 1);
    expect(coverage.entries.last.reason.code, 'unsupported_media');
  });

  test('a different archive becomes its own import', () async {
    final first = await writeArchive(name: 'first.zip');
    final second = await writeArchive(name: 'second.zip');

    final firstOutcome = await coordinator.importArchive(first) as ImportOutcome;
    final secondOutcome = await coordinator.importArchive(second) as ImportOutcome;

    expect(secondOutcome.reusedExistingImport, isFalse);
    expect(secondOutcome.importId, isNot(firstOutcome.importId));
    expect(await countRows('imports'), 2);
    expect(await countRows('events'), 4);
    // People are shared across imports instead of duplicated.
    expect(await countRows('people'), 2);
  });

  test(
    'rejects an archive above the configured limits without writing',
    () async {
      // The coordinator builds its importer on this inspector, so the entry-count
      // limit is enforced before the transaction starts.
      final tight = ImportCoordinator(
        database: database,
        inspector: const ExportInspector(
          limits: ArchiveInspectionLimits(maxEntries: 1),
        ),
      );

      await expectLater(
        tight.importArchive(await writeArchive()),
        throwsA(
          isA<ArchiveInspectionException>().having(
            (error) => error.code,
            'code',
            'entry_count_limit',
          ),
        ),
      );
      expect(await countRows('imports'), 0);
      expect(await countRows('events'), 0);
    },
  );
}
