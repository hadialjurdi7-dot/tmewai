import 'dart:io';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/import_repository.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';

/// A database that declares a newer schema version than the current code, used
/// to prove the upgrade path of the migration strategy actually runs.
class _FutureSchemaDatabase extends AppDatabase {
  _FutureSchemaDatabase(super.executor);

  /// Always one version ahead, so the probe keeps working when the real
  /// schema version is bumped.
  @override
  int get schemaVersion => super.schemaVersion + 1;
}

void main() {
  setUpAll(() {
    // These tests open more than one connection on purpose (in-memory per test
    // plus two sequential connections to one file for the migration test).
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> storedVersion(AppDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  Future<Set<String>> schemaObjects(AppDatabase db, String type) async {
    final rows = await db
        .customSelect(
          'SELECT name FROM sqlite_master WHERE type = ?',
          variables: [Variable<String>(type)],
        )
        .get();
    return {for (final row in rows) row.read<String>('name')};
  }

  test('creates every table and index on first open', () async {
    final tables = await schemaObjects(database, 'table');

    expect(
      tables,
      containsAll(<String>[
        'imports',
        'source_files',
        'people',
        'conversations',
        'events',
        'attachments',
      ]),
    );

    final indexes = await schemaObjects(database, 'index');
    expect(
      indexes,
      containsAll(<String>[
        'source_files_import_id',
        'conversations_import_id',
        'events_import_id',
        'events_timestamp_normalized',
        'events_event_type',
      ]),
    );
  });

  test(
    'runs the migration strategy, which records the schema version',
    () async {
      // Reading forces the lazily-opened database to run its migration first.
      await database.customSelect('SELECT 1').get();

      expect(await storedVersion(database), database.schemaVersion);

      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);
    },
  );

  test(
    'runs the upgrade path when a database is behind the schema version',
    () async {
      // A stored file is required: migrations are applied once per opened
      // executor, so re-opening an in-memory database cannot exercise them.
      final directory = await Directory.systemTemp.createTemp(
        'pda-drift-migrate-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/schema.sqlite';

      final behind = AppDatabase(NativeDatabase(File(path)));
      await behind.customSelect('SELECT 1').get();
      expect(await storedVersion(behind), behind.schemaVersion);
      await behind.close();

      final upgraded = _FutureSchemaDatabase(NativeDatabase(File(path)));
      await upgraded.customSelect('SELECT 1').get();
      expect(await storedVersion(upgraded), upgraded.schemaVersion);
      expect(await schemaObjects(upgraded, 'table'), contains('events'));
      await upgraded.close();
    },
  );

  test(
    'adds the coverage column when upgrading a version 2 database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pda-drift-migrate-v2-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/schema.sqlite';

      final version2 = AppDatabase(NativeDatabase(File(path)));
      await version2.customSelect('SELECT 1').get();
      // A real v2 database has no coverage column; dropping it and rolling the
      // recorded version back reproduces one.
      await version2.customStatement(
        'ALTER TABLE imports DROP COLUMN coverage_json',
      );
      await version2.customStatement('PRAGMA user_version = 2');
      await version2.close();

      final upgraded = AppDatabase(NativeDatabase(File(path)));
      final columns = await upgraded
          .customSelect('PRAGMA table_info(imports)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        contains('coverage_json'),
      );
      expect(await storedVersion(upgraded), upgraded.schemaVersion);
      await upgraded.close();
    },
  );

  test('inserts an import with its source files and reads them back', () async {
    final repository = ImportRepository(database);

    final importId = await repository.insertImport(
      ImportRecord(
        platform: 'facebook',
        format: 'json',
        sourceFingerprint: 'sha256:fixture',
        startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        completedAt: DateTime.utc(2026, 1, 2, 3, 4, 9),
        importerVersion: '0.1.0',
        status: ImportStatus.completed,
      ),
      const [
        SourceFileRecord(
          relativePath: 'messages/inbox/message_1.json',
          parseStatus: ParseStatus.parsed,
          mediaType: 'application/json',
        ),
        SourceFileRecord(
          relativePath: 'photos/image.jpg',
          parseStatus: ParseStatus.skipped,
          errorCode: 'unsupported_media',
        ),
      ],
    );

    final stored = await repository.findImport(importId);

    expect(stored, isNotNull);
    expect(stored!.importRecord.id, importId);
    expect(stored.importRecord.platform, 'facebook');
    expect(stored.importRecord.status, ImportStatus.completed);
    expect(stored.importRecord.startedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(stored.importRecord.completedAt, DateTime.utc(2026, 1, 2, 3, 4, 9));
    expect(stored.sourceFiles.map((file) => file.relativePath), [
      'messages/inbox/message_1.json',
      'photos/image.jpg',
    ]);
    expect(stored.sourceFiles.first.importId, importId);
    expect(stored.sourceFiles.first.parseStatus, ParseStatus.parsed);
    expect(stored.sourceFiles.last.errorCode, 'unsupported_media');
    expect(await repository.findImport(importId + 999), isNull);
  });

  test('rejects a source file that points at a missing import', () async {
    await expectLater(
      database
          .into(database.sourceFiles)
          .insert(
            SourceFilesCompanion.insert(
              importId: 404,
              relativePath: 'messages/inbox/message_1.json',
              parseStatus: ParseStatus.parsed,
            ),
          ),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('FOREIGN KEY constraint failed'),
          'a foreign-key violation',
        ),
      ),
    );
  });

  test('enforces the schema with a transaction that rolls back', () async {
    final repository = ImportRepository(database);

    await expectLater(
      repository.insertImport(
        ImportRecord(
          platform: 'facebook',
          format: 'json',
          sourceFingerprint: 'sha256:fixture',
          startedAt: DateTime.utc(2026, 1, 2),
          importerVersion: '0.1.0',
          status: ImportStatus.completed,
        ),
        const [
          SourceFileRecord(
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
          // Same path in the same import: the unique key must reject it, and
          // the whole import is rolled back with it.
          SourceFileRecord(
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        ],
      ),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('UNIQUE constraint failed'),
          'a unique-constraint violation',
        ),
      ),
    );

    final rows = await database.select(database.imports).get();
    expect(rows, isEmpty);
  });
}
