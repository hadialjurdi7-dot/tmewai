import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/conversation_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/person_repository.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

const _thread = 'messages/inbox/layla_1';
const _messagePath = '$_thread/message_1.json';

/// The typed payloads of one empty-bodied thread, in a fixed order.
Map<String, dynamic> _threadBody() {
  var timestamp = 1552345200000;
  Map<String, dynamic> entry(Map<String, dynamic> payload) =>
      {'timestamp_ms': timestamp += 1000, ...payload};

  return {
    'participants': [
      {'name': 'Layla Fixture'},
    ],
    'title': 'Layla Fixture',
    'thread_path': 'inbox/layla_1',
    'messages': [
      entry({
        'photos': [
          {'uri': '$_thread/photos/photo.jpg'},
        ],
      }),
      entry({
        'videos': [
          {'uri': '$_thread/videos/clip.mp4'},
        ],
      }),
      entry({
        'gifs': [
          {'uri': '$_thread/gifs/loop.gif'},
        ],
      }),
      entry({
        'audio_files': [
          {'uri': '$_thread/audio/voice.mp3'},
        ],
      }),
      entry({
        'files': [
          {'uri': '$_thread/files/doc.pdf'},
        ],
      }),
      entry({
        'share': {'link': 'https://example.invalid/a-synthetic-link'},
      }),
      entry({
        'sticker': {'uri': '$_thread/stickers/sticker.png'},
      }),
      entry({'call_duration': 42}),
      entry({'unsent': true}),
      entry({
        'poll': {
          'question': 'A synthetic poll?',
          'options': ['One', 'Two'],
        },
      }),
      entry({
        'plan': {'title': 'A synthetic plan'},
      }),
      entry({}),
      entry({'content': 'A synthetic caption.'}),
    ],
  };
}

Future<File> _writeZip(Directory temp) async {
  final archive = Archive()
    ..addFile(ArchiveFile.string(_messagePath, jsonEncode(_threadBody())))
    ..addFile(
      ArchiveFile.bytes('$_thread/photos/photo.jpg', const [1, 2, 3]),
    )
    ..addFile(ArchiveFile.bytes('$_thread/videos/clip.mp4', const [4, 5]))
    ..addFile(ArchiveFile.bytes('$_thread/gifs/loop.gif', const [6, 7]))
    ..addFile(ArchiveFile.bytes('$_thread/audio/voice.mp3', const [8, 9]))
    ..addFile(ArchiveFile.bytes('$_thread/files/doc.pdf', const [10, 11]))
    ..addFile(
      ArchiveFile.bytes('$_thread/stickers/sticker.png', const [12, 13]),
    );
  final file = File('${temp.path}/payloads.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive));
  return file;
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory temp;
  late File zip;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pda-payloads-');
    zip = await _writeZip(temp);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('every empty body gets its own type and a bilingual label', () async {
    final preview = await const FacebookJsonImporter().preview(zip);

    expect(preview.skippedRecords, 0, reason: 'an empty body is not skipped');
    expect(preview.records, hasLength(13));
    expect(
      preview.records.map((record) => record.eventType).toList(),
      const [
        'message_photo',
        'message_video',
        'message_gif',
        'message_audio',
        'message_file',
        'message_link',
        'message_sticker',
        'message_call',
        'message_deleted',
        'message_poll',
        'message_plan',
        'message_empty',
        'message',
      ],
    );

    expect(
      preview.records
          .where(
            (record) =>
                record.text?.trim().isNotEmpty != true &&
                record.payloadLabel(isRtl: true) == null,
          )
          .map((record) => record.eventType),
      isEmpty,
      reason: 'no empty-bodied record may render without a label',
    );

    final labels = {
      for (final record in preview.records)
        record.eventType: record.payloadLabel(isRtl: true),
    };
    expect(labels, {
      'message_photo': 'صورة',
      'message_video': 'فيديو',
      'message_gif': 'صورة متحركة',
      'message_audio': 'ملف صوتي',
      'message_file': 'ملف',
      'message_link': 'رابط مشارَك',
      'message_sticker': 'ملصق',
      'message_call': 'مكالمة — 42 ثانية',
      'message_deleted': 'رسالة محذوفة',
      'message_poll': 'استطلاع',
      'message_plan': 'خطة',
      'message_empty': 'رسالة فارغة — بلا محتوى',
      'message': null,
    });
    expect(
      preview.records[7].payloadLabel(isRtl: false),
      'Call — 42 seconds',
    );
  });

  test('typed payloads keep their attachment metadata', () async {
    final preview = await const FacebookJsonImporter().preview(zip);

    expect(preview.attachments, hasLength(6));
    expect(
      {for (final a in preview.attachments) a.relativePath: a.mediaType},
      {
        '$_thread/photos/photo.jpg': 'image',
        '$_thread/videos/clip.mp4': 'video',
        '$_thread/gifs/loop.gif': 'image',
        '$_thread/audio/voice.mp3': 'audio',
        '$_thread/files/doc.pdf': 'file',
        '$_thread/stickers/sticker.png': 'image',
      },
    );
    expect(
      preview.attachments.map((a) => a.contentHash),
      everyElement(isNotNull),
      reason: 'small entries are hashed, as before',
    );
  });

  test('typed messages are stored as distinct types and still count', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final coordinator = ImportCoordinator(database: database);
    addTearDown(() async {
      await coordinator.dispose();
      await database.close();
    });

    final outcome = await coordinator.importArchive(zip) as ImportOutcome;

    expect(outcome.events, 13);
    expect(outcome.skippedRecords, 0);
    expect(outcome.conversations, 1);
    expect(outcome.people, 1, reason: 'thread participants name the sender');

    final stored = await database.select(database.events).get();
    expect(
      stored.map((event) => event.eventType).toSet(),
      containsAll(const [
        'message_photo',
        'message_video',
        'message_gif',
        'message_audio',
        'message_file',
        'message_link',
        'message_sticker',
        'message_call',
        'message_deleted',
        'message_poll',
        'message_plan',
        'message_empty',
        'message',
      ]),
    );
    final empty = stored.singleWhere(
      (event) => event.eventType == 'message_empty',
    );
    expect(
      empty.textContent,
      isNull,
      reason: 'an empty record is stored, not filled with invented text',
    );
    final call = stored.singleWhere(
      (event) => event.eventType == 'message_call',
    );
    expect(call.metadataJson, '{"call_duration":"42"}');

    // A typed message is still a message for every aggregate: the thread,
    // its person and the archive KPI must all see these thirteen rows.
    final conversations = ConversationRepository(database);
    expect(await conversations.conversationCount(), 1);
    final thread = (await conversations.conversations()).single;
    expect(thread.messageCount, 13);
    expect(await conversations.messages(thread.id), hasLength(13));

    final profile = await PersonRepository(database).profile(
      stored.first.actorId!,
    );
    expect(profile!.messageCount, 13);

    final totals = await OverviewRepository(database).archiveTotals();
    expect(totals.messages, 13);
  });
}
