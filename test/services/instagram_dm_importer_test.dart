import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/instagram_dm_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

String mojibake(String value) => latin1.decode(utf8.encode(value));

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('three plain messages keep exact sender, text and UTC instant', () {
    final thread = parseThreadJson(jsonEncode({
      'participants': [
        {'name': 'Ahmad'},
        {'name': 'Sara'},
      ],
      'messages': [
        {
          'sender_name': 'Ahmad',
          'timestamp_ms': 1710278045000,
          'content': 'مرحبا شو أخبارك؟',
        },
        {
          'sender_name': 'Sara',
          'timestamp_ms': 1710278100000,
          'content': 'تمام',
        },
        {
          'sender_name': 'Ahmad',
          'timestamp_ms': 1710278160000,
          'content': 'تم',
        },
      ],
      'title': 'Ahmad',
    }));

    expect(thread.messages, hasLength(3));
    expect(thread.skipped, 0);
    expect(thread.title, 'Ahmad');
    expect(thread.participants, ['Ahmad', 'Sara']);
    expect(
      thread.messages.map((message) => message.sender).toList(),
      ['Ahmad', 'Sara', 'Ahmad'],
    );
    expect(
      thread.messages.map((message) => message.text).toList(),
      ['مرحبا شو أخبارك؟', 'تمام', 'تم'],
    );
    expect(
      thread.messages.first.timestamp.toUtc(),
      DateTime.utc(2024, 3, 12, 21, 14, 5),
    );
    expect(
      thread.messages.last.timestamp.toUtc(),
      DateTime.utc(2024, 3, 12, 21, 16, 0),
    );
  });

  test('mojibake Arabic is repaired and correct Arabic is left alone', () {
    final thread = parseThreadJson(jsonEncode({
      'messages': [
        {
          'sender_name': mojibake('أحمد'),
          'timestamp_ms': 1710278045000,
          'content': mojibake('مرحبا شو أخبارك؟'),
        },
        {
          'sender_name': 'سارة',
          'timestamp_ms': 1710278100000,
          'content': 'مرحبا',
        },
      ],
    }));

    expect(thread.messages.first.sender, 'أحمد');
    expect(thread.messages.first.text, 'مرحبا شو أخبارك؟');
    expect(thread.messages.last.text, 'مرحبا');
    expect(repairInstagramMojibake('مرحبا'), 'مرحبا');
    expect(repairInstagramMojibake('hello'), 'hello');
  });

  test('photo message keeps the attachment name and no text', () {
    final thread = parseThreadJson(jsonEncode({
      'messages': [
        {
          'sender_name': 'Sara',
          'timestamp_ms': 1710278100000,
          'photos': [
            {'uri': 'messages/inbox/thread/photos/1.jpg'},
          ],
        },
      ],
    }));

    expect(thread.messages.single.text, '');
    expect(
      thread.messages.single.attachments,
      ['messages/inbox/thread/photos/1.jpg'],
    );
  });

  test('reactions are repaired but never leak into the body', () {
    final thread = parseThreadJson(jsonEncode({
      'messages': [
        {
          'sender_name': 'Sara',
          'timestamp_ms': 1710278100000,
          'content': 'ردّ',
          'reactions': [
            {'reaction': mojibake('❤'), 'actor': 'Ahmad'},
          ],
        },
      ],
    }));

    expect(thread.messages.single.text, 'ردّ');
    expect(thread.messages.single.reactions, ['❤']);
    expect(repairInstagramMojibake(mojibake('❤')), '❤');
  });

  test('share link is captured', () {
    final thread = parseThreadJson(jsonEncode({
      'messages': [
        {
          'sender_name': 'Ahmad',
          'timestamp_ms': 1710278160000,
          'content': 'تم',
          'share': {'link': 'https://example.com'},
        },
      ],
    }));

    expect(thread.messages.single.link, 'https://example.com');
  });

  test('empty, malformed and unknown-shape JSON yield no messages', () {
    for (final input in ['', '{', '[]', '{"messages": 7}']) {
      final thread = parseThreadJson(input);
      expect(thread.messages, isEmpty);
      expect(thread.title, isNull);
    }
    expect(parseThreadJson('{}').skipped, 0);
  });

  test('multi-thread parse handles two threads with correct counts', () {
    String makeThread(String title, int count) => jsonEncode({
      'title': title,
      'messages': [
        for (var i = 0; i < count; i++)
          {
            'sender_name': title,
            'timestamp_ms': 1710278045000 + i,
            'content': '$i',
          },
      ],
    });

    final threads = parseInboxDirectory([
      ('inbox/a/message_1.json', makeThread('A', 2)),
      ('inbox/b/message_1.json', makeThread('B', 3)),
      ('inbox/broken/message_1.json', '{'),
      ('inbox/empty/message_1.json', '{}'),
    ]);

    expect(threads, hasLength(4));
    expect(threads[0].title, 'A');
    expect(threads[0].messages, hasLength(2));
    expect(threads[1].title, 'B');
    expect(threads[1].messages, hasLength(3));
    expect(threads[2].messages, isEmpty);
    expect(threads[2].skipped, 1);
    expect(threads[3].messages, isEmpty);
  });

  test('a small Instagram thread writes through the shared DB path', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final temp = await Directory.systemTemp.createTemp('ig-dm-');
    addTearDown(() async {
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final path = 'your_instagram_activity/messages/inbox/thread/message_1.json';
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          path,
          jsonEncode({
            'participants': [
              {'name': 'Ahmad'},
              {'name': 'Sara'},
            ],
            'title': 'Ahmad',
            'messages': [
              {
                'sender_name': mojibake('أحمد'),
                'timestamp_ms': 1710278045000,
                'content': mojibake('مرحبا'),
                'reactions': [
                  {'reaction': mojibake('❤'), 'actor': 'Sara'},
                ],
              },
              {
                'sender_name': 'Sara',
                'timestamp_ms': 1710278100000,
                'content': 'تمام',
              },
            ],
          }),
        ),
      );
    final zip = File('${temp.path}/instagram.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final outcome = await ImportCoordinator(
      database: database,
      platform: 'instagram',
    ).importArchive(zip) as ImportOutcome;

    expect(outcome.events, 2);
    final rows = await database
        .customSelect(
          'SELECT text_content, metadata_json FROM events ORDER BY id',
        )
        .get();
    expect(rows, hasLength(2));
    expect(rows.first.read<String>('text_content'), 'مرحبا');
    expect(rows.last.read<String>('text_content'), 'تمام');
    expect(rows.first.read<String?>('metadata_json'), contains('❤'));
    final platforms = await database
        .customSelect('SELECT DISTINCT platform FROM events')
        .get();
    expect(platforms.single.read<String>('platform'), 'instagram');
  });
}
