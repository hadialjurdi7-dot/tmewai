import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';
import 'package:personal_data_agent/src/features/home/home_service.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_service.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;
  late TimelineService service;
  late int importId;
  late int sourceFileId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = TimelineService(TimelineRepository(database));
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:timeline',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    sourceFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'posts/your_posts_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );

    Future<void> addEvent(String type, DateTime? timestamp, String text) async {
      await database
          .into(database.events)
          .insert(
            EventsCompanion.insert(
              importId: importId,
              sourceFileId: sourceFileId,
              sourceLocator: 'posts/your_posts_1.json#/$text',
              platform: 'facebook',
              eventType: type,
              timezoneStatus: timestamp == null
                  ? TimezoneStatus.unknown
                  : TimezoneStatus.utc,
              timestampNormalized: Value(timestamp?.toUtc()),
              textContent: Value(text),
            ),
          );
    }

    await addEvent('post', DateTime.utc(2023, 11, 1, 9), 'day-one-a');
    await addEvent('message', DateTime.utc(2023, 11, 1, 21), 'day-one-b');
    await addEvent('post', DateTime.utc(2023, 11, 2, 8), 'day-two');
    await addEvent('comment', DateTime.utc(2023, 12, 5, 12), 'december');
    await addEvent('post', null, 'no-date-a');
    await addEvent('reaction', null, 'no-date-b');
  });

  tearDown(() => database.close());

  test('day buckets are exact and the unknown bucket is separate', () async {
    final timeline = await service.load(grouping: TimelineGrouping.day);

    expect(timeline.totalCount, 6);
    expect(timeline.unknownCount, 2);
    expect(timeline.buckets.map((bucket) => (bucket.key, bucket.count)), [
      ('2023-11-01', 2),
      ('2023-11-02', 1),
      ('2023-12-05', 1),
      (null, 2),
    ]);
    expect(timeline.buckets.last.isUnknown, isTrue);
    expect(timeline.buckets.first.isUnknown, isFalse);
    expect(timeline.buckets.first.start, DateTime.utc(2023, 11, 1));
    expect(timeline.buckets.first.end, DateTime.utc(2023, 11, 2));

    // Counts are loaded eagerly, rows are requested for one visible group.
    final firstPage = await service.loadBucketPage(timeline.buckets.first);
    expect(firstPage.map((event) => event.textContent), [
      'day-one-a',
      'day-one-b',
    ]);

    final unknownPage = await service.loadBucketPage(timeline.buckets.last);
    expect(unknownPage.map((event) => event.textContent), [
      'no-date-a',
      'no-date-b',
    ]);
  });

  test('a bucket larger than a page is read page by page', () async {
    final timeline = await service.load(grouping: TimelineGrouping.day);
    final first = timeline.buckets.first;

    final page = await service.loadBucketPage(first, limit: 1);
    final next = await service.loadBucketPage(first, limit: 1, offset: 1);

    expect(page.single.textContent, 'day-one-a');
    expect(next.single.textContent, 'day-one-b');
    expect(first.count, 2);
  });

  test('month buckets aggregate the same events exactly', () async {
    final timeline = await service.load(grouping: TimelineGrouping.month);

    expect(timeline.totalCount, 6);
    expect(timeline.buckets.map((bucket) => (bucket.key, bucket.count)), [
      ('2023-11', 3),
      ('2023-12', 1),
      (null, 2),
    ]);
  });

  test('filters apply to counts and rows together', () async {
    final filtered = await service.load(
      grouping: TimelineGrouping.month,
      eventType: 'post',
    );
    expect(filtered.buckets.map((bucket) => (bucket.key, bucket.count)), [
      ('2023-11', 2),
      (null, 1),
    ]);

    final ranged = await service.load(
      grouping: TimelineGrouping.day,
      from: DateTime.utc(2023, 11, 1),
      to: DateTime.utc(2023, 11, 2, 23, 59, 59),
    );
    expect(ranged.buckets.map((bucket) => (bucket.key, bucket.count)), [
      ('2023-11-01', 2),
      ('2023-11-02', 1),
    ]);
    expect(ranged.unknownCount, 0);
  });

  test(
    'home selects the three newest events past the 5000-row timeline page',
    () async {
      await database.batch((batch) {
        for (var index = 0; index < 5005; index++) {
          batch.insert(
            database.events,
            EventsCompanion.insert(
              importId: importId,
              sourceFileId: sourceFileId,
              sourceLocator: 'large-archive/$index',
              platform: 'facebook',
              eventType: 'post',
              timezoneStatus: TimezoneStatus.utc,
              timestampNormalized: Value(
                DateTime.utc(2024).add(Duration(seconds: index)),
              ),
              textContent: Value('event-$index'),
            ),
          );
        }
      });

      final home = await HomeService(
        OverviewRepository(database),
        TimelineRepository(database),
      ).load();

      expect(home.latest.map((event) => event.textContent), [
        'event-5004',
        'event-5003',
        'event-5002',
        'event-5001',
      ]);
    },
  );

  test('bucket keys are UTC and never local-shifted', () {
    expect(
      TimelineService.bucketKey(
        DateTime.utc(2023, 11, 1, 23, 59),
        TimelineGrouping.day,
      ),
      '2023-11-01',
    );
    expect(
      TimelineService.bucketKey(
        DateTime.utc(2023, 11, 1).toLocal(),
        TimelineGrouping.month,
      ),
      '2023-11',
    );
    expect(TimelineService.bucketKey(null, TimelineGrouping.day), isNull);
  });
}
