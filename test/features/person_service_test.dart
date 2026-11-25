import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/attachment_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/person_repository.dart';
import 'package:personal_data_agent/src/features/people/person_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

Map<String, Object?> _message(
  String sender,
  DateTime at,
  String content, {
  List<Map<String, Object?>>? photos,
}) => {
  'sender_name': sender,
  'timestamp_ms': at.millisecondsSinceEpoch,
  'content': content,
  'photos': ?photos,
};

PersonService _service(AppDatabase database) => PersonService(
  PersonRepository(database),
  OverviewRepository(database),
  AttachmentRepository(database),
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-person-');
    database = AppDatabase(NativeDatabase.memory());
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/leila/message_1.json',
          jsonEncode({
            'title': 'ليلى خالد',
            'messages': [
              _message('ليلى خالد', DateTime.utc(2019, 3, 12, 10, 14), 'أ'),
              _message('سامر', DateTime.utc(2019, 3, 12, 10, 18), 'ب'),
              _message(
                'ليلى خالد',
                DateTime.utc(2021, 8, 24, 9, 5),
                'ج',
                photos: [
                  {'uri': 'messages/inbox/leila/photos/1.jpg'},
                ],
              ),
              _message('ليلى خالد', DateTime.utc(2021, 8, 24, 9, 6), 'د'),
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/yearly/message_1.json',
          jsonEncode({
            'title': 'أرشيف السنة',
            'messages': [
              _message('سامر', DateTime.utc(2022, 1, 1), 'ه'),
              _message('ليلى خالد', DateTime.utc(2022, 1, 2), 'و'),
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile('messages/inbox/leila/photos/1.jpg', 4, [1, 2, 3, 4]),
      );
    final file = File('${tempDirectory.path}/person.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('the list ranks people by messages and opens the first one', () async {
    final snapshot = await _service(database).load();      expect(snapshot.people.length, 2);
    expect(snapshot.people.first.name, 'ليلى خالد');
    expect(snapshot.people.first.messageCount, 4);
    expect(snapshot.selected!.id, snapshot.people.first.id);
    // The shortcuts and the archive card state the whole archive's numbers,
    // not only the open person's.
    expect(snapshot.messages, 6);
    expect(snapshot.photos, 1);
    expect(snapshot.events, 6);
    expect(snapshot.lastDatedAt, DateTime.utc(2022, 1, 2));
  });

  test('person photo counts exclude video and audio rows', () async {
    final image = await database
        .customSelect(
          'SELECT event_id, source_file_id FROM attachments '
          "WHERE media_type = 'image' LIMIT 1",
        )
        .getSingle();
    for (final mediaType in ['video', 'audio']) {
      await database
          .into(database.attachments)
          .insert(
            AttachmentsCompanion.insert(
              eventId: Value(image.read<int>('event_id')),
              sourceFileId: image.read<int>('source_file_id'),
              mediaType: mediaType,
              sizeBytes: 1,
            ),
          );
    }

    final snapshot = await _service(database).load();
    expect(snapshot.selected!.photoCount, 1);
    expect(snapshot.selected!.photos, hasLength(1));
  });

  test(
    'the profile counts only that person, with yearly gaps as zero',
    () async {
      final snapshot = await _service(database).load();
      final profile = snapshot.selected!;

      expect(profile.name, 'ليلى خالد');
      expect(profile.platform, 'facebook');
      expect(profile.messageCount, 4);
      expect(profile.photoCount, 1);
      expect(profile.firstAt, DateTime.utc(2019, 3, 12, 10, 14));
      expect(profile.lastAt, DateTime.utc(2022, 1, 2));
      expect(profile.days, 3);
      expect(profile.conversationId, isNotNull);
      expect(profile.firstYear, 2019);
      expect(profile.lastYear, 2022);
      expect(profile.yearSpan, 4);
      expect(
        [for (final year in profile.years) (year.year, year.count)],
        [(2019, 1), (2020, 0), (2021, 2), (2022, 1)],
      );
      expect(profile.busiestYear, 2021);
      // The first page of their text messages, newest first; the total is the
      // honest count the paged list states “loaded N of M” against.
      expect(profile.messageTotal, 4);
      expect(profile.lines.length, 4);
      expect(profile.lines.first.text, 'و');
      expect(profile.lines.first.at, DateTime.utc(2022, 1, 2));
      expect(profile.lines.last.text, 'أ');
      expect(profile.photos.length, 1);
      expect(profile.photos.single.at, DateTime.utc(2021, 8, 24, 9, 5));
    },
  );

  test('an explicit person opens that profile', () async {
    final service = _service(database);
    final first = await service.load();
    final second = first.people.last;

    final snapshot = await service.load(personId: second.id);

    expect(snapshot.selected!.name, 'سامر');
    expect(snapshot.selected!.messageCount, 2);
    expect(snapshot.selected!.photoCount, 0);
    expect(snapshot.selected!.photos, isEmpty);
    expect(snapshot.selected!.firstYear, 2019);
    expect(snapshot.selected!.lastYear, 2022);
  });
}
