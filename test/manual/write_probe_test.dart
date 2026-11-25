import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

/// Manual probe for the write phase at a real export's scale.
///
///   EXPORT_DIR=/path/to/extracted/export flutter test test/manual/write_probe_test.dart
///   BIG_RECORDS=140000 flutter test test/manual/write_probe_test.dart
///
/// Prints what the coordinator actually did, or the exact exception the write
/// phase threw. Not part of the suite: it takes minutes and writes a real
/// database file.
void main() {
  final exportDir = Platform.environment['EXPORT_DIR'];
  final bigRecords = int.tryParse(Platform.environment['BIG_RECORDS'] ?? '');

  if (exportDir == null && bigRecords == null) {
    test('write probe (set EXPORT_DIR or BIG_RECORDS)', () {}, skip: 'no input');
    return;
  }

  test('the write phase completes at scale', () async {
    final root = await Directory.systemTemp.createTemp('write-probe-');
    final source = Directory('${root.path}/export');
    source.createSync(recursive: true);

    if (exportDir != null) {
      for (final entity in Directory(exportDir).listSync(recursive: true)) {
        if (entity is! File) continue;
        final target = File('${source.path}/${entity.path.substring(exportDir.length + 1)}');
        target.parent.createSync(recursive: true);
        entity.copySync(target.path);
      }
    } else {
      _synthesize(source, bigRecords!);
    }

    final workspace = WorkspaceService(
      rootDirectory: Directory('${root.path}/workspace'),
    );
    await workspace.open();
    final coordinator = ImportCoordinator(database: workspace.database);

    try {
      final result = await coordinator.importSource(source.path);
      if (result is ImportOutcome) {
        // ignore: avoid_print
        print('PROBE ok events=${result.events} people=${result.people} '
            'conversations=${result.conversations} '
            'attachments=${result.attachments} '
            'skipped=${result.skippedRecords} '
            'warnings=${result.warnings.join(",")}');
      } else {
        // ignore: avoid_print
        print('PROBE cancelled $result');
      }
    } catch (error, stack) {
      // ignore: avoid_print
      print('PROBE FAILED ${error.runtimeType}: $error');
      // ignore: avoid_print
      print(stack.toString().split('\n').take(12).join('\n'));
    } finally {
      await coordinator.dispose();
      await workspace.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

/// A folder shaped like a real export at a chosen record count, including the
/// awkward shapes: a post with a very long body, a comment thread, ads files
/// the importer does not model, and one message with no text.
void _synthesize(Directory root, int records) {
  final perFile = 1000;
  final files = (records / perFile).ceil();
  for (var file = 0; file < files; file++) {
    final messages = <Map<String, dynamic>>[];
    for (var i = 0; i < perFile; i++) {
      messages.add({
        'sender_name': 'Person ${i % 40}',
        'timestamp_ms': 1600000000000 + i * 1000,
        'content': 'message $i of file $file',
      });
    }
    final dir = Directory('${root.path}/your_activity/messages/inbox/t$file')
      ..createSync(recursive: true);
    File('${dir.path}/message_1.json').writeAsStringSync(
      jsonEncode({
        'participants': [{'name': 'Person ${file % 40}'}],
        'messages': messages,
        'title': 'Thread $file',
        'thread_type': 'Regular',
      }),
    );
  }

  // A post body over 100,000 characters: the events.text_content ceiling.
  final posts = Directory('${root.path}/your_activity/posts')
    ..createSync(recursive: true);
  File('${posts.path}/your_posts_1.json').writeAsStringSync(jsonEncode([
    {
      'timestamp': 1600000000,
      'data': [
        {'post': 'x' * 150000},
      ],
    },
    for (var i = 0; i < 500; i++)
      {
        'timestamp': 1600000000 + i,
        'data': [
          {'post': 'a normal post $i'},
        ],
      },
  ]));

  final ads = Directory('${root.path}/ads_information')..createSync(recursive: true);
  for (var i = 0; i < 20; i++) {
    File('${ads.path}/ads_$i.json').writeAsStringSync(
      jsonEncode({'ad_preferences_v2': {'items': i}}),
    );
  }
}

/// Kept for callers that hand over a ZIP instead of a folder.
File writeZip(Directory dir, Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, Uint8List.fromList(bytes)));
  });
  return File('${dir.path}/export.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
}
