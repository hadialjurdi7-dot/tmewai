import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'event_type_filter.dart';

/// Totals the home, story and analytics screens show for one period.
///
/// [photos] counts image attachment metadata rows; media bytes are never read.
/// [days] is the number of distinct UTC days that carry at least one dated
/// event, so it can never exceed the dated event count.
class ArchiveTotals {
  const ArchiveTotals({
    required this.messages,
    required this.photos,
    required this.people,
    required this.days,
    required this.events,
    this.first,
    this.last,
  });

  final int messages;
  final int photos;
  final int people;
  final int days;
  final int events;
  final DateTime? first;
  final DateTime? last;
}

/// Aggregate reads for the overview dashboard.
///
/// Every number is produced by one SQL statement over `events` (plus its
/// conversation, person or source file), so a card and its drill-down share
/// the same underlying rows.
class OverviewRepository {
  const OverviewRepository(this._database);

  final AppDatabase _database;

  Future<({DateTime? first, DateTime? last, int dated, int unknown})>
  activityPeriod() async {
    final row = await _database
        .customSelect(
          'SELECT MIN(timestamp_normalized) AS first_at, '
          'MAX(timestamp_normalized) AS last_at, '
          'SUM(timestamp_normalized IS NOT NULL) AS dated_count, '
          'SUM(timestamp_normalized IS NULL) AS unknown_count FROM events',
        )
        .getSingle();
    return (
      first: row.read<DateTime?>('first_at'),
      last: row.read<DateTime?>('last_at'),
      dated: row.read<int?>('dated_count') ?? 0,
      unknown: row.read<int?>('unknown_count') ?? 0,
    );
  }

  Future<List<({String key, int count})>> countsByDay() async {
    final rows = await _database
        .customSelect(
          "SELECT strftime('%Y-%m-%d', timestamp_normalized, 'unixepoch') "
          'AS bucket, COUNT(*) AS event_count FROM events '
          'WHERE timestamp_normalized IS NOT NULL '
          'GROUP BY bucket ORDER BY bucket ASC',
        )
        .get();
    return [
      for (final row in rows)
        (key: row.read<String>('bucket'), count: row.read<int>('event_count')),
    ];
  }

  /// Event counts per type, highest first. [year] restricts to one UTC year.
  Future<List<({String eventType, int count})>> countsByEventType({
    int? year,
  }) async {
    final (condition, variables) = _yearCondition('timestamp_normalized', year);
    final rows = await _database
        .customSelect(
          'SELECT event_type, COUNT(*) AS event_count FROM events $condition '
          'GROUP BY event_type ORDER BY event_count DESC, event_type ASC',
          variables: variables,
        )
        .get();
    return [
      for (final row in rows)
        (
          eventType: row.read<String>('event_type'),
          count: row.read<int>('event_count'),
        ),
    ];
  }

  /// Message count per conversation, highest first. [year] restricts to one
  /// UTC year.
  ///
  /// A period KPI that ignored the year would keep its archive-wide maximum
  /// while every other card on the screen narrowed with the filter.
  Future<List<({int id, String? title, String? sourceId, int count})>>
  topConversations({int limit = 5, int? year}) async {
    final (yearCondition, yearVariables) = _yearCondition(
      'e.timestamp_normalized',
      year,
      prefix: ' AND ',
    );
    final rows = await _database
        .customSelect(
          'SELECT c.id, c.title, c.source_conversation_id, '
          'COUNT(*) AS event_count FROM events e '
          'JOIN conversations c ON c.id = e.conversation_id '
          'WHERE ${messageEventSql('e.event_type')}$yearCondition '
          'GROUP BY c.id ORDER BY event_count DESC, c.id ASC LIMIT ?',
          variables: [...yearVariables, Variable<int>(limit)],
        )
        .get();
    return [
      for (final row in rows)
        (
          id: row.read<int>('id'),
          title: row.read<String?>('title'),
          sourceId: row.read<String?>('source_conversation_id'),
          count: row.read<int>('event_count'),
        ),
    ];
  }

  /// Message count per person, highest first. A person with no message event
  /// is not listed; [year] restricts to one UTC year.
  Future<List<({int id, String name, int count})>> topPeople({
    int limit = 5,
    int? year,
  }) async {
    final (yearCondition, yearVariables) = _yearCondition(
      'e.timestamp_normalized',
      year,
      prefix: ' AND ',
    );
    final rows = await _database
        .customSelect(
          'SELECT p.id, p.display_name, COUNT(*) AS event_count '
          'FROM events e JOIN people p ON p.id = e.actor_id '
          'WHERE ${messageEventSql('e.event_type')}$yearCondition '
          'GROUP BY p.id ORDER BY event_count DESC, p.id ASC LIMIT ?',
          variables: [...yearVariables, Variable<int>(limit)],
        )
        .get();
    return [
      for (final row in rows)
        (
          id: row.read<int>('id'),
          name: row.read<String>('display_name'),
          count: row.read<int>('event_count'),
        ),
    ];
  }

  /// Message counts per UTC year, ascending.
  Future<List<({int year, int count})>> countsByYear({
    String? eventType = 'message',
  }) async {
    // A null [eventType] counts every dated event, which is what a year filter
    // needs: otherwise a year that holds only posts or reactions disappears
    // from the choices while the charts below it still include those rows.
    // `message` is the exception: it means every message kind, including the
    // typed payloads a photo-only or link-only message is stored as.
    final String filter;
    final List<Variable<String>> variables;
    if (eventType == null) {
      filter = '';
      variables = const [];
    } else if (eventType == 'message') {
      filter = 'AND ${messageEventSql('event_type')} ';
      variables = const [];
    } else {
      filter = 'AND event_type = ? ';
      variables = [Variable<String>(eventType)];
    }
    final rows = await _database
        .customSelect(
          "SELECT CAST(strftime('%Y', timestamp_normalized, 'unixepoch') "
          'AS INTEGER) AS bucket_year, COUNT(*) AS event_count '
          'FROM events WHERE timestamp_normalized IS NOT NULL '
          '$filter'
          'GROUP BY bucket_year ORDER BY bucket_year ASC',
          variables: variables,
        )
        .get();
    return [
      for (final row in rows)
        (
          year: row.read<int>('bucket_year'),
          count: row.read<int>('event_count'),
        ),
    ];
  }

  /// Message counts per UTC month (1..12) for [year], or all years when null.
  Future<List<({int month, int count})>> countsByMonth({
    String eventType = 'message',
    int? year,
  }) async {
    final (condition, variables) = _yearCondition(
      'timestamp_normalized',
      year,
      prefix: ' AND ',
    );
    // `message` covers every message kind; any other value is one exact type.
    final typeFilter = eventType == 'message'
        ? messageEventSql('event_type')
        : 'event_type = ?';
    final rows = await _database
        .customSelect(
          "SELECT CAST(strftime('%m', timestamp_normalized, 'unixepoch') "
          'AS INTEGER) AS bucket_month, COUNT(*) AS event_count '
          'FROM events WHERE timestamp_normalized IS NOT NULL '
          'AND $typeFilter$condition '
          'GROUP BY bucket_month ORDER BY bucket_month ASC',
          variables: [
            if (eventType != 'message') Variable<String>(eventType),
            ...variables,
          ],
        )
        .get();
    return [
      for (final row in rows)
        (
          month: row.read<int>('bucket_month'),
          count: row.read<int>('event_count'),
        ),
    ];
  }

  /// Message counts per UTC hour (0..23) for [year], or all years when null.
  Future<List<({int hour, int count})>> countsByHour({
    String eventType = 'message',
    int? year,
  }) async {
    final (condition, variables) = _yearCondition(
      'timestamp_normalized',
      year,
      prefix: ' AND ',
    );
    final typeFilter = eventType == 'message'
        ? messageEventSql('event_type')
        : 'event_type = ?';
    final rows = await _database
        .customSelect(
          "SELECT CAST(strftime('%H', timestamp_normalized, 'unixepoch') "
          'AS INTEGER) AS bucket_hour, COUNT(*) AS event_count '
          'FROM events WHERE timestamp_normalized IS NOT NULL '
          'AND $typeFilter$condition '
          'GROUP BY bucket_hour ORDER BY bucket_hour ASC',
          variables: [
            if (eventType != 'message') Variable<String>(eventType),
            ...variables,
          ],
        )
        .get();
    return [
      for (final row in rows)
        (
          hour: row.read<int>('bucket_hour'),
          count: row.read<int>('event_count'),
        ),
    ];
  }

  /// Archive totals for [year], or for the whole archive when null.
  ///
  /// `ponytail:` the home, story and analytics screens need these totals and
  /// period buckets; the dashboard never did. One statement per total keeps
  /// each number traceable to the same `events` rows it describes.
  Future<ArchiveTotals> archiveTotals({int? year}) async {
    final (condition, variables) = _yearCondition(
      'timestamp_normalized',
      year,
      prefix: ' AND ',
    );
    final eventFilter = year == null
        ? ''
        : ' WHERE timestamp_normalized IS NOT NULL$condition';
    final rows = await _database
        .customSelect(
          'SELECT COUNT(*) AS event_count, '
          'SUM(${messageEventSql('event_type')}) AS message_count, '
          'COUNT(DISTINCT actor_id) AS people_count, '
          "COUNT(DISTINCT strftime('%Y-%m-%d', timestamp_normalized, "
          "'unixepoch')) AS day_count, "
          'MIN(timestamp_normalized) AS first_at, '
          'MAX(timestamp_normalized) AS last_at '
          'FROM events$eventFilter',
          variables: variables,
        )
        .getSingle();

    // The importer stores `image` from its media-field/extension mapping;
    // restricting the query to that persisted type keeps the photo KPI
    // traceable to image rows. Attachments without an event cannot be dated,
    // so a year total includes only images carried by dated events.
    final photoRow = year == null
        ? await _database
              .customSelect(
                "SELECT COUNT(*) AS photo_count FROM attachments "
                "WHERE media_type = 'image'",
              )
              .getSingle()
        : await _database
              .customSelect(
                'SELECT COUNT(*) AS photo_count FROM attachments a '
                'JOIN events e ON e.id = a.event_id '
                "WHERE a.media_type = 'image' AND "
                "strftime('%Y', e.timestamp_normalized, 'unixepoch') = ?",
                variables: [Variable<String>(year.toString())],
              )
              .getSingle();

    return ArchiveTotals(
      messages: rows.read<int?>('message_count') ?? 0,
      photos: photoRow.read<int>('photo_count'),
      people: rows.read<int?>('people_count') ?? 0,
      days: rows.read<int?>('day_count') ?? 0,
      events: rows.read<int>('event_count'),
      first: rows.read<DateTime?>('first_at'),
      last: rows.read<DateTime?>('last_at'),
    );
  }

  /// SQL fragment for an optional UTC-year filter on [column].
  (String, List<Variable<Object>>) _yearCondition(
    String column,
    int? year, {
    String prefix = 'WHERE ',
  }) {
    if (year == null) return ('', const []);
    return (
      "$prefix strftime('%Y', $column, 'unixepoch') = ?",
      [Variable<String>(year.toString())],
    );
  }

  Future<List<({int id, String path, int count})>> countsBySourceFile({
    int limit = 5,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT s.id, s.relative_path, COUNT(*) AS event_count '
          'FROM events e JOIN source_files s ON s.id = e.source_file_id '
          'GROUP BY s.id ORDER BY event_count DESC, s.id ASC LIMIT ?',
          variables: [Variable<int>(limit)],
        )
        .get();
    return [
      for (final row in rows)
        (
          id: row.read<int>('id'),
          path: row.read<String>('relative_path'),
          count: row.read<int>('event_count'),
        ),
    ];
  }
}
