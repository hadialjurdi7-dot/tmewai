import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('fb-people-'));
  tearDown(() => temp.deleteSync(recursive: true));

  File writeZip(Map<String, String> entries) {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    final file = File('${temp.path}/export.zip');
    file.writeAsBytesSync(ZipEncoder().encode(archive));
    return file;
  }

  test('resolves nameless messages from thread participants and files', () async {
    // The older layout: messages carry no sender_name at all. The thread names
    // its other participant, and friends/profile files repeat the names.
    final file = writeZip({
      'friends_and_followers/friends.json': jsonEncode({
        'friends_v2': [
          {'name': 'ليلى خالد'},
          {'name': 'Sample Sender'},
        ],
      }),
      'personal_information/personal_information/profile_information/profile_information.json':
          jsonEncode({
            'profile_v2': {
              'name': {'full_name': 'Sample Sender'},
            },
          }),
      'messages/inbox/ليلى_الجردي_100/message_1.json': jsonEncode({
        'participants': [
          {'name': 'ليلى خالد'},
          {'name': 'Sample Sender'},
        ],
        'title': 'ليلى خالد',
        'messages': [
          {'timestamp_ms': 1700000000000, 'content': 'مرحبا'},
          {'timestamp_ms': 1700000100000, 'content': 'كيفك؟'},
          {'timestamp_ms': 1700000200000, 'photos': <Object>[]},
        ],
      }),
    });

    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.records, hasLength(3));
    expect(
      preview.records.map((record) => record.senderName),
      everyElement('ليلى خالد'),
    );
    expect(
      preview.records.where((record) => record.senderName == null),
      isEmpty,
      reason: 'zero unknown senders when the archive names the thread',
    );
  });

  test('keeps a real sender_name instead of replacing it', () async {
    final file = writeZip({
      'messages/inbox/Layla_100/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Layla'},
          {'name': 'Sample'},
        ],
        'title': 'Layla',
        'messages': [
          {'sender_name': 'Sample', 'timestamp_ms': 1700000000000, 'content': 'hi'},
          {'timestamp_ms': 1700000100000, 'content': 'hello'},
        ],
      }),
    });

    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.records.first.senderName, 'Sample');
    expect(preview.records.last.senderName, 'Layla');
  });

  test('uses the thread folder when the title is absent', () async {
    final file = writeZip({
      'messages/inbox/Sara_Ahmad_42/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Sara Ahmad'},
          {'name': 'Sample'},
        ],
        'messages': [
          {'timestamp_ms': 1700000000000, 'content': 'hello'},
        ],
      }),
    });

    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.records.single.senderName, 'Sara Ahmad');
  });

  test('leaves a participant-less thread unknown instead of inventing one', () async {
    final file = writeZip({
      // Names exist elsewhere in the archive, but nothing ties them to this
      // thread. A friend matching the folder name is still not evidence that
      // its messages were sent by that person.
      'friends_and_followers/friends.json': jsonEncode({
        'friends_v2': [
          {'name': 'Layla'},
        ],
      }),
      'messages/inbox/Layla_100/message_1.json': jsonEncode({
        'messages': [
          {'timestamp_ms': 1700000000000, 'content': 'hello'},
          {'timestamp_ms': 1700000100000, 'content': 'again'},
        ],
      }),
    });

    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.records, hasLength(2));
    expect(
      preview.records.map((record) => record.senderName),
      everyElement(isNull),
      reason: 'a folder name alone is not a sender',
    );
  });

  test('a group thread with no matching participant stays unknown', () async {
    final file = writeZip({
      'messages/inbox/Family_9/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Layla'},
          {'name': 'Sample'},
          {'name': 'Sara'},
        ],
        'title': 'Family',
        'messages': [
          {'timestamp_ms': 1700000000000, 'content': 'hello'},
        ],
      }),
    });

    final preview = await const FacebookJsonImporter().previewSource(file.path);

    expect(preview.records.single.senderName, isNull);
  });
}
