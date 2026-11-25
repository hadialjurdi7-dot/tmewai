import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

/// Facebook's export writer sometimes took the UTF-8 bytes of a JSON document,
/// read them as Latin-1 characters (`أهلاً` becomes `Ø£Ù‡Ù„Ø§Ù‹`) and saved
/// that text as UTF-8 again. These tests import such a file and check the text
/// the database stores, not merely that the import finished.
void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late ImportCoordinator coordinator;

  setUpAll(() {
    // Each test opens its own in-memory database on purpose.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-encoding-');
    database = AppDatabase(NativeDatabase.memory());
    coordinator = ImportCoordinator(database: database);
  });

  tearDown(() async {
    await coordinator.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('a double-encoded message file is stored as readable Arabic', () async {
    final messages = jsonEncode({
      'title': 'أصدقاء',
      'participants': [
        {'name': 'ليلى'},
      ],
      'messages': [
        {
          'sender_name': 'ليلى',
          'timestamp_ms': 1700000000123,
          'content': 'أهلاً بك، شو الطبخة اليوم؟',
        },
        {
          'sender_name': 'ليلى',
          'timestamp_ms': 1700000001123,
          'content': '&amp; &#1587;&#1604;&#1575;&#1605;',
        },
      ],
    });
    final file = await _writeZip(tempDirectory, {
      'messages/inbox/1/message_1.json': _doubleEncode(messages),
    });

    final preview = await const FacebookJsonImporter().preview(file);
    expect(preview.unsupportedJsonFiles, 0);
    expect(preview.records, hasLength(2));
    // The preview and the stored row must agree; repairing only at write time
    // would leave the on-screen preview unreadable.
    expect(preview.records.first.text, 'أهلاً بك، شو الطبخة اليوم؟');
    expect(preview.records.first.senderName, 'ليلى');
    expect(preview.records.first.conversationTitle, 'أصدقاء');

    final outcome = await coordinator.importArchive(file) as ImportOutcome;
    expect(outcome.events, 2);

    final stored = await database
        .customSelect('SELECT text_content FROM events ORDER BY id')
        .get();
    expect(
      stored.map((row) => row.read<String?>('text_content')).toList(),
      ['أهلاً بك، شو الطبخة اليوم؟', '& سلام'],
    );
    // Nothing in the stored text is still mojibake.
    for (final text in stored.map((row) => row.read<String?>('text_content'))) {
      expect(text, isNot(matches(RegExp(r'[ÃÂØÙ]'))));
    }

    final people = await database.select(database.people).get();
    expect(people.map((person) => person.displayName), ['ليلى']);
    final conversations = await database.select(database.conversations).get();
    expect(conversations.single.title, 'أصدقاء');
  });

  test('a message file that is not valid UTF-8 is recovered, not dropped',
      () async {
    const marker = 'INVALIDBYTE';
    final messages = jsonEncode({
      'title': 'الأصدقاء',
      'messages': [
        {
          'sender_name': 'Sara',
          'timestamp_ms': 1700000000123,
          'content': 'أهلاً بك',
        },
        {
          'sender_name': 'Sara',
          'timestamp_ms': 1700000001123,
          'content': 'tag:$marker',
        },
      ],
    });
    final bytes = _doubleEncode(messages);
    // Replace the marker with a lone Latin-1 byte. A UTF-8 decoder rejects it,
    // which used to mark the whole file malformed and drop both messages.
    final markerAt = _indexOf(bytes, utf8.encode(marker));
    final broken = <int>[
      ...bytes.sublist(0, markerAt),
      0xE9,
      ...bytes.sublist(markerAt + marker.length),
    ];
    final file = await _writeZip(tempDirectory, {
      'messages/inbox/1/message_1.json': broken,
    });

    final preview = await const FacebookJsonImporter().preview(file);
    expect(preview.supportedFiles, 1);
    expect(preview.unsupportedJsonFiles, 0);
    expect(preview.warnings, isNot(contains('malformed_message_json')));
    expect(preview.records, hasLength(2));
    expect(preview.records.first.text, 'أهلاً بك');

    final outcome = await coordinator.importArchive(file) as ImportOutcome;
    expect(outcome.events, 2);

    final stored = await database
        .customSelect('SELECT text_content FROM events ORDER BY id')
        .get();
    expect(
      stored.map((row) => row.read<String?>('text_content')).first,
      'أهلاً بك',
    );
  });
}

/// The bytes the broken writer produced: UTF-8 bytes read as Latin-1, then
/// saved as UTF-8 again.
List<int> _doubleEncode(String jsonText) =>
    utf8.encode(latin1.decode(utf8.encode(jsonText)));

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  throw StateError('marker not present');
}

Future<File> _writeZip(
  Directory directory,
  Map<String, List<int>> entries,
) async {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  final file = File('${directory.path}/export.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive));
  return file;
}
