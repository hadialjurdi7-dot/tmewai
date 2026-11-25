import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
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
    tempDirectory = await Directory.systemTemp.createTemp('pda-posts-test-');
    database = AppDatabase(NativeDatabase.memory());
    coordinator = ImportCoordinator(database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  const postsPath = 'your_facebook_activity/posts/your_posts_1.json';
  const checkInsPath =
      'your_facebook_activity/posts/'
      'your_posts__check_ins__photos_and_videos_1.json';

  Future<File> writeZip(
    String body, {
    String name = 'a.zip',
    String path = postsPath,
  }) async {
    final archive = Archive()..addFile(ArchiveFile.string(path, body));
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  /// One post entry, as exported: a timestamp, a data list and attachments.
  Map<String, dynamic> postEntry(
    int timestamp,
    String? text, {
    List<Map<String, dynamic>> attachments = const [],
  }) => {
    'timestamp': timestamp,
    'data': [
      if (text != null) {'post': text},
    ],
    'attachments': attachments,
  };

  test('parses the newer posts object shape', () async {
    final file = await writeZip(
      jsonEncode({
        'posts': [
          postEntry(1700000000, 'A synthetic post.', attachments: [
            {
              'data': [
                {'media': {'uri': 'media/photo.jpg'}},
                {'external_context': {'url': 'https://example.invalid'}},
              ],
            },
          ]),
          postEntry(1700000100, 'A second synthetic post.'),
        ],
      }),
    );

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(2));
    final first = result.records.first;
    expect(first.eventType, 'post');
    expect(first.text, 'A synthetic post.');
    expect(first.conversationKey, isNull, reason: 'a post is not a message');
    expect(first.senderName, isNull);
    expect(first.sourceLocator, '$postsPath#/posts/0');
    expect(first.timestampRaw, '1700000000');
    expect(
      first.timestampUtc,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );
    expect(first.metadata, {
      'attachments': '1',
      'attachment_types': 'external_context,media',
    });
    expect(
      result.records.last.metadata,
      isNull,
      reason: 'a post with no attachments keeps no metadata',
    );
    expect(result.supportedFiles, 1);
    expect(result.skippedRecords, 0);
    expect(result.warnings, isNot(contains('no_supported_files_found')));
  });

  test('parses the older top-level array shape', () async {
    final file = await writeZip(
      jsonEncode([
        postEntry(1700000000, 'Older shape post.'),
        postEntry(1700000100, 'Older shape attachment post.', attachments: [
          {
            'data': [
              {'media': {'uri': 'media/clip.mp4'}},
            ],
          },
        ]),
      ]),
      path: checkInsPath,
    );

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(2));
    expect(
      result.records.map((record) => record.eventType),
      everyElement('post'),
    );
    expect(result.records.first.sourcePath, checkInsPath);
    expect(result.records.first.sourceLocator, '$checkInsPath#/posts/0');
    expect(result.records.last.text, 'Older shape attachment post.');
    expect(result.records.last.metadata, {
      'attachments': '1',
      'attachment_types': 'media',
    });
  });

  test('leaves an attachment-only post without text', () async {
    final file = await writeZip(
      jsonEncode({
        'posts': [
          postEntry(1700000000, null, attachments: [
            {
              'data': [
                {'media': {'uri': 'media/one.jpg'}},
              ],
            },
            {
              'data': [
                {'media': {'uri': 'media/two.jpg'}},
              ],
            },
          ]),
        ],
      }),
    );

    final result = await const FacebookJsonImporter().preview(file);

    final record = result.records.single;
    expect(record.text, isNull, reason: 'a photo post has no post text');
    expect(record.eventType, 'post');
    expect(record.metadata, {
      'attachments': '2',
      'attachment_types': 'media',
    });
    expect(result.skippedRecords, 0);
  });

  test('skips a malformed post with a safe code', () async {
    final file = await writeZip(
      jsonEncode({
        'posts': [
          postEntry(1700000000, 'Kept.'),
          'not a post',
          {'timestamp': 1700000001, 'data': 'not a list'},
          {'timestamp': 1700000002, 'data': [{'post': 7}]},
          {'timestamp': 1700000003, 'data': [], 'attachments': 'not a list'},
          {'timestamp': 1700000004, 'data': []},
          postEntry(9999999999999999, 'Kept, with an unusable timestamp.'),
        ],
      }),
    );

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, hasLength(2));
    expect(result.records.first.text, 'Kept.');
    expect(result.records.last.text, 'Kept, with an unusable timestamp.');
    expect(result.records.last.timestampUtc, isNull);
    expect(
      result.records.last.timestampRaw,
      isNull,
      reason: 'an out-of-range timestamp is reported, not guessed',
    );
    expect(result.skippedRecords, 5);
    expect(result.warnings, contains('invalid_post_record'));
    expect(result.warnings, contains('invalid_post_timestamp'));
    expect(result.warnings, isNot(contains('no_supported_files_found')));
    expect(result.supportedFiles, 1);
  });

  test('classifies an unusable posts file by its known folder, not as unknown', () async {
    final file = await writeZip('{"likes":[]}');

    final result = await const FacebookJsonImporter().preview(file);

    expect(result.records, isEmpty);
    expect(result.supportedFiles, 0);
    expect(
      result.files.single.status,
      FacebookPreviewFileStatus.knownNotImported,
    );
    expect(result.files.single.errorCode, 'unsupported_posts_json');
    expect(result.knownNotImportedJsonFiles, 1);
    expect(result.unsupportedJsonFiles, 0);
    expect(result.warnings, contains('known_folders_not_imported'));
    expect(result.warnings, isNot(contains('unsupported_json_files_present')));
    expect(result.warnings, contains('no_supported_files_found'));
  });

  test('rejects an oversized posts payload', () async {
    final file = await writeZip(
      jsonEncode({
        'posts': [postEntry(1700000000, 'A synthetic post.')],
      }),
    );

    await expectLater(
      const FacebookJsonImporter(maxJsonFileBytes: 4).preview(file),
      throwsA(
        isA<ArchiveInspectionException>().having(
          (error) => error.code,
          'code',
          'json_file_size_limit',
        ),
      ),
    );
  });

  test('enforces the record count limit on post records', () async {
    final file = await writeZip(
      jsonEncode({
        'posts': [
          postEntry(1700000000, 'One.'),
          postEntry(1700000100, 'Two.'),
          postEntry(1700000200, 'Three.'),
        ],
      }),
    );

    await expectLater(
      const FacebookJsonImporter(maxRecords: 2).preview(file),
      throwsA(
        isA<FacebookImportException>().having(
          (error) => error.code,
          'code',
          'record_count_limit',
        ),
      ),
    );
  });

  test('persists posts as events and the coverage report supports them', () async {
    final file = await writeZip(
      jsonEncode({
        'posts': [
          postEntry(1700000000, 'A persisted post.', attachments: [
            {
              'data': [
                {'media': {'uri': 'media/photo.jpg'}},
              ],
            },
          ]),
        ],
      }),
    );

    final outcome = await coordinator.importArchive(file) as ImportOutcome;

    expect(outcome.events, 1);
    expect(outcome.conversations, 0, reason: 'posts have no conversation');
    expect(outcome.people, 0, reason: 'a post names no actor in the export');
    final coverage = coordinator.lastCoverageReport!;
    expect(coverage.supportedFiles, 1);
    expect(coverage.entries.single.reason.code, 'supported');
    expect(coverage.counts['records_parsed'], 1);

    final event = await database.select(database.events).getSingle();
    expect(event.eventType, 'post');
    expect(event.textContent, 'A persisted post.');
    expect(
      event.metadataJson,
      '{"attachments":"1","attachment_types":"media"}',
    );
    expect(event.conversationId, isNull);
    expect(event.actorId, isNull);
  });
}
