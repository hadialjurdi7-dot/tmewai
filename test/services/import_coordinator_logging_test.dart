import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/logging/redacted_log.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/import_progress.dart';

class _RecordingSink implements LogSink {
  final List<MapEntry<String, Map<String, Object?>>> events = [];

  @override
  void emit(String event, Map<String, Object?> fields) {
    events.add(MapEntry(event, Map<String, Object?>.of(fields)));
  }

  Iterable<Map<String, Object?>> named(String name) =>
      events.where((entry) => entry.key == name).map((entry) => entry.value);

  bool containsText(String needle) => events.any(
        (entry) => entry.key.contains(needle) ||
            entry.value.values.any((value) => '$value'.contains(needle)),
      );
}

class _ThrowingSink implements LogSink {
  @override
  void emit(String event, Map<String, Object?> fields) {
    throw StateError('sink is unavailable');
  }
}

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late _RecordingSink sink;
  late ImportCoordinator coordinator;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-log-test-');
    database = AppDatabase(NativeDatabase.memory());
    sink = _RecordingSink();
    coordinator = ImportCoordinator(
      database: database,
      log: RedactedLog(sink),
    );
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

  test('records started and completed with their counts', () async {
    final file = await writeArchive(3);

    final result = await coordinator.importArchive(file) as ImportOutcome;

    final started = sink.named('import.started').single;
    expect(started['level'], 'info');
    expect(started['platform'], 'facebook');
    expect(started['sourceKind'], 'archive');

    final completed = sink.named('import.completed').single;
    expect(completed['events'], result.events);
    expect(completed['events'], 3);
    expect(completed['importId'], result.importId);
    expect(completed['sourceFiles'], result.sourceFiles);
    expect(completed['warnings'], 0);
    expect(sink.named('import.failed'), isEmpty);
  });

  test('records a failure with a catalog code instead of a bare message', () async {
    final notAnArchive = File('${tempDirectory.path}/broken.zip');
    await notAnArchive.writeAsString('this is not a zip archive');

    await expectLater(
      coordinator.importArchive(notAnArchive),
      throwsA(isA<Exception>()),
    );

    final failed = sink.named('import.failed').single;
    expect(failed['level'], 'error');
    expect(failed['code'], isA<String>());
    expect((failed['code'] as String).isNotEmpty, isTrue);
    expect(failed['errorClass'], 'ArchiveInspectionException');
    expect(failed['phase'], 'parsing');

    // The redaction rule: no host path and no file content leaves the process.
    expect(sink.containsText(tempDirectory.path), isFalse);
    expect(sink.containsText('this is not a zip archive'), isFalse);
  });

  test('records a deduplicated import when the same archive is imported twice',
      () async {
    final file = await writeArchive(2);

    await coordinator.importArchive(file);
    sink.events.clear();
    await coordinator.importArchive(file);

    final deduplicated = sink.named('import.deduplicated').single;
    expect(deduplicated['events'], 2);
    expect(sink.named('import.completed'), isEmpty);
  });

  test('records a cancelled import with the phase it stopped in', () async {
    final file = await writeArchive(3);
    final token = CancelToken()..cancel();

    final result = await coordinator.importArchive(file, cancelToken: token);

    expect(result, isA<ImportCancelled>());
    final cancelled = sink.named('import.cancelled').single;
    expect(cancelled['phase'], 'inspecting');
    expect(cancelled['filesDone'], 0);
  });

  test('records a failure when the source cannot be read', () async {
    final missing = File('${tempDirectory.path}/does-not-exist.zip');

    await expectLater(
      coordinator.importArchive(missing),
      throwsA(isA<FileSystemException>()),
    );

    final failed = sink.named('import.failed').single;
    expect(failed['level'], 'error');
    expect(failed['code'], 'import_unexpected_failed');
    expect(failed['phase'], 'inspecting');
    expect(failed['errorClass'], 'PathNotFoundException');

    // The redaction rule still holds on the generic failure path.
    expect(sink.containsText(tempDirectory.path), isFalse);
  });

  test('a throwing sink does not change an import result', () async {
    final file = await writeArchive(2);
    final throwingCoordinator = ImportCoordinator(
      database: database,
      log: RedactedLog(_ThrowingSink()),
    );

    final result = await throwingCoordinator.importArchive(file);

    expect(result, isA<ImportOutcome>());
    expect((result as ImportOutcome).events, 2);
    expect(result.reusedExistingImport, isFalse);
  });
}
