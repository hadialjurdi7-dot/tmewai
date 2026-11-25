import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/timeline_repository.dart';

/// How events are grouped.
enum TimelineGrouping {
  day('%Y-%m-%d'),
  month('%Y-%m');

  const TimelineGrouping(this.strftimeFormat);

  /// SQLite format, bound as a parameter in the repository query.
  final String strftimeFormat;
}

/// One aggregated bucket of the timeline.
///
/// The model is deliberately cheap: the count always comes from one SQL
/// aggregate, and the rows are read page by page only when the bucket is on
/// screen. A bucket therefore never holds the whole group in memory.
class TimelineBucket {
  const TimelineBucket({
    required this.key,
    required this.count,
    this.start,
    this.end,
    this.isUnknown = false,
  });

  /// `YYYY-MM-DD` or `YYYY-MM` (UTC), or null for the unknown bucket.
  final String? key;

  /// Exact count from SQL, even when only a page of rows is loaded.
  final int count;

  /// Inclusive UTC start of the bucket, null for the unknown bucket.
  final DateTime? start;

  /// Exclusive UTC end of the bucket, null for the unknown bucket.
  final DateTime? end;

  /// True for events whose export timestamp could not be normalized. They are
  /// never presented as if their date were known.
  final bool isUnknown;
}

class Timeline {
  const Timeline({
    required this.grouping,
    required this.buckets,
    required this.totalCount,
    required this.unknownCount,
  });

  final TimelineGrouping grouping;

  /// Dated buckets ascending, then the unknown bucket last.
  final List<TimelineBucket> buckets;

  final int totalCount;
  final int unknownCount;

  bool get isEmpty => buckets.isEmpty;
}

/// Repository provider for the timeline, overridable in tests.
final timelineRepositoryProvider = FutureProvider<TimelineRepository>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return TimelineRepository(workspace.database);
});

/// Deterministic aggregation of events into day or month buckets.
///
/// [load] answers only with counts and bucket keys (`GROUP BY` in SQL); it
/// never reads event rows. [loadBucketPage] then reads one page for one visible
/// group. Buckets are keyed in UTC so a device timezone can never move an
/// event into another day.
class TimelineService {
  const TimelineService(this.repository);

  final TimelineRepository repository;

  /// Rows per visible group page.
  static const int bucketPageSize = 10;

  Future<Timeline> load({
    required TimelineGrouping grouping,
    DateTime? from,
    DateTime? to,
    String? eventType,
  }) async {
    final counts = await repository.countsByBucket(
      strftimeFormat: grouping.strftimeFormat,
      from: from,
      to: to,
      eventType: eventType,
    );

    final keys = <String?>[
      ...counts.keys.whereType<String>().toList()..sort(),
      if (counts.containsKey(null)) null,
    ];
    final buckets = <TimelineBucket>[
      for (final key in keys)
        TimelineBucket(
          key: key,
          count: counts[key] ?? 0,
          start: _startOfBucket(key, grouping),
          end: _endOfBucket(key, grouping),
          isUnknown: key == null,
        ),
    ];

    final totalCount = counts.values.fold(0, (sum, count) => sum + count);
    return Timeline(
      grouping: grouping,
      buckets: List.unmodifiable(buckets),
      totalCount: totalCount,
      unknownCount: counts[null] ?? 0,
    );
  }

  /// One page of rows for one visible bucket, oldest first.
  Future<List<TimelineRow>> loadBucketPage(
    TimelineBucket bucket, {
    DateTime? from,
    DateTime? to,
    String? eventType,
    int offset = 0,
    int limit = bucketPageSize,
  }) {
    return repository.eventsPage(
      bucketStart: bucket.start,
      bucketEnd: bucket.end,
      from: from,
      to: to,
      eventType: eventType,
      unknownTimestamps: bucket.isUnknown,
      limit: limit,
      offset: offset,
    );
  }

  /// UTC bucket key for [timestamp], or null when it is unknown.
  static String? bucketKey(DateTime? timestamp, TimelineGrouping grouping) {
    if (timestamp == null) return null;
    final utc = timestamp.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final year = utc.year.toString().padLeft(4, '0');
    return grouping == TimelineGrouping.day
        ? '$year-${two(utc.month)}-${two(utc.day)}'
        : '$year-${two(utc.month)}';
  }

  static DateTime? _startOfBucket(String? key, TimelineGrouping grouping) {
    if (key == null) return null;
    final parts = key.split('-').map(int.tryParse).toList();
    if (parts.length < 2 || parts[0] == null || parts[1] == null) return null;
    if (grouping == TimelineGrouping.month) {
      return DateTime.utc(parts[0]!, parts[1]!);
    }
    if (parts.length < 3 || parts[2] == null) return null;
    return DateTime.utc(parts[0]!, parts[1]!, parts[2]!);
  }

  static DateTime? _endOfBucket(String? key, TimelineGrouping grouping) {
    final start = _startOfBucket(key, grouping);
    if (start == null) return null;
    return grouping == TimelineGrouping.month
        ? DateTime.utc(start.year, start.month + 1)
        : start.add(const Duration(days: 1));
  }
}
