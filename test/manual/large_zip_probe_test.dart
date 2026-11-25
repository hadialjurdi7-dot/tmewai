import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';

/// Manual probe, not part of the suite: point LARGE_ZIP at a real export and
/// this prints what the inspector read plus the process peak RSS.
///
///   LARGE_ZIP=/path/to/export.zip flutter test test/manual/large_zip_probe_test.dart
void main() {
  final path = Platform.environment['LARGE_ZIP'];
  if (path == null || path.isEmpty) {
    test('large zip probe (set LARGE_ZIP to run)', () {}, skip: 'no LARGE_ZIP');
    return;
  }

  test('inspects and imports a real-size export', () async {
    final file = File(path);
    final sizeMb = file.lengthSync() / (1024 * 1024);
    final watch = Stopwatch()..start();

    final scan = await const ArchiveInspector().scanJsonFiles(
      file,
      maxJsonBytes: 256 * 1024 * 1024,
      maxJsonFileBytes: 64 * 1024 * 1024,
    );
    watch.stop();

    final jsonBytes = scan.jsonFiles.fold<int>(0, (sum, f) => sum + f.bytes.length);
    final rss = File('/proc/self/status')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('VmHWM'), orElse: () => 'VmHWM: ?');

    // ignore: avoid_print
    print('PROBE archive=${sizeMb.toStringAsFixed(1)}MB '
        'entries=${scan.inspection.entries} '
        'json=${scan.inspection.jsonFiles} '
        'media=${scan.inspection.mediaFiles} '
        'jsonBytes=${(jsonBytes / 1048576).toStringAsFixed(1)}MB '
        'expanded=${(scan.inspection.totalExpandedBytes / 1048576).toStringAsFixed(1)}MB '
        'elapsed=${watch.elapsedMilliseconds}ms '
        '${rss.trim()}');

    expect(scan.inspection.entries, greaterThan(3000));
    expect(scan.jsonFiles, isNotEmpty);
    expect(journalIsValid(scan), isTrue);
  });
}

bool journalIsValid(ArchiveScan scan) => scan.jsonFiles.every(
      (file) => file.bytes.isNotEmpty && file.path.toLowerCase().endsWith('.json'),
    );
