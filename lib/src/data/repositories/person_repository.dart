import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'event_type_filter.dart';

/// One person's provable numbers, all from their own message rows.
class PersonProfileRow {
  const PersonProfileRow({
    required this.id,
    required this.name,
    required this.platform,
    required this.platformPersonId,
    required this.messageCount,
    required this.photoCount,
    required this.firstAt,
    required this.lastAt,
    required this.days,
    required this.conversationId,
  });

  final int id;
  final String name;
  final String platform;

  /// The id the source platform exported for this person; null when absent.
  final String? platformPersonId;
  final int messageCount;
  final int photoCount;

  /// First and last dated message, the range the profile states.
  final DateTime? firstAt;
  final DateTime? lastAt;

  /// Distinct UTC days that carry one of their messages.
  final int days;

  /// The conversation most of their messages live in, when one exists.
  final int? conversationId;
}

/// One of the newest things this person said.
class PersonMessageRow {
  const PersonMessageRow({
    required this.id,
    required this.at,
    required this.text,
  });

  final int id;
  final DateTime? at;
  final String? text;
}

/// Reads one person's slice of the local archive for «ملف شخص».
///
/// `ponytail:` P6 needs a per-person profile, their yearly message buckets and
/// their newest lines; the existing aggregates rank people but never open one
/// person's rows. Each read is one statement filtered by `actor_id`, so the
/// profile can never show a number the person's own events do not reproduce.
class PersonRepository {
  const PersonRepository(this._database);

  final AppDatabase _database;

  /// The profile of [personId], or null when the person does not exist.
  Future<PersonProfileRow?> profile(int personId) async {
    final row = await _database
        .customSelect(
          'SELECT p.id, p.display_name, p.platform, p.platform_person_id, '
          'SUM(${messageEventSql('e.event_type')}) AS message_count, '
          'MIN(CASE WHEN ${messageEventSql('e.event_type')} '
          'THEN e.timestamp_normalized END) AS first_at, '
          'MAX(CASE WHEN ${messageEventSql('e.event_type')} '
          'THEN e.timestamp_normalized END) AS last_at, '
          'COUNT(DISTINCT CASE WHEN ${messageEventSql('e.event_type')} '
          'THEN strftime(\'%Y-%m-%d\', e.timestamp_normalized, \'unixepoch\') '
          'END) AS day_count, '
          '(SELECT COUNT(*) FROM attachments a '
          'JOIN events ae ON ae.id = a.event_id '
          'WHERE ae.actor_id = p.id AND a.media_type = \'image\') AS photo_count '
          'FROM people p LEFT JOIN events e ON e.actor_id = p.id '
          'WHERE p.id = ? GROUP BY p.id',
          variables: [Variable<int>(personId)],
        )
        .getSingleOrNull();
    if (row == null) return null;

    final conversation = await _database
        .customSelect(
          'SELECT conversation_id FROM events '
          'WHERE actor_id = ? AND ${messageEventSql('event_type')} '
          'AND conversation_id IS NOT NULL '
          'GROUP BY conversation_id '
          'ORDER BY COUNT(*) DESC, conversation_id ASC LIMIT 1',
          variables: [Variable<int>(personId)],
        )
        .getSingleOrNull();

    return PersonProfileRow(
      id: row.read<int>('id'),
      name: row.read<String>('display_name'),
      platform: row.read<String>('platform'),
      platformPersonId: row.read<String?>('platform_person_id'),
      messageCount: row.read<int?>('message_count') ?? 0,
      photoCount: row.read<int?>('photo_count') ?? 0,
      // Drift reads a stored instant as a local DateTime; the archive is
      // bucketed in UTC, so normalize at the edge.
      firstAt: row.read<DateTime?>('first_at')?.toUtc(),
      lastAt: row.read<DateTime?>('last_at')?.toUtc(),
      days: row.read<int?>('day_count') ?? 0,
      conversationId: conversation?.read<int?>('conversation_id'),
    );
  }

  /// Message counts per UTC year for [personId], ascending.
  Future<List<({int year, int count})>> messageYears(int personId) async {
    final rows = await _database
        .customSelect(
          "SELECT CAST(strftime('%Y', timestamp_normalized, 'unixepoch') "
          'AS INTEGER) AS bucket_year, COUNT(*) AS row_count '
          'FROM events WHERE actor_id = ? AND ${messageEventSql('event_type')} '
          'AND timestamp_normalized IS NOT NULL '
          'GROUP BY bucket_year ORDER BY bucket_year ASC',
          variables: [Variable<int>(personId)],
        )
        .get();
    return [
      for (final row in rows)
        (year: row.read<int>('bucket_year'), count: row.read<int>('row_count')),
    ];
  }

  /// How many of [personId]'s messages carry text, the paged list's total.
  ///
  /// Empty-bodied rows (attachments, shares) are excluded exactly like the
  /// page, so “loaded N of M” can never promise rows the page will skip.
  Future<int> textMessageCount(int personId) async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS message_count FROM events '
          'WHERE actor_id = ? AND ${messageEventSql('event_type')} '
          'AND text_content IS NOT NULL',
          variables: [Variable<int>(personId)],
        )
        .getSingle();
    return row.read<int>('message_count');
  }

  /// One newest-first page of [personId]'s text messages.
  ///
  /// Same ordering and filters as [recentMessages], so a page appended by the
  /// screen can never repeat or skip a row of the previous page.
  Future<List<PersonMessageRow>> messagePage(
    int personId, {
    required int limit,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }
    final rows = await _database
        .customSelect(
          'SELECT id, timestamp_normalized, text_content FROM events '
          'WHERE actor_id = ? AND ${messageEventSql('event_type')} '
          'AND text_content IS NOT NULL '
          'ORDER BY timestamp_normalized IS NULL ASC, '
          'timestamp_normalized DESC, id DESC LIMIT ? OFFSET ?',
          variables: [
            Variable<int>(personId),
            Variable<int>(limit),
            Variable<int>(offset),
          ],
        )
        .get();
    return [
      for (final row in rows)
        PersonMessageRow(
          id: row.read<int>('id'),
          at: row.read<DateTime?>('timestamp_normalized')?.toUtc(),
          text: row.read<String?>('text_content'),
        ),
    ];
  }

  /// The newest [limit] messages with text by [personId], newest first.
  Future<List<PersonMessageRow>> recentMessages(
    int personId, {
    int limit = 3,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final rows = await _database
        .customSelect(
          'SELECT id, timestamp_normalized, text_content FROM events '
          'WHERE actor_id = ? AND ${messageEventSql('event_type')} '
          'AND text_content IS NOT NULL '
          'ORDER BY timestamp_normalized IS NULL ASC, '
          'timestamp_normalized DESC, id DESC LIMIT ?',
          variables: [Variable<int>(personId), Variable<int>(limit)],
        )
        .get();
    return [
      for (final row in rows)
        PersonMessageRow(
          id: row.read<int>('id'),
          at: row.read<DateTime?>('timestamp_normalized')?.toUtc(),
          text: row.read<String?>('text_content'),
        ),
    ];
  }
}
