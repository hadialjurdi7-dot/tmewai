import 'package:drift/drift.dart';

import '../../domain/models/event_search_hit.dart';
import '../database/app_database.dart';
import '../database/event_search_schema.dart';
import '../database/search_text.dart';
import 'event_type_filter.dart';

/// Full-text search over imported events.
///
/// The query text is bound as an FTS5 string literal: user input is matched as
/// text and can never change the SQL statement that runs.
class EventSearchRepository {
  const EventSearchRepository(this._database);

  final AppDatabase _database;

  /// Adds a type filter to [conditions].
  ///
  /// `message` means every message kind: a message with an empty body is
  /// stored as `message_photo`, `message_link`, …, and a filter or drill-down
  /// that says "messages" must not hide it.
  void _addEventTypeFilter(
    List<String> conditions,
    List<Variable<Object>> variables,
    String eventType,
  ) {
    if (eventType == 'message') {
      conditions.add(messageEventSql('e.event_type'));
    } else {
      conditions.add('e.event_type = ?');
      variables.add(Variable<String>(eventType));
    }
  }

  /// Searches event text and source locators, ranked by FTS relevance and then
  /// by timestamp (most recent first).
  ///
  /// [from] and [to] filter on the normalized timestamp, [eventType] on the
  /// event type. Events without a normalized timestamp sort after dated ones.
  Future<List<EventSearchHit>> searchEvents(
    String query, {
    DateTime? from,
    DateTime? to,
    String? eventType,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }

    final match = buildMatchQuery(query);
    if (match == null) return const [];

    final conditions = <String>['$eventSearchTable MATCH ?'];
    final variables = <Variable<Object>>[Variable<String>(match)];

    if (from != null) {
      conditions.add('e.timestamp_normalized >= ?');
      variables.add(Variable<DateTime>(from.toUtc()));
    }
    if (to != null) {
      conditions.add('e.timestamp_normalized <= ?');
      variables.add(Variable<DateTime>(to.toUtc()));
    }
    if (eventType != null) {
      _addEventTypeFilter(conditions, variables, eventType);
    }

    variables
      ..add(Variable<int>(limit))
      ..add(Variable<int>(offset));

    final rows = await _database.customSelect('''
SELECT
  e.id AS event_id,
  e.source_locator,
  e.platform,
  e.event_type,
  e.timestamp_normalized,
  e.text_content,
  bm25($eventSearchTable) AS relevance
FROM $eventSearchTable
JOIN events AS e ON e.id = $eventSearchTable.event_id
WHERE ${conditions.join(' AND ')}
ORDER BY
  relevance ASC,
  (e.timestamp_normalized IS NULL) ASC,
  e.timestamp_normalized DESC,
  e.id ASC
LIMIT ? OFFSET ?
''', variables: variables).get();

    return [
      for (final row in rows)
        EventSearchHit(
          eventId: row.read<int>('event_id'),
          sourceLocator: row.read<String>('source_locator'),
          platform: row.read<String>('platform'),
          eventType: row.read<String>('event_type'),
          relevance: row.read<double>('relevance'),
          timestampNormalized: row
              .readNullable<DateTime>('timestamp_normalized')
              ?.toUtc(),
          textContent: row.readNullable<String>('text_content'),
        ),
    ];
  }

  /// Lists exactly the records matching a structural predicate, without a
  /// free-text query. Used by dashboard drill-downs so a card count and its
  /// record list share one filter definition.
  Future<List<EventSearchHit>> filterEvents({
    DateTime? from,
    DateTime? to,
    String? eventType,
    int? conversationId,
    int? actorId,
    int? sourceFileId,
    bool? hasTimestamp,
    int limit = 200,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final conditions = <String>[];
    final variables = <Variable<Object>>[];
    if (from != null) {
      conditions.add('e.timestamp_normalized >= ?');
      variables.add(Variable<DateTime>(from.toUtc()));
    }
    if (to != null) {
      conditions.add('e.timestamp_normalized <= ?');
      variables.add(Variable<DateTime>(to.toUtc()));
    }
    if (eventType != null) {
      _addEventTypeFilter(conditions, variables, eventType);
    }
    if (conversationId != null) {
      conditions.add('e.conversation_id = ?');
      variables.add(Variable<int>(conversationId));
    }
    if (actorId != null) {
      conditions.add('e.actor_id = ?');
      variables.add(Variable<int>(actorId));
    }
    if (sourceFileId != null) {
      conditions.add('e.source_file_id = ?');
      variables.add(Variable<int>(sourceFileId));
    }
    if (hasTimestamp != null) {
      conditions.add(
        hasTimestamp
            ? 'e.timestamp_normalized IS NOT NULL'
            : 'e.timestamp_normalized IS NULL',
      );
    }
    variables.add(Variable<int>(limit));

    final rows = await _database.customSelect('''
SELECT e.id AS event_id, e.source_locator, e.platform, e.event_type,
  e.timestamp_normalized, e.text_content, 0.0 AS relevance
FROM events AS e
${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
ORDER BY e.timestamp_normalized IS NULL ASC, e.timestamp_normalized ASC, e.id ASC
LIMIT ?
''', variables: variables).get();

    return [
      for (final row in rows)
        EventSearchHit(
          eventId: row.read<int>('event_id'),
          sourceLocator: row.read<String>('source_locator'),
          platform: row.read<String>('platform'),
          eventType: row.read<String>('event_type'),
          relevance: row.read<double>('relevance'),
          timestampNormalized: row
              .readNullable<DateTime>('timestamp_normalized')
              ?.toUtc(),
          textContent: row.readNullable<String>('text_content'),
        ),
    ];
  }

  /// The most common words in the local search index, highest first.
  ///
  /// `ponytail:` «أشهر 3 كلمات» on the story screen needs term frequencies,
  /// which only the FTS index already knows. `fts5vocab` is a read-only view
  /// over that index; the transient vocabulary table is created for the query
  /// and dropped in [finally], so the stored schema never changes.
  ///
  /// [documents] is the number of events containing the term and [occurrences]
  /// is the total number of times it appears. The ranking is by [occurrences]
  /// first: the story and analytics cards print occurrence counts and bar
  /// lengths, so ranking by document frequency let a word said once in two
  /// threads outrank a word said many times in one and contradict its own card.
  /// Terms shorter than two characters are skipped: single-letter particles
  /// would crowd the list without saying anything about the archive.
  Future<List<({String term, int documents, int occurrences})>> topTerms({
    int limit = 3,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    await _database.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS event_search_terms '
      "USING fts5vocab($eventSearchTable, 'col')",
    );
    try {
      final rows = await _database
          .customSelect(
            'SELECT term, doc, cnt FROM event_search_terms '
            "WHERE col = 'text_content' AND length(term) >= 2 "
            'ORDER BY cnt DESC, doc DESC, term ASC LIMIT ?',
            variables: [Variable<int>(limit)],
          )
          .get();
      return [
        for (final row in rows)
          (
            term: row.read<String>('term'),
            documents: row.read<int>('doc'),
            occurrences: row.read<int>('cnt'),
          ),
      ];
    } finally {
      await _database.customStatement(
        'DROP TABLE IF EXISTS event_search_terms',
      );
    }
  }

  /// Turns free text into an FTS5 match expression, or null when nothing
  /// searchable is left.
  ///
  /// Every token is quoted and inner quotes are doubled, so FTS5 operators in
  /// user input (`OR`, `*`, `NEAR`, `"`, `;`) are matched as literal text
  /// instead of being interpreted. Tokens are combined with an implicit AND.
  static String? buildMatchQuery(String query) {
    final tokens = <String>[];
    for (final part in normalizeSearchText(query).split(RegExp(r'\s+'))) {
      final token = part.replaceAll('"', '""');
      if (token.isEmpty) continue;
      tokens.add('"$token"');
    }
    if (tokens.isEmpty) return null;
    return tokens.join(' ');
  }
}
