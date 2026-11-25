import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';

/// Facebook ships more than one layout for the same data. These are the real
/// file names, and the importer must read all of them: a name it does not know
/// used to make the whole file invisible, which left nothing to import.
const _oldLayout = {
  'your_posts_1.json': '''
[{"timestamp": 1600000000, "data": [{"post": "an old post"}]}]''',
  'comments.json': '''
[{"timestamp": 1600000100,
  "data": [{"comment": {"author": "Ahmad", "comment": "an old comment",
                        "timestamp": 1600000100}}]}]''',
  'likes_and_reactions_1.json': '''
[{"timestamp": 1600000200, "data": [{"reaction": {"reaction": "LIKE"}}]}]''',
  'messages/inbox/ahmad_42/message_1.json': '''
{"participants": [{"name": "Ahmad"}],
 "messages": [{"sender_name": "Ahmad", "timestamp_ms": 1600000300000,
               "content": "an old message"}],
 "title": "Ahmad", "thread_type": "Regular"}''',
};

const _newLayout = {
  'your_activity_across_facebook/posts/your_posts__check_ins__photos_and_videos_1.json':
      '''
[{"timestamp": 1700000000, "data": [{"post": "a new post"}]}]''',
  'your_activity_across_facebook/comments/comments.json': '''
{"comments_v2": [{"timestamp": 1700000100,
                  "data": [{"comment": {"author": "Sara", "comment": "a new comment",
                                        "timestamp": 1700000100}}]}]}''',
  'your_activity_across_facebook/likes_and_reactions/likes_and_reactions.json':
      '''
{"reactions_v2": [{"timestamp": 1700000200,
                   "data": [{"reaction": {"reaction": "LOVE"}}]}]}''',
  'your_activity_across_facebook/messages/inbox/sara_7/message_1.json': '''
{"participants": [{"name": "Sara"}],
 "messages": [{"sender_name": "Sara", "timestamp_ms": 1700000300000,
               "content": "a new message"}],
 "title": "Sara", "thread_type": "Regular"}''',
  // Files this importer does not model: they must be skipped, never fatal.
  'personal_information/personal_information/profile_information/profile_information.json':
      '{"profile_v2": {"name": {"full_name": "X"}}}',
  'friends_and_followers/friends.json': '{"friends_v2": []}',
};

File _writeZip(String dir, Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, Uint8List.fromList(bytes)));
  });
  return File('$dir/export.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
}

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('fb-layouts-'));
  tearDown(() => temp.deleteSync(recursive: true));

  for (final layout in {'old root names': _oldLayout, 'new folders': _newLayout}.entries) {
    test('imports a ${layout.key} export', () async {
      final file = _writeZip(temp.path, layout.value);
      final preview = await const FacebookJsonImporter().previewSource(file.path);

      expect(preview.supportedFiles, 4, reason: 'every named file must be read');
      // `personal_information/` and `friends_and_followers/` are documented
      // Facebook roots, so their unmodelled files are known, not unsupported.
      expect(preview.unsupportedJsonFiles, 0);
      expect(preview.knownNotImportedJsonFiles, layout.key == 'new folders' ? 2 : 0);
      if (layout.key == 'new folders') {
        expect(preview.warnings, contains('known_folders_not_imported'));
        expect(preview.warnings, isNot(contains('unsupported_json_files_present')));
      }
      expect(preview.records.length, 4);
      final parsed = preview.files
          .where((f) => f.status == FacebookPreviewFileStatus.parsed)
          .length;
      expect(parsed, 4);
    });
  }

  test('a renamed file is still parsed from its record shape', () async {
    // Nothing in the name says "messages"; only the content does.
    final file = _writeZip(temp.path, {
      'your_activity_across_facebook/renamed_thread.json': '''
{"participants": [{"name": "Nour"}],
 "messages": [{"sender_name": "Nour", "timestamp_ms": 1700000300000,
               "content": "hello"}],
 "title": "Nour"}''',
    });
    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.supportedFiles, 1);
    expect(preview.records.single.text, 'hello');
  });

  test('a JSON file with no usable records is skipped, not fatal', () async {
    final file = _writeZip(temp.path, {
      ..._newLayout,
      'your_activity_across_facebook/unknown_shape.json': '{"nothing": []}',
    });
    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.supportedFiles, 4);
    // profile_information, friends and unknown_shape all sit under known roots:
    // they are classified, not fatal.
    expect(preview.knownNotImportedJsonFiles, 3);
    expect(preview.unsupportedJsonFiles, 0);
    expect(preview.records.length, 4);
  });
}
