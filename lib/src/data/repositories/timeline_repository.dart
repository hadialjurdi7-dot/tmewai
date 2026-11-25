import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// One event read for the timeline, in normalized order.
class TimelineRow {
  const TimelineRow({
    required this.eventId,
    required this.eventType,
    required this.sourceLocator,
    this.timestampNormalized,
    this.textContent,
  });

  final int eventId;
  final String eventType;
  final String sourceLocator;

  /// UTC instant, or null when the export could not be normalized.
  final DateTime? timestampNormalized;

  final String? textContent;
}

/// Timeline reads over `events`.
///
/// Both calls are a single statement for the whole range: counts come from
/// SQL `GROUP BY`, rows from one ordered query, so no bucket costs a query.
class TimelineRepository {
  const TimelineRepository(this._database);

  final AppDatabase _database;

  /// Event counts per bucket, keyed by the `strftime` result.
  ///
  /// A null key is the unknown-timestamp bucket. [strftimeFormat] must be the
  /// day (`%Y-%m-%d`) or month (`%Y-%m`) form; it stays a bound parameter, so
  /// it can never alter the statement.
  Future<Map<String?, int>> countsByBucket({
    required String strftimeFormat,
    DateTime? from,
    DateTime? to,
    String? eventType,
  }) async {
    final (where, variables) = _filters(
      from: from,
      to: to,
      eventType: eventType,
    );
    final rows = await _database
        .customSelect(
          'SELECT strftime(?, timestamp_normalized, \'unixepoch\') AS bucket, '
          'COUNT(*) AS event_count '
          'FROM events $where '
          'GROUP BY bucket ORDER BY bucket ASC',
          variables: [Variable<String>(strftimeFormat), ...variables],
        )
        .get();

    return {
      for (final row in rows)
        row.read<String?>('bucket'): row.read<int>('event_count'),
    };
  }

  /// The newest [limit] events first, with unknown timestamps last.
  ///
  /// `ponytail:` the home activity cards need a small explicit newest-first
  /// read; `loadRows` intentionally pages the oldest 5000 for timeline browsing.
  Future<List<TimelineRow>> latestEvents({int limit = 3}) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final rows = await _database
        .customSelect(
          'SELECT id, event_type, source_locator, timestamp_normalized, '
          'text_content FROM events '
          'ORDER BY timestamp_normalized IS NULL ASC, '
          'timestamp_normalized DESC, id DESC LIMIT ?',
          variables: [Variable<int>(limit)],
        )
        .get();

    return [
      for (final row in rows)
        TimelineRow(
          eventId: row.read<int>('id'),
          eventType: row.read<String>('event_type'),
          sourceLocator: row.read<String>('source_locator'),
          timestampNormalized: row.read<DateTime?>('timestamp_normalized'),
          textContent: row.read<String?>('text_content'),
        ),
    ];
  }

  /// One page of a single timeline bucket, oldest first.
  ///
  /// Unlike [loadRows], which caps the whole range, this asks for the rows of
  /// one day/month group by its UTC half-open range. The range comparison uses
  /// the existing `events_timestamp_normalized` index, so a visible group never
  /// scans the archive and a group larger than a page is read page by page.
  ///
  /// [unknownTimestamps] selects the undated bucket and ignores the bucket
  /// range. Pass [offset] to append the next page.
  Future<List<TimelineRow>> eventsPage({
    DateTime? bucketStart,
    DateTime? bucketEnd,
    DateTime? from,
    DateTime? to,
    String? eventType,
    bool unknownTimestamps = false,
    int limit = 10,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }
    if (unknownTimestamps) {
      return _selectPage(
        where: _pageWhere(
          conditions: ['timestamp_normalized IS NULL'],
          variables: [],
          eventType: eventType,
        ),
        limit: limit,
        offset: offset,
        unknownOrder: true,
      );
    }
    if (bucketStart == null || bucketEnd == null) {
      throw ArgumentError('A dated bucket needs a start and an end.');
    }

    final conditions = <String>['timestamp_normalized >= ?'];
    final variables = <Variable<Object>>[
      Variable<DateTime>(bucketStart.toUtc()),
    ];
    if (from != null && from.toUtc().isAfter(bucketStart.toUtc())) {
      conditions[0] = 'timestamp_normalized >= ?';
      variables[0] = Variable<DateTime>(from.toUtc());
    }
    conditions.add('timestamp_normalized < ?');
    variables.add(Variable<DateTime>(bucketEnd.toUtc()));
    if (to != null) {
      conditions.add('timestamp_normalized <= ?');
      variables.add(Variable<DateTime>(to.toUtc()));
    }

    return _selectPage(
      where: _pageWhere(
        conditions: conditions,
        variables: variables,
        eventType: eventType,
      ),
      limit: limit,
      offset: offset,
    );
  }

  /// Ordered rows for the range, unknown timestamps last, then oldest first.
  Future<List<TimelineRow>> loadRows({
    DateTime? from,
    DateTime? to,
    String? eventType,
    int limit = 5000,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final (where, variables) = _filters(
      from: from,
      to: to,
      eventType: eventType,
    );
    final rows = await _database
        .customSelect(
          'SELECT id, event_type, source_locator, timestamp_normalized, '
          'text_content FROM events $where '
          'ORDER BY timestamp_normalized IS NULL ASC, '
          'timestamp_normalized ASC, id ASC '
          'LIMIT ?',
          variables: [...variables, Variable<int>(limit)],
        )
        .get();

    return [
      for (final row in rows)
        TimelineRow(
          eventId: row.read<int>('id'),
          eventType: row.read<String>('event_type'),
          sourceLocator: row.read<String>('source_locator'),
          timestampNormalized: row.read<DateTime?>('timestamp_normalized'),
          textContent: row.read<String?>('text_content'),
        ),
    ];
  }

  Future<List<TimelineRow>> _selectPage({
    required (String, List<Variable<Object>>) where,
    required int limit,
    required int offset,
    bool unknownOrder = false,
  }) async {
    final (clause, variables) = where;
    final ordering = unknownOrder
        ? 'ORDER BY id ASC'
        : 'ORDER BY timestamp_normalized ASC, id ASC';
    final rows = await _database
        .customSelect(
          'SELECT id, event_type, source_locator, timestamp_normalized, '
          'text_content FROM events $clause $ordering LIMIT ? OFFSET ?',
          variables: [
            ...variables,
            Variable<int>(limit),
            Variable<int>(offset),
          ],
        )
        .get();

    return [
      for (final row in rows)
        TimelineRow(
          eventId: row.read<int>('id'),
          eventType: row.read<String>('event_type'),
          sourceLocator: row.read<String>('source_locator'),
          timestampNormalized: row.read<DateTime?>('timestamp_normalized'),
          textContent: row.read<String?>('text_content'),
        ),
    ];
  }

  (String, List<Variable<Object>>) _pageWhere({
    required List<String> conditions,
    required List<Variable<Object>> variables,
    String? eventType,
  }) {
    if (eventType != null) {
      conditions.add('event_type = ?');
      variables.add(Variable<String>(eventType));
    }
    return (
      conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}',
      variables,
    );
  }

  (String, List<Variable<Object>>) _filters({
    DateTime? from,
    DateTime? to,
    String? eventType,
  }) {
    final conditions = <String>[];
    final variables = <Variable<Object>>[];
    if (from != null) {
      conditions.add('timestamp_normalized >= ?');
      variables.add(Variable<DateTime>(from.toUtc()));
    }
    if (to != null) {
      conditions.add('timestamp_normalized <= ?');
      variables.add(Variable<DateTime>(to.toUtc()));
    }
    if (eventType != null) {
      conditions.add('event_type = ?');
      variables.add(Variable<String>(eventType));
    }
    return (
      conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}',
      variables,
    );
  }
}
