import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late ImportCoordinator coordinator;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-media-test-');
    database = AppDatabase(NativeDatabase.memory());
    coordinator = ImportCoordinator(database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  const photoPath = 'posts/media/photo.jpg';
  const videoPath = 'posts/media/clip.mp4';
  const chatPhotoPath = 'messages/inbox/friends/photos/chat.jpg';
  const postFilePath = 'posts/your_posts_1.json';
  const messageFilePath = 'messages/inbox/friends/message_1.json';

  final photoBytes = utf8.encode('synthetic-photo-bytes');
  final videoBytes = utf8.encode('synthetic-video-bytes');
  final chatPhotoBytes = utf8.encode('synthetic-chat-photo');

  /// A ZIP holding one posts file, one message file and their media entries.
  Future<File> writeZip({
    String postsJson = '{"posts":[]}',
    String messagesJson = '{"messages":[]}',
    Map<String, List<int>> media = const {},
    String name = 'a.zip',
  }) async {
    final archive = Archive()
      ..addFile(ArchiveFile.string(postFilePath, postsJson))
      ..addFile(ArchiveFile.string(messageFilePath, messagesJson));
    media.forEach((path, bytes) {
      archive.addFile(ArchiveFile.bytes(path, bytes));
    });
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  Map<String, dynamic> postEntry({
    required int timestamp,
    required String text,
    List<String> mediaUris = const [],
  }) => {
    'timestamp': timestamp,
    'data': [
      {'post': text},
    ],
    'attachments': [
      for (final uri in mediaUris)
        {
          'data': [
            {
              'media': {'uri': uri},
            },
          ],
        },
    ],
  };

  Map<String, dynamic> messageEntry({
    required int timestampMs,
    required String content,
    List<String> photoUris = const [],
  }) => {
    'sender_name': 'Fixtures Person',
    'timestamp_ms': timestampMs,
    'content': content,
    'photos': [
      for (final uri in photoUris) {'uri': uri},
    ],
  };

  test('records media metadata with the right type, length and hash', () async {
    final file = await writeZip(
      postsJson: jsonEncode({
        'posts': [
          postEntry(
            timestamp: 1700000000,
            text: 'A post with media.',
            mediaUris: [photoPath, videoPath],
          ),
        ],
      }),
      messagesJson: jsonEncode({
        'title': 'Friends',
        'messages': [
          messageEntry(
            timestampMs: 1700000000000,
            content: 'A message with a photo.',
            photoUris: [chatPhotoPath],
          ),
        ],
      }),
      media: {
        photoPath: photoBytes,
        videoPath: videoBytes,
        chatPhotoPath: chatPhotoBytes,
      },
    );

    final outcome = await coordinator.importArchive(file) as ImportOutcome;

    expect(outcome.skippedRecords, 0);
    expect(outcome.attachments, 3);
    expect(outcome.warnings, isNot(contains('attachment_path_rejected')));

    final rows = await (database.select(
      database.attachments,
    )..orderBy([(table) => OrderingTerm.asc(table.relativePath)])).get();

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.relativePath), [
      chatPhotoPath,
      videoPath,
      photoPath,
    ]);
    expect(rows.map((row) => row.mediaType), ['image', 'video', 'image']);

    final byPath = {for (final row in rows) row.relativePath: row};
    for (final (path, bytes, type) in [
      (photoPath, photoBytes, 'image'),
      (videoPath, videoBytes, 'video'),
      (chatPhotoPath, chatPhotoBytes, 'image'),
    ]) {
      final row = byPath[path]!;
      expect(row.mediaType, type);
      expect(
        row.sizeBytes,
        bytes.length,
        reason: 'the length is the archive entry length',
      );
      expect(
        row.contentHash,
        sha256.convert(bytes).toString(),
        reason: 'the hash is of the entry bytes, in memory only',
      );
      expect(row.eventId, isNotNull);
      expect(row.sourceFileId, isNotNull);
    }
  });

  test('rejects a media path that escapes the archive with a safe code', () async {
    final file = await writeZip(
      postsJson: jsonEncode({
        'posts': [
          postEntry(
            timestamp: 1700000000,
            text: 'Escaping references.',
            mediaUris: [
              '../../secret.jpg',
              '/etc/passwd.jpg',
              'posts/media/missing.jpg',
            ],
          ),
        ],
      }),
      media: {
        photoPath: photoBytes,
      },
    );

    final outcome = await coordinator.importArchive(file) as ImportOutcome;

    expect(outcome.events, 1, reason: 'the post is still imported');
    expect(outcome.attachments, 0, reason: 'nothing unsafe is stored');
    expect(outcome.warnings, contains('attachment_path_rejected'));
    expect(outcome.warnings, contains('attachment_missing'));
    expect(await database.select(database.attachments).get(), isEmpty);
  });

  test(
    'records an oversized entry as metadata only without reading it',
    () async {
      final file = await writeZip(
        postsJson: jsonEncode({
          'posts': [
            postEntry(
              timestamp: 1700000000,
              text: 'Large media.',
              mediaUris: [photoPath],
            ),
          ],
        }),
        media: {
          photoPath: photoBytes,
        },
      );

      final smallBudget = ImportCoordinator(
        database: database,
        importer: const FacebookJsonImporter(maxAttachmentHashBytes: 4),
      );
      final outcome = await smallBudget.importArchive(file) as ImportOutcome;

      final row = await database.select(database.attachments).getSingle();
      expect(row.relativePath, photoPath);
      expect(row.mediaType, 'image');
      expect(row.sizeBytes, photoBytes.length);
      expect(
        row.contentHash,
        isNull,
        reason: 'an entry over the hashing budget is never read',
      );
      expect(outcome.warnings, contains('attachment_hash_size_limit'));
      expect(outcome.attachments, 1);
    },
  );

  test('deleting an import cascades its attachment rows', () async {
    final file = await writeZip(
      postsJson: jsonEncode({
        'posts': [
          postEntry(
            timestamp: 1700000000,
            text: 'A post with media.',
            mediaUris: [photoPath],
          ),
        ],
      }),
      media: {
        photoPath: photoBytes,
      },
    );

    final outcome = await coordinator.importArchive(file) as ImportOutcome;
    expect(await database.select(database.attachments).get(), hasLength(1));

    await (database.delete(
      database.imports,
    )..where((table) => table.id.equals(outcome.importId))).go();

    expect(await database.select(database.attachments).get(), isEmpty);
    expect(await database.select(database.events).get(), isEmpty);
  });
}
