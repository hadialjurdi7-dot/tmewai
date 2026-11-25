import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';

/// Locks the two defects reported in issues #61 and #62 so they cannot come
/// back: «صور» must count images only, and «آخر النشاط» must read the newest
/// events instead of the oldest page of a truncated result.
void main() {
  late AppDatabase database;
  late int importId;
  late int sourceFileId;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    importId = await database.into(database.imports).insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:issues-61-62',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    sourceFileId = await database.into(database.sourceFiles).insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> insertAttachment(String mediaType) => database
      .into(database.attachments)
      .insert(
        AttachmentsCompanion.insert(
          sourceFileId: sourceFileId,
          mediaType: mediaType,
          sizeBytes: 1,
        ),
      );

  test('#61 the photo KPI counts images only, not every attachment', () async {
    await insertAttachment('image');
    await insertAttachment('image');
    await insertAttachment('video');
    await insertAttachment('audio');
    await insertAttachment('file');

    final totals = await OverviewRepository(database).archiveTotals();

    expect(totals.photos, 2, reason: 'video/audio/file must not be «صور»');
  });

  test('#62 latest events are the newest, even past the earlier page limit',
      () async {
    // 5,200 events: more than the old 5,000-row page that used to be read
    // ascending, which made the three «آخر النشاط» rows come from the oldest
    // end of the archive.
    for (var i = 0; i < 5200; i++) {
      await database.into(database.events).insert(
            EventsCompanion.insert(
              sourceFileId: sourceFileId,
              eventType: 'message',
              sourceLocator: 'loc-$i',
              importId: importId,
              platform: 'facebook',
              timezoneStatus: TimezoneStatus.utc,
              timestampNormalized: Value(DateTime.utc(2020, 1, 1).add(
                Duration(hours: i),
              )),
              textContent: Value('event $i'),
            ),
          );
    }

    final latest = await TimelineRepository(database).latestEvents(limit: 3);

    expect(latest, hasLength(3));
    expect(latest.map((e) => e.textContent), ['event 5199', 'event 5198', 'event 5197']);
  });
}
