import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/whatsapp_txt_importer.dart';

void main() {
  const importer = WhatsAppTxtImporter();

  test('Android 24h Arabic chat: exact senders, text and timestamps', () {
    final chat = importer.parse(
      '12/03/2024, 21:14 - Ahmad: مرحبا شو أخبارك؟\n'
      '12/03/2024, 21:15 - Sara: تمام الحمدلله 😊\n'
      '13/03/2024, 08:02 - Ahmad: تصبح على خير',
    );

    expect(chat.messages, hasLength(3));
    expect(chat.systemLines, 0);
    expect(chat.skipped, 0);
    expect(chat.messages[0].sender, 'Ahmad');
    expect(chat.messages[0].text, 'مرحبا شو أخبارك؟');
    expect(chat.messages[0].timestamp, DateTime(2024, 3, 12, 21, 14));
    expect(chat.messages[1].sender, 'Sara');
    expect(chat.messages[1].text, 'تمام الحمدلله 😊');
    expect(chat.messages[1].timestamp, DateTime(2024, 3, 12, 21, 15));
    expect(chat.messages[2].sender, 'Ahmad');
    expect(chat.messages[2].text, 'تصبح على خير');
    expect(chat.messages[2].timestamp, DateTime(2024, 3, 13, 8, 2));
  });

  test('US 12h AM/PM variant is month-first and converts to 24h', () {
    final chat = importer.parse(
      '12/03/2024, 9:05 PM - Ahmad: مرحبا شو أخبارك؟\n'
      '12/03/2024, 12:15 AM - Sara: تمام\n'
      '12/03/2024, 12:30 PM - Sara: مساء الخير',
    );

    expect(chat.messages, hasLength(3));
    expect(chat.messages[0].timestamp, DateTime(2024, 12, 3, 21, 5));
    expect(chat.messages[1].timestamp, DateTime(2024, 12, 3, 0, 15));
    expect(chat.messages[2].timestamp, DateTime(2024, 12, 3, 12, 30));
  });

  test('iOS bracket variant keeps seconds', () {
    final chat = importer.parse(
      '[12/03/2024, 21:09:30] Ahmad: iOS bracket format is different',
    );

    expect(chat.messages, hasLength(1));
    expect(chat.messages.single.sender, 'Ahmad');
    expect(chat.messages.single.text, 'iOS bracket format is different');
    expect(chat.messages.single.timestamp, DateTime(2024, 3, 12, 21, 9, 30));
  });

  test('continuation lines join into one message', () {
    final chat = importer.parse(
      '12/03/2024, 21:08 - Sara: سطر أول\n'
      'سطر ثانٍ من نفس الرسالة\n'
      '12/03/2024, 21:09 - Ahmad: next',
    );

    expect(chat.messages, hasLength(2));
    expect(chat.messages[0].text, 'سطر أول\nسطر ثانٍ من نفس الرسالة');
    expect(chat.messages[0].timestamp, DateTime(2024, 3, 12, 21, 8));
    expect(chat.messages[1].text, 'next');
    expect(chat.skipped, 0);
  });

  test('system lines are counted, never returned as messages', () {
    final chat = importer.parse(
      '12/03/2024, 21:14 - Messages and calls are end-to-end encrypted. '
      'No one outside of this chat, not even WhatsApp, can read or listen '
      'to them.\n'
      '12/03/2024, 21:15 - Sara joined using this group\'s invite link\n'
      '12/03/2024, 21:16 - Ahmad changed the subject to "النادي"\n'
      '12/03/2024, 21:17 - You changed the group icon\n'
      '12/03/2024, 21:18 - Ahmad: real message',
    );

    expect(chat.messages, hasLength(1));
    expect(chat.messages.single.text, 'real message');
    expect(chat.systemLines, 4);
    expect(chat.skipped, 0);
    expect(chat.messages.any((message) => message.isSystem), isFalse);
  });

  test('<attached: …> keeps the text and records the filename', () {
    final chat = importer.parse(
      '12/03/2024, 9:07 PM - Ahmad: '
      '<attached: 00000042-PHOTO-2024-03-12-21-06-17.jpg>\n'
      '12/03/2024, 9:10 PM - Sara: <Media omitted>',
    );

    expect(chat.messages, hasLength(2));
    expect(
      chat.messages[0].text,
      '<attached: 00000042-PHOTO-2024-03-12-21-06-17.jpg>',
    );
    expect(
      chat.messages[0].attachmentName,
      '00000042-PHOTO-2024-03-12-21-06-17.jpg',
    );
    expect(chat.messages[1].text, '<Media omitted>');
    expect(chat.messages[1].attachmentName, isNull);
  });

  test('garbage input yields zero messages and never throws', () {
    for (final garbage in [
      'not a chat\njust words\n???',
      '32/13/2024, 99:99 - Ahmad: broken',
      '[bad] Ahmad: nope',
    ]) {
      final chat = importer.parse(garbage);
      expect(chat.messages, isEmpty);
      expect(chat.systemLines, 0);
      expect(chat.skipped, greaterThan(0));
    }
  });

  test('empty file, BOM and CRLF are handled', () {
    expect(importer.parse('').messages, isEmpty);
    expect(importer.parse('').skipped, 0);

    final chat = importer.parse(
      '\uFEFF12/03/2024, 21:14 - Ahmad: مرحبا\r\n'
      '12/03/2024, 21:15 - Sara: تمام\r\n',
    );
    expect(chat.messages, hasLength(2));
    expect(chat.messages[0].text, 'مرحبا');
    expect(chat.messages[1].text, 'تمام');
    expect(chat.skipped, 0);
  });

  test('Arabic text round-trips exactly with no mojibake', () {
    const original = 'مرحبا شو أخبارك؟ 😊 — سطر ثانٍ';
    final chat = importer.parseBytes(utf8.encode(
      '12/03/2024, 21:14 - أحمد: $original',
    ));
    expect(chat.messages.single.sender, 'أحمد');
    expect(chat.messages.single.text, original);
    expect(chat.messages.single.text, isNot(contains('Ø')));
  });

  group('database write', () {
    late AppDatabase database;
    late ImportCoordinator coordinator;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      coordinator = ImportCoordinator(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('imported chat rows come back from the same events table', () async {
      const source = '12/03/2024, 21:14 - Ahmad: مرحبا شو أخبارك؟\n'
          '12/03/2024, 21:15 - Sara: تمام\n';

      final result = await coordinator.importWhatsAppTextBytes(
        utf8.encode(source),
      );

      expect(result, isA<ImportOutcome>());
      final outcome = result as ImportOutcome;
      expect(outcome.events, 2);
      expect(outcome.people, 2);
      expect(outcome.conversations, 1);

      final rows = await database.select(database.events).get();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.platform).toSet(), {'whatsapp'});
      expect(rows.first.textContent, 'مرحبا شو أخبارك؟');
      expect(rows.last.textContent, 'تمام');
      expect(rows.first.timestampNormalized, DateTime(2024, 3, 12, 21, 14));
    });

    test('a .txt path and a WhatsApp ZIP both reach the same writer', () async {
      const source = '12/03/2024, 21:14 - Ahmad: مرحبا\n';
      final directory = await Directory.systemTemp.createTemp('wa-chat-');
      addTearDown(() => directory.delete(recursive: true));

      final text = File('${directory.path}/_chat.txt')
        ..writeAsStringSync(source);
      final fromText = await coordinator.importWhatsAppText(text.path);
      expect(fromText, isA<ImportOutcome>());
      expect((fromText as ImportOutcome).events, 1);

      final archive = Archive()
        ..addFile(
          ArchiveFile.string('WhatsApp Chat/_chat.txt', source),
        );
      final zip = File('${directory.path}/chat.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final fromZip = await coordinator.importWhatsAppText(zip.path);
      expect(fromZip, isA<ImportOutcome>());
      expect((fromZip as ImportOutcome).events, 1);
      expect(await database.select(database.events).get(), hasLength(2));
    });

    test('attachment filename is stored as allowlisted event metadata',
        () async {
      final result = await coordinator.importWhatsAppTextBytes(
        utf8.encode(
          '12/03/2024, 9:07 PM - Ahmad: '
          '<attached: photo.jpg>',
        ),
      );
      final rows = await database.select(database.events).get();
      expect(result, isA<ImportOutcome>());
      expect(rows, hasLength(1));
      expect(rows.single.metadataJson, contains('photo.jpg'));
      expect(
        rows.single.metadataJson,
        contains(whatsappAttachmentMetadataKey),
      );
    });
  });
}
