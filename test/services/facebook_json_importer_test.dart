import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';

void main() {
  group('FacebookJsonImporter', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('pda-facebook-test-');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('normalizes supported message records with stable source locators', () async {
      final file = await _writeZip(tempDirectory, {
        'your_facebook_activity/messages/inbox/friends/messages.json':
            '{"title":"Friends","messages":['
            '{"sender_name":"ليلى","timestamp_ms":1700000000123,"content":"مرحبا"},'
            '{"sender_name":"Sam","content":"hello"}]}',
        'your_facebook_activity/posts/your_posts.json': '{"posts":[]}',
      });

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.archiveInspection.jsonFiles, 2);
      expect(result.records, hasLength(2));
      expect(result.records.first.sourcePath,
          'your_facebook_activity/messages/inbox/friends/messages.json');
      expect(result.records.first.sourceLocator,
          'your_facebook_activity/messages/inbox/friends/messages.json#/messages/0');
      expect(result.records.first.conversationKey,
          'your_facebook_activity/messages/inbox/friends');
      expect(result.records.first.conversationTitle, 'Friends');
      expect(result.records.first.senderName, 'ليلى');
      expect(result.records.first.text, 'مرحبا');
      expect(result.records.first.timestampRaw, '1700000000123');
      expect(result.records.first.timestampUtc,
          DateTime.fromMillisecondsSinceEpoch(1700000000123, isUtc: true));
      expect(result.records.last.timestampUtc, isNull);
      // `posts/your_posts.json` is a recognised posts file that happens to hold
      // no posts, so it is supported rather than unsupported.
      expect(result.supportedFiles, 2);
      expect(result.unsupportedJsonFiles, 0);
      expect(await File(
        '${tempDirectory.path}/your_facebook_activity/messages/inbox/friends/messages.json',
      ).exists(), isFalse);
    });

    test('skips malformed records and reports a safe warning code', () async {
      final file = await _writeZip(tempDirectory, {
        'messages/inbox/message_1.json':
            '{"messages":[{"sender_name":"A","content":"ok"},42,'
            '{"sender_name":false,"content":"bad"}]}',
      });

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, hasLength(1));
      expect(result.skippedRecords, 2);
      expect(result.warnings, contains('invalid_message_record'));
    });

    test('does not claim support for malformed JSON or unrelated JSON files', () async {
      final file = await _writeZip(tempDirectory, {
        'messages/inbox/message_1.json': '{broken',
        'posts/your_posts.json': '{"posts":[]}',
      });

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, isEmpty);
      // The posts file is readable, so only the malformed one is unsupported -
      // and an empty import still reports itself instead of failing silently.
      expect(result.supportedFiles, 1);
      expect(result.unsupportedJsonFiles, 1);
      expect(result.warnings, contains('malformed_message_json'));
      expect(result.warnings, contains('unsupported_json_files_present'));
    });

    test('enforces aggregate and per-file JSON payload limits', () async {
      final file = await _writeZip(tempDirectory, {
        'messages/inbox/message_1.json': '{"messages":[]}',
      });

      await expectLater(
        const FacebookJsonImporter(maxJsonBytes: 4).preview(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'json_payload_size_limit',
        )),
      );
      await expectLater(
        const FacebookJsonImporter(maxJsonFileBytes: 4).preview(file),
        throwsA(isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'json_file_size_limit',
        )),
      );
    });

    test('reports invalid timestamps and continues without inventing a date', () async {
      final file = await _writeZip(tempDirectory, {
        'messages/inbox/message_1.json':
            '{"messages":[{"sender_name":"A","timestamp_ms":9999999999999999}]}',
      });

      final result = await const FacebookJsonImporter().preview(file);

      expect(result.records, hasLength(1));
      expect(result.records.single.timestampRaw, isNull);
      expect(result.records.single.timestampUtc, isNull);
      expect(result.warnings, contains('invalid_message_timestamp'));
    });

    test('enforces normalized record count limit', () async {
      final file = await _writeZip(tempDirectory, {
        'messages/inbox/message_1.json': '{"messages":[{},{}]}',
      });

      await expectLater(
        const FacebookJsonImporter(maxRecords: 1).preview(file),
        throwsA(isA<FacebookImportException>().having(
          (error) => error.code,
          'code',
          'record_count_limit',
        )),
      );
    });
  });
}

Future<File> _writeZip(Directory directory, Map<String, String> entries) async {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  final bytes = ZipEncoder().encode(archive);
  final file = File('${directory.path}/fixture.zip');
  await file.writeAsBytes(bytes);
  return file;
}
