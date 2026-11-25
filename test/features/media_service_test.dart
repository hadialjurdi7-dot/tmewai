import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/attachment_repository.dart';
import 'package:personal_data_agent/src/features/media/media_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

Map<String, Object?> _photoMessage(
  String sender,
  DateTime at,
  List<String> paths,
) => {
  'sender_name': sender,
  'timestamp_ms': at.millisecondsSinceEpoch,
  'content': 'صورة من $at',
  'photos': [
    for (final path in paths) {'uri': path},
  ],
};

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-media-');
    database = AppDatabase(NativeDatabase.memory());
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/leila/message_1.json',
          jsonEncode({
            'title': 'ليلى خالد',
            'messages': [
              _photoMessage('ليلى خالد', DateTime.utc(2019, 3, 12), [
                'messages/inbox/leila/photos/a.jpg',
              ]),
              _photoMessage('ليلى خالد', DateTime.utc(2021, 8, 24), [
                'messages/inbox/leila/photos/b.jpg',
              ]),
              _photoMessage('سامر', DateTime.utc(2023, 5, 1), [
                'messages/inbox/leila/photos/c.jpg',
                'messages/inbox/leila/photos/d.jpg',
              ]),
            ],
          }),
        ),
      );
    for (final name in ['a', 'b', 'c', 'd']) {
      archive.addFile(
        ArchiveFile('messages/inbox/leila/photos/$name.jpg', 4, [1, 2, 3, 4]),
      );
    }
    final file = File('${tempDirectory.path}/media.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('the gallery counts every attachment and buckets it by UTC year', () async {
    final snapshot = await MediaService(AttachmentRepository(database)).load();

    expect(snapshot.total, 4);
    expect(snapshot.matched, 4);
    expect(snapshot.items.length, 4);
    expect(snapshot.selectedYear, isNull);
    expect(
      [for (final row in snapshot.years) (row.year, row.count)],
      [(2023, 2), (2021, 1), (2019, 1)],
    );
    expect(snapshot.oldestYear, 2019);
    // Newest first: the 2023 photos lead.
    expect(snapshot.items.first.at, DateTime.utc(2023, 5, 1));
    expect(snapshot.items.first.mediaType, 'image');
    expect(snapshot.items.first.hasPath, isTrue);
  });

  test('a year filter narrows the grid to that year', () async {
    final service = MediaService(AttachmentRepository(database));

    final snapshot = await service.load(year: 2021);

    expect(snapshot.selectedYear, 2021);
    expect(snapshot.matched, 1);
    expect(snapshot.selectedCount, 1);
    expect(snapshot.items.single.at, DateTime.utc(2021, 8, 24));
    expect(snapshot.years.length, 3);

    final none = await service.load(year: 2015);
    expect(none.matched, 0);
    expect(none.items, isEmpty);
  });

  test('people are ranked by how many attachment rows they carry', () async {
    final snapshot = await MediaService(AttachmentRepository(database)).load();

    expect(snapshot.people.length, 2);
    // ليلى carries two photos (2019, 2021) and سامر two (2023); the tie is
    // broken by the person id, so the older row leads.
    expect(snapshot.people.first.name, 'ليلى خالد');
    expect(snapshot.people.first.count, 2);
    expect(snapshot.people.last.name, 'سامر');
    expect(snapshot.people.last.count, 2);
  });

  test('video, audio and undated rows never enter the image counters', () async {
    // A second archive adds one video, one audio file and one image the export
    // did not date. The gallery is an image screen, so none of them may move
    // the header away from the tiles it draws.
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/leila/message_2.json',
          jsonEncode({
            'title': 'ليلى خالد',
            'messages': [
              {
                'sender_name': 'ليلى خالد',
                'timestamp_ms': DateTime.utc(2024, 1, 1).millisecondsSinceEpoch,
                'content': 'فيديو وصوت',
                'videos': [
                  {'uri': 'messages/inbox/leila/videos/v.mp4'},
                ],
                'audio_files': [
                  {'uri': 'messages/inbox/leila/audio/a.m4a'},
                ],
              },
              {
                'sender_name': 'ليلى خالد',
                'content': 'صورة بلا تاريخ',
                'photos': [
                  {'uri': 'messages/inbox/leila/photos/e.jpg'},
                ],
              },
            ],
          }),
        ),
      )
      ..addFile(ArchiveFile('messages/inbox/leila/videos/v.mp4', 3, [1, 2, 3]))
      ..addFile(ArchiveFile('messages/inbox/leila/audio/a.m4a', 3, [4, 5, 6]))
      ..addFile(ArchiveFile('messages/inbox/leila/photos/e.jpg', 3, [7, 8, 9]));
    final file = File('${tempDirectory.path}/mixed.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);

    final repository = AttachmentRepository(database);
    // The table really holds seven rows: the four images of the first archive
    // plus one video, one audio file and one undated image.
    expect(await repository.count(), 7);

    final snapshot = await MediaService(repository).load();

    expect(snapshot.total, 5, reason: 'the header counts images only');
    expect(snapshot.matched, 5);
    expect(snapshot.years.fold<int>(0, (sum, row) => sum + row.count), 4);
    expect(snapshot.items.map((item) => item.mediaType).toSet(), {'image'});
    // The undated image has no year bucket, yet it is still counted and drawn.
    expect(snapshot.items.length, 5);
  });
}
