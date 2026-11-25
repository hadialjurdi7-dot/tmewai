import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

/// The folder source is what most people use: they unzip the export themselves
/// and point the app at the folder. It must enforce the same rules the ZIP path
/// enforces, or the two sources drift apart and one of them becomes the way in.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tmewai_folder_');
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Future<File> write(String relative, String content) async {
    final file = File('${temp.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  group('FolderInspector', () {
    test('walks a normal folder and classifies its files', () async {
      await write('messages/inbox/layla/message_1.json', '{"messages":[]}');
      await write('photos/a.jpg', 'binary');
      await write('notes.txt', 'hello');

      final report = await FolderInspector().inspect(temp);

      expect(report.entries, 3);
      expect(report.jsonFiles, 1);
      expect(report.mediaFiles, 1);
      expect(report.ignoredFiles, 1);
      expect(report.warnings, contains('unsupported_files_present'));
    });

    test('reads only the supported JSON shapes on request', () async {
      await write('messages/inbox/layla/message_1.json', '{"messages":[]}');
      await write('other.json', '{}');

      final scan = await FolderInspector().scanJsonFiles(
        temp,
        jsonPathPattern: r'message_\d+\.json$',
      );

      expect(scan.jsonFiles.map((file) => file.path), ['messages/inbox/layla/message_1.json']);
      expect(
        jsonDecode(utf8.decode(scan.jsonFiles.single.bytes)),
        {'messages': <Object>[]},
      );
    });

    test('rejects a folder containing a symbolic link', () async {
      await write('data.json', '{}');
      final link = Link('${temp.path}/escape');
      await link.create('${temp.path}/data.json');

      await expectLater(
        FolderInspector().inspect(temp),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'symbolic_link_rejected',
        )),
      );
    });

    test('applies the same entry and size limits as the ZIP path', () async {
      await write('a.json', '{}');
      await write('b.json', '{}');

      await expectLater(
        const FolderInspector(
          limits: ArchiveInspectionLimits(maxEntries: 1),
        ).inspect(temp),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'entry_count_limit',
        )),
      );
    });

    test('counts directories toward the entry limit', () async {
      // A tree of empty directories must not be able to slip past the limit:
      // the walk stops as soon as the folder holds more entries than allowed.
      for (var i = 0; i < 4; i++) {
        await Directory('${temp.path}/dir$i').create(recursive: true);
      }

      await expectLater(
        const FolderInspector(
          limits: ArchiveInspectionLimits(maxEntries: 2),
        ).inspect(temp),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'entry_count_limit',
        )),
      );
    });

    test('fingerprints content, so a same-size edit is visible', () async {
      final file = await write('messages/message_1.json', '{"a":"hello"}');
      final before = folderFingerprintEntries(
        temp.path,
        const ArchiveInspectionLimits(),
      );

      await file.writeAsString('{"a":"world"}'); // same length, different bytes
      final after = folderFingerprintEntries(
        temp.path,
        const ArchiveInspectionLimits(),
      );

      expect(before.single.split(':').take(2), after.single.split(':').take(2));
      expect(before, isNot(after));
    });

    test('hashes only the entries it is asked for', () async {
      await write('a.jpg', 'one');
      await write('b.jpg', 'two');
      await write('c.json', '{}');

      final digests = await FolderInspector().hashEntries(temp, {'a.jpg', 'c.json'});

      expect(digests.keys.toSet(), {'a.jpg', 'c.json'});
      expect(digests['a.jpg']!.sizeBytes, 3);
      expect(digests['a.jpg']!.sha256, isNotNull);
    });
  });

  group('ImportCoordinator', () {
    test('records why a folder was rejected while fingerprinting', () async {
      // The folder walk can reject the import before any parsing happens; the
      // coverage report must still say why, or the user sees a blank failure.
      await write('data.json', '{}');
      await Link('${temp.path}/escape').create('${temp.path}/data.json');

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final coordinator = ImportCoordinator(database: database);

      await expectLater(
        coordinator.importSource(temp.path),
        throwsA(isA<ArchiveInspectionException>()),
      );
      // The coverage reason vocabulary is the report's, not the exception's:
      // what matters is that the rejection is reported instead of dropped.
      final blocked = coordinator.lastCoverageReport!.entries.single;
      expect(blocked.supported, isFalse);
      expect(blocked.reason.code, isNot('unknown_error'));
    });
  });

  group('ExportInspector', () {
    test('routes a folder path to the folder scanner', () async {
      await write('messages/message_1.json', '{"messages":[]}');

      expect(ExportInspector.isFolder(temp.path), isTrue);
      final report = await const ExportInspector().inspect(temp.path);
      expect(report.entries, 1);
    });

    test('keeps reporting an empty file apart from an oversized one', () async {
      final empty = File('${temp.path}/empty.zip');
      await empty.writeAsBytes(const <int>[]);

      await expectLater(
        const ExportInspector().inspect(empty.path),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'archive_empty',
        )),
      );

      final archive = File('${temp.path}/big.zip');
      await archive.writeAsBytes(const [1, 2, 3, 4]);

      await expectLater(
        const ExportInspector(limits: ArchiveInspectionLimits(maxArchiveBytes: 1))
            .inspect(archive.path),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'archive_invalid',
        )),
      );
    });
  });
}
