import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/telegram_json_importer.dart';

void main() {
  const importer = TelegramJsonImporter();

  /// Small inline fixture — the exact Telegram shape, no binary assets.
  String chatJson({
    Object? extraMessages,
    String name = 'محادثة الاختبار',
  }) => jsonEncode({
    'name': name,
    'type': 'personal_chat',
    'id': 123456,
    'messages': [
      {
        'id': 1,
        'type': 'message',
        'date': '2024-03-12T21:14:05',
        'date_unixtime': '1710278045',
        'from': 'Ahmad',
        'from_id': 'user111',
        'text': 'مرحبا شو أخبارك؟',
      },
      ?extraMessages,
    ],
  });

  group('TelegramJsonImporter.parse', () {
    test('plain-string text keeps exact Arabic sender, text and timestamp', () {
      final chat = importer.parse(chatJson());

      expect(chat.title, 'محادثة الاختبار');
      expect(chat.type, 'personal_chat');
      expect(chat.messages, hasLength(1));
      final message = chat.messages.single;
      expect(message.id, 1);
      expect(message.sender, 'Ahmad');
      expect(message.text, 'مرحبا شو أخبارك؟');
      expect(message.timestamp, DateTime.utc(2024, 3, 12, 21, 14, 5));
      expect(message.isService, isFalse);
    });

    test('entity-list text flattens to the literal sentence in order', () {
      final chat = importer.parse(chatJson(extraMessages: {
        'id': 2,
        'type': 'message',
        'date': '2024-03-12T21:15:00',
        'date_unixtime': '1710278100',
        'from': 'Sara',
        'text': [
          'سطر أول\n',
          {'type': 'bold', 'text': 'سطر عريض'},
          ' ونهاية',
        ],
      }));

      expect(chat.messages.last.text, 'سطر أول\nسطر عريض ونهاية');
      expect(chat.messages.last.sender, 'Sara');
    });

    test('service messages are excluded from messages and counted', () {
      final chat = importer.parse(chatJson(extraMessages: {
        'id': 4,
        'type': 'service',
        'date': '2024-03-12T21:17:00',
        'actor': 'Ahmad',
        'action': 'join_group_by_link',
        'text': '',
      }));

      expect(chat.messages, hasLength(1));
      expect(chat.messages.any((message) => message.isService), isFalse);
      expect(chat.serviceCount, 1);
    });

    test('photo and file messages keep the attachment name with empty text', () {
      final chat = importer.parse(chatJson(extraMessages: {
        'id': 3,
        'type': 'message',
        'date': '2024-03-12T21:16:00',
        'date_unixtime': '1710278160',
        'from': 'Ahmad',
        'photo': 'photos/photo_1@12-03-2024_21-16-00.jpg',
        'text': '',
      }));

      final photo = chat.messages.last;
      expect(photo.text, isEmpty);
      expect(photo.attachmentName, 'photos/photo_1@12-03-2024_21-16-00.jpg');

      final fileChat = importer.parse(chatJson(extraMessages: {
        'id': 5,
        'type': 'message',
        'date_unixtime': '1710278220',
        'file': 'files/report.pdf',
        'mime_type': 'application/pdf',
        'text': '',
      }));
      expect(fileChat.messages.last.attachmentName, 'files/report.pdf');
      expect(fileChat.messages.last.mimeType, 'application/pdf');
    });

    test('missing from becomes a stable placeholder, never a crash', () {
      final chat = importer.parse(chatJson(extraMessages: {
        'id': 6,
        'type': 'message',
        'date_unixtime': '1710278280',
        'text': 'رسالة من حساب محفوظ',
      }));

      expect(chat.messages.last.sender, telegramUnknownSender);
      expect(chat.messages.last.text, 'رسالة من حساب محفوظ');
    });

    test('date_unixtime is preferred over date when both exist', () {
      final chat = importer.parse(chatJson(extraMessages: {
        'id': 7,
        'type': 'message',
        'date': '1999-01-01T00:00:00',
        'date_unixtime': '1710278045',
        'text': 'timestamp test',
      }));

      expect(chat.messages.last.timestamp, DateTime.utc(2024, 3, 12, 21, 14, 5));
      expect(chat.messages.last.timestamp.year, isNot(1999));
    });

    test('replies and unknown message types are tolerated', () {
      final chat = importer.parse(chatJson(extraMessages: {
        'id': 8,
        'type': 'voice_message',
        'date_unixtime': '1710278340',
        'from': 'Sara',
        'text': 'رسالة صوتية',
        'reply_to_message_id': 1,
        'forwarded_from': 'someone else',
      }));

      expect(chat.messages.last.replyToId, 1);
      expect(chat.messages.last.text, 'رسالة صوتية');
    });

    test('garbage and empty messages produce zero messages, no exception', () {
      for (final source in [
        'not json',
        '[]',
        '{}',
        '{"messages": []}',
        '{"messages": [1, "x", null]}',
      ]) {
        final chat = importer.parse(source);
        expect(chat.messages, isEmpty, reason: source);
      }
      expect(importer.parse('{"messages": [1, "x"]}').skipped, 2);
    });
  });

  group('Telegram JSON database write', () {
    late Directory temp;
    late AppDatabase database;
    late ImportCoordinator coordinator;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('telegram-import-');
      database = AppDatabase(NativeDatabase.memory());
      coordinator = ImportCoordinator(database: database);
    });

    tearDown(() async {
      await coordinator.dispose();
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('importing a chat stores events with their text read back', () async {
      final file = File('${temp.path}/result.json');
      await file.writeAsString(chatJson(extraMessages: {
        'id': 2,
        'type': 'message',
        'date_unixtime': '1710278100',
        'from': 'Sara',
        'text': 'ثاني رسالة',
      }));

      final outcome =
          await coordinator.importTelegramSource(file.path) as ImportOutcome;

      expect(outcome.events, 2);
      expect(outcome.reusedExistingImport, isFalse);
      expect(outcome.skippedRecords, 0);

      final countRow = await database
          .customSelect('SELECT COUNT(*) AS row_count FROM events')
          .getSingle();
      expect(countRow.read<int>('row_count'), 2);

      final rows = await (database.select(database.events)
            ..orderBy([(table) => OrderingTerm.asc(table.sourceLocator)]))
          .get();
      expect(rows.map((row) => row.textContent), [
        'مرحبا شو أخبارك؟',
        'ثاني رسالة',
      ]);
      expect(rows.every((row) => row.platform == 'telegram'), isTrue);
      expect(
        rows.every((row) => row.timestampNormalized != null),
        isTrue,
      );

      final importRow = await database.select(database.imports).getSingle();
      expect(importRow.platform, 'telegram');
      expect(importRow.format, 'json');
    });
  });
}
