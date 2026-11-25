import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';

import '../fixtures/unix_zip_builder.dart';

void main() {
  group('ArchiveInspector', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('pda-archive-test-');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('counts supported file categories without extracting contents', () async {
      final file = await _writeZip(tempDirectory, {
        'facebook/messages/inbox.json': '{"messages": []}',
        'facebook/photos/image.jpg': 'fake image bytes',
        'facebook/unknown.bin': 'ignored',
      });

      final report = await const ArchiveInspector().inspect(file);

      expect(report.entries, 3);
      expect(report.jsonFiles, 1);
      expect(report.mediaFiles, 1);
      expect(report.ignoredFiles, 1);
      expect(report.warnings, contains('unsupported_files_present'));
      expect(await File('${tempDirectory.path}/facebook/messages/inbox.json').exists(),
          isFalse);
    });

    test('rejects an archive entry with path traversal', () async {
      final file = await _writeZip(tempDirectory, {'../outside.json': '{}'});

      await expectLater(
        const ArchiveInspector().inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'path_traversal',
        )),
      );
    });

    test('rejects absolute paths', () async {
      final file = await _writeZip(tempDirectory, {'/tmp/outside.json': '{}'});

      await expectLater(
        const ArchiveInspector().inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'absolute_entry_path',
        )),
      );
    });

    test('rejects duplicate normalized paths', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string('folder/item.json', '{}'))
        ..addFile(ArchiveFile.string('FOLDER\\ITEM.JSON', '{}'));
      final file = await _saveZip(tempDirectory, archive);

      await expectLater(
        const ArchiveInspector().inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'duplicate_entry',
        )),
      );
    });

    test('rejects symbolic links before reading the rest of the archive', () async {
      // ZipEncoder cannot encode a symlink: it stamps regular-file attributes
      // and has no content to write, so the fixture is built with Unix mode
      // bits (S_IFLNK) instead.
      final file = File('${tempDirectory.path}/fixture.zip');
      await file.writeAsBytes(buildUnixZip([
        ZipFixtureEntry.symlink('link.json', '../outside.json'),
        ZipFixtureEntry.file('data.json', '{}'),
      ]));

      await expectLater(
        const ArchiveInspector().inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'symbolic_link_rejected',
        )),
      );
    });

    test('rejects an entry above configured expanded-size limit', () async {
      final file = await _writeZip(tempDirectory, {
        'large.json': '0123456789',
      });

      await expectLater(
        ArchiveInspector(
          limits: const ArchiveInspectionLimits(maxEntryBytes: 4),
        ).inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'entry_size_limit',
        )),
      );
    });

    test('rejects total expanded-size metadata above configured limit', () async {
      final file = await _writeZip(tempDirectory, {
        'one.json': '1234',
        'two.json': '5678',
      });

      await expectLater(
        ArchiveInspector(
          limits: const ArchiveInspectionLimits(
            maxEntryBytes: 5,
            maxTotalExpandedBytes: 7,
          ),
        ).inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'expanded_size_limit',
        )),
      );
    });

    test('rejects archives above configured entry count', () async {
      final file = await _writeZip(tempDirectory, {
        'one.json': '{}',
        'two.json': '{}',
      });

      await expectLater(
        ArchiveInspector(
          limits: const ArchiveInspectionLimits(maxEntries: 1),
        ).inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'entry_count_limit',
        )),
      );
    });

    test('a file larger than the in-memory ceiling is still read from disk',
        () async {
      // The file path seeks instead of loading, so the bytes-in-memory ceiling
      // must not refuse it: a real export is 800 MB and up.
      final file = await _writeZip(tempDirectory, {'data.json': '{}'});

      final inspection = await ArchiveInspector(
        limits: const ArchiveInspectionLimits(maxArchiveBytes: 1),
      ).inspect(file);

      expect(inspection.entries, 1);
      expect(inspection.jsonFiles, 1);
    });

    test('rejects malformed ZIP with a safe error code', () async {
      final file = File('${tempDirectory.path}/broken.zip');
      await file.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      await expectLater(
        const ArchiveInspector().inspect(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'archive_invalid',
        )),
      );
    });

    // A real Facebook export carries one entry per photo/video; the default
    // ceilings have to accept a photo-heavy archive instead of refusing it.
    test('accepts an archive with more entries than a small fixture',
        () async {
      final archive = Archive();
      for (var i = 0; i < 25000; i++) {
        archive.addFile(ArchiveFile.string('photos/p$i.jpg', 'x'));
      }
      archive.addFile(
          ArchiveFile.string('messages/inbox/a/message_1.json', '{"messages":[]}'));
      final file = await _saveZip(tempDirectory, archive);

      final inspection = await const ArchiveInspector().inspect(file);

      expect(inspection.entries, 25001);
      expect(inspection.mediaFiles, 25000);
      expect(inspection.jsonFiles, 1);
    });
  });
}

Future<File> _writeZip(Directory directory, Map<String, String> entries) async {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return _saveZip(directory, archive);
}

Future<File> _saveZip(Directory directory, Archive archive) async {
  final bytes = ZipEncoder().encode(archive);
  final file = File('${directory.path}/fixture.zip');
  await file.writeAsBytes(bytes);
  return file;
}
