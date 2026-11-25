import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/import_progress.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late ImportCoordinator coordinator;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-progress-test-');
    database = AppDatabase(NativeDatabase.memory());
    coordinator = ImportCoordinator(database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  const messagesPath = 'messages/inbox/friends/message_1.json';

  /// A ZIP with one messages file holding [count] synthetic messages.
  Future<File> writeArchive(int count, {String name = 'a.zip'}) async {
    final messages = [
      for (var index = 0; index < count; index++)
        {
          'sender_name': 'Fixtures Person',
          'timestamp_ms': 1700000000000 + index,
          'content': 'Synthetic message $index',
        },
    ];
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          messagesPath,
          jsonEncode({'title': 'Friends', 'messages': messages}),
        ),
      );
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

  test('emits ordered progress events ending with a completed phase', () async {
    final file = await writeArchive(3);
    final events = <ImportProgress>[];
    final subscription = coordinator.progress.listen(events.add);

    final result = await coordinator.importArchive(file) as ImportOutcome;
    await pumpEventQueue();
    await subscription.cancel();

    expect(result.events, 3);
    expect(events, isNotEmpty);
    expect(events.first.phase, ImportPhase.inspecting);
    expect(events.last.phase, ImportPhase.completed);
    expect(events.last.recordsWritten, 3);
    expect(events.last.filesDone, events.last.filesTotal);

    const approvedOrder = [
      ImportPhase.inspecting,
      ImportPhase.parsing,
      ImportPhase.writing,
      ImportPhase.completed,
    ];
    var lastIndex = 0;
    var lastFilesDone = 0;
    for (final event in events) {
      final index = approvedOrder.indexOf(event.phase);
      expect(index, greaterThanOrEqualTo(lastIndex), reason: '$event');
      lastIndex = index;
      expect(
        event.filesDone,
        greaterThanOrEqualTo(lastFilesDone),
        reason: 'progress never goes backwards: $event',
      );
      lastFilesDone = event.filesDone;
      if (event.phase == ImportPhase.writing) {
        expect(event.currentRelativePath, messagesPath);
        expect(event.currentRelativePath, isNot(startsWith('/')));
        expect(event.currentRelativePath, isNot(contains(tempDirectory.path)));
      }
    }

    final writing = events.where((event) => event.phase == ImportPhase.writing);
    expect(writing, isNotEmpty);
    expect(
      events.where((event) => event.phase == ImportPhase.parsing),
      isNotEmpty,
    );
  });

  test(
    'cancelling mid-import rolls back every row and deletes staging',
    () async {
      final file = await writeArchive(600);
      final staging = Directory('${tempDirectory.path}/staging');
      await staging.create(recursive: true);
      await File('${staging.path}/partial.bin').writeAsBytes([1, 2, 3]);

      final cancelling = ImportCoordinator(
        database: database,
        stagingDirectory: staging,
      );
      final token = CancelToken();
      final subscription = cancelling.progress.listen((event) {
        if (event.phase == ImportPhase.writing) token.cancel();
      });

      final result = await cancelling.importArchive(file, cancelToken: token);
      await pumpEventQueue();
      await subscription.cancel();

      expect(result, isA<ImportCancelled>());
      final cancelled = result as ImportCancelled;
      expect(cancelled.rowsWritten, 0);
      expect(cancelled.phase, ImportPhase.writing);

      expect(await countRows('imports'), 0);
      expect(await countRows('source_files'), 0);
      expect(await countRows('people'), 0);
      expect(await countRows('conversations'), 0);
      expect(await countRows('events'), 0);
      expect(await countRows('attachments'), 0);
      expect(await countRows('event_search'), 0);
      expect(await staging.exists(), isFalse, reason: 'staging was deleted');
    },
  );

  test('cancelling after the write phase leaves the database healthy', () async {
    final databasePath = '${tempDirectory.path}/progress.sqlite';
    final fileDatabase = AppDatabase.atPath(
      databasePath,
      tempDirectoryPath: tempDirectory.path,
    );
    final fileCoordinator = ImportCoordinator(database: fileDatabase);
    final completedToken = CancelToken();
    final subscription = fileCoordinator.progress.listen((event) {
      if (event.phase == ImportPhase.completed) completedToken.cancel();
    });

    final first = await fileCoordinator.importArchive(
      await writeArchive(5, name: 'first.zip'),
    ) as ImportOutcome;
    await pumpEventQueue();

    // The write phase is done; a token cancelled now must not undo or corrupt
    // the committed import.
    final again = await fileCoordinator.importArchive(
      await writeArchive(5, name: 'second.zip'),
      cancelToken: completedToken,
    );
    await pumpEventQueue();
    await subscription.cancel();

    expect(first.events, 5);
    expect(again, isA<ImportCancelled>());

    final events = await fileDatabase.select(fileDatabase.events).get();
    expect(events, hasLength(5));
    final searchRows = await fileDatabase
        .customSelect('SELECT COUNT(*) AS row_count FROM event_search')
        .getSingle();
    expect(searchRows.read<int>('row_count'), 5);
    expect(await fileDatabase.select(fileDatabase.imports).get(), hasLength(1));
    await fileDatabase.close();

    // Reopening the same file and querying proves the database is intact.
    final reopened = AppDatabase.atPath(
      databasePath,
      tempDirectoryPath: tempDirectory.path,
    );
    try {
      expect(await reopened.select(reopened.imports).get(), hasLength(1));
      expect(await reopened.select(reopened.events).get(), hasLength(5));
      final reopenedSearch = await reopened
          .customSelect('SELECT COUNT(*) AS row_count FROM event_search')
          .getSingle();
      expect(reopenedSearch.read<int>('row_count'), 5);
    } finally {
      await reopened.close();
    }
  });
}
