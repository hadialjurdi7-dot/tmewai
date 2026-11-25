import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/zip_random_access.dart';

/// Builds a real ZIP on disk with the same encoder Facebook-adjacent tools use,
/// so the reader is exercised against bytes it did not author itself.
File _writeZip(String dir, Map<String, List<int>> files, {bool store = false}) {
  final archive = Archive();
  files.forEach((name, bytes) {
    archive.addFile(
      ArchiveFile(name, bytes.length, Uint8List.fromList(bytes)),
    );
  });
  // level 0 = stored, the default = deflate. Both must read back identically.
  final encoded = ZipEncoder().encode(archive, level: store ? 0 : 6);
  final file = File('$dir/archive.zip')..writeAsBytesSync(encoded);
  return file;
}

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('zipra-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('reads stored and deflated entries', () {
    final file = _writeZip(temp.path, {
      'your_activity/posts.json': utf8.encode('{"a":1}'),
      'photos/1.jpg': List<int>.filled(2048, 7),
    });
    final archive = ZipRandomAccessArchive.open(file);
    addTearDown(archive.close);

    expect(archive.entries.map((e) => e.name), [
      'your_activity/posts.json',
      'photos/1.jpg',
    ]);
    final posts = archive.entries.first;
    expect(posts.compressedSize, greaterThan(0));
    expect(archive.readEntry(posts, maxBytes: 4096), utf8.encode('{"a":1}'));
    final photo = archive.entries.last;
    expect(archive.readEntry(photo, maxBytes: 8192).length, 2048);
  });

  test('an entry over the byte budget is refused before decompressing', () {
    final file = _writeZip(temp.path, {
      'big.json': List<int>.filled(10 * 1024, 32),
    }, store: true);
    final archive = ZipRandomAccessArchive.open(file);
    addTearDown(archive.close);

    expect(
      () => archive.readEntry(archive.entries.single, maxBytes: 1024),
      throwsA(isA<ZipFormatException>().having(
        (e) => e.code,
        'code',
        'json_file_size_limit',
      )),
    );
  });

  test('a truncated archive is rejected instead of decoding to nothing', () {
    final file = _writeZip(temp.path, {'a.json': utf8.encode('{}')});
    final bytes = file.readAsBytesSync();
    file.writeAsBytesSync(bytes.sublist(0, 40));

    expect(
      () => ZipRandomAccessArchive.open(file),
      throwsA(isA<ZipFormatException>()),
    );
  });

  test('the inspector reads a ZIP without the in-memory ceiling', () async {
    final file = _writeZip(temp.path, {
      'your_activity/posts.json': utf8.encode('{"ok":true}'),
      'media/videos/1.mp4': List<int>.filled(64 * 1024, 0),
    });
    final scan = await const ArchiveInspector().scanJsonFiles(file);

    expect(scan.inspection.entries, 2);
    expect(scan.inspection.jsonFiles, 1);
    expect(scan.inspection.mediaFiles, 1);
    expect(scan.jsonFiles.single.path, 'your_activity/posts.json');
    expect(utf8.decode(scan.jsonFiles.single.bytes), '{"ok":true}');
  });

  test('a small JSON payload budget still stops an oversized collection',
      () async {
    final file = _writeZip(temp.path, {
      'a.json': List<int>.filled(4096, 32),
      'b.json': List<int>.filled(4096, 32),
    }, store: true);

    await expectLater(
      const ArchiveInspector().scanJsonFiles(file, maxJsonBytes: 4096),
      throwsA(isA<ArchiveInspectionException>().having(
        (e) => e.code,
        'code',
        'json_payload_size_limit',
      )),
    );
  });
}
