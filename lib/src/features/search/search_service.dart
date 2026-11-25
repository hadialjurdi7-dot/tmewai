import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/database/event_search_schema.dart';
import '../../data/repositories/event_search_repository.dart';
import '../../domain/models/event_search_hit.dart';
import '../../services/embeddings/embedding_model.dart';
import '../../services/embeddings/vector_search_service.dart';
import 'rank_fusion.dart';

/// One search result plus the record it came from.
///
/// Conversation and person names are read from the stored relations, never
/// inferred from the text, so a row can be traced back to its conversation and
/// participant. Either can be absent when the export did not record it.
class SearchResultRow {
  const SearchResultRow({
    required this.hit,
    this.conversationTitle,
    this.personName,
    this.personId,
  });

  final EventSearchHit hit;
  final String? conversationTitle;
  final String? personName;

  /// The stored person row behind [personName]; null when the export recorded
  /// no actor, in which case there is no profile to open.
  final int? personId;
}

/// Which retriever produced the page.
///
/// The UI shows this instead of calling every result “smart”: when no current
/// vector index exists the page is the same lexical result as before.
enum SearchMode { lexical, hybrid }

/// One page of results and the total number of matching records.
class SearchOutcome {
  const SearchOutcome({
    required this.rows,
    required this.totalHits,
    this.mode = SearchMode.lexical,
  });

  final List<SearchResultRow> rows;

  /// Matches across every page in lexical mode. In [SearchMode.hybrid] it is
  /// the size of the fused candidate set: the union of the two bounded
  /// retrieval windows. There is no calibrated global cosine cutoff yet, so
  /// claiming a corpus-wide semantic total would overstate what was checked.
  final int totalHits;

  final SearchMode mode;
}

/// Read model for the search screen: matches, provenance and a total count in
/// one query.
///
/// The match expression comes from [EventSearchRepository.buildMatchQuery], so
/// the screen and the shared repository fold and quote input identically. The
/// query is kept here instead of widening the repository's public API because
/// only this screen needs the joined conversation/person names and the window
/// count.
class SearchService {
  SearchService(this._database, {EmbeddingModel? embeddingModel})
    : _vectorSearch = embeddingModel == null
          ? null
          : VectorSearchService(_database, embeddingModel);

  final AppDatabase _database;

  /// Non-null only when the provider has a local model available.
  final VectorSearchService? _vectorSearch;

  /// Searches event text and source locators, ranked by relevance then date.
  ///
  /// [from] and [to] are inclusive normalized timestamps. [eventType] matches
  /// the stored type. [limit] caps the returned rows; [SearchOutcome.totalHits]
  /// is exact in lexical mode and the bounded candidate count in hybrid mode.
  ///
  /// Semantic search is never required for a search to succeed. If no current
  /// vector exists, or the vector sweep throws, this returns the untouched
  /// lexical result instead of failing the screen.
  Future<SearchOutcome> search(
    String query, {
    DateTime? from,
    DateTime? to,
    String? eventType,
    int limit = 50,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }

    final match = EventSearchRepository.buildMatchQuery(query);
    if (match == null) {
      return const SearchOutcome(rows: [], totalHits: 0);
    }

    final semantic = _vectorSearch;
    if (semantic != null) {
      try {
        if (await semantic.hasIndex()) {
          return await _hybridSearch(
            match: match,
            query: query,
            semantic: semantic,
            from: from,
            to: to,
            eventType: eventType,
            limit: limit,
          );
        }
      } on Object {
        // A damaged vector row, an unavailable runtime or an isolate failure
        // must never break a lexical search. Falling through is deliberate.
      }
    }

    return _lexicalSearch(
      match: match,
      from: from,
      to: to,
      eventType: eventType,
      limit: limit,
    );
  }

  /// The pre-existing lexical path, kept intact so a semantic-off database
  /// returns exactly the same rows, order and total as before.
  Future<SearchOutcome> _lexicalSearch({
    required String match,
    required DateTime? from,
    required DateTime? to,
    required String? eventType,
    required int limit,
  }) async {
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
      conditions.add('e.event_type = ?');
      variables.add(Variable<String>(eventType));
    }
    variables.add(Variable<int>(limit));

    // bm25 is only available in the FTS subquery: combining it directly with
    // the window count made SQLite reject the auxiliary function.
    final rows = await _database.customSelect('''
SELECT
  m.event_id,
  m.source_locator,
  m.platform,
  m.event_type,
  m.timestamp_normalized,
  m.text_content,
  c.title AS conversation_title,
  p.display_name AS person_name,
  m.actor_id AS person_id,
  m.relevance,
  COUNT(*) OVER () AS total_hits
FROM (
  SELECT
    e.id AS event_id,
    e.source_locator,
    e.platform,
    e.event_type,
    e.timestamp_normalized,
    e.text_content,
    e.conversation_id,
    e.actor_id,
    bm25($eventSearchTable) AS relevance
  FROM $eventSearchTable
  JOIN events AS e ON e.id = $eventSearchTable.event_id
  WHERE ${conditions.join(' AND ')}
) AS m
LEFT JOIN conversations AS c ON c.id = m.conversation_id
LEFT JOIN people AS p ON p.id = m.actor_id
ORDER BY
  m.relevance ASC,
  (m.timestamp_normalized IS NULL) ASC,
  m.timestamp_normalized DESC,
  m.event_id ASC
LIMIT ?
''', variables: variables).get();

    return SearchOutcome(
      totalHits: rows.isEmpty ? 0 : rows.first.read<int>('total_hits'),
      rows: [
        for (final row in rows)
          SearchResultRow(
            hit: EventSearchHit(
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
            conversationTitle: row.readNullable<String>('conversation_title'),
            personName: row.readNullable<String>('person_name'),
            personId: row.readNullable<int>('person_id'),
          ),
      ],
    );
  }

  /// Runs both retrievers and fuses them with RRF.
  ///
  /// Each retriever is asked for a wider window than the page so the page has
  /// enough alternatives after fusion. Keeping the windows bounded is what
  /// keeps `totalHits` deterministic; the doc on [SearchOutcome.totalHits]
  /// states the limit honestly.
  Future<SearchOutcome> _hybridSearch({
    required String match,
    required String query,
    required VectorSearchService semantic,
    required DateTime? from,
    required DateTime? to,
    required String? eventType,
    required int limit,
  }) async {
    final candidateLimit = limit * 4;
    final lexical = await _lexicalSearch(
      match: match,
      from: from,
      to: to,
      eventType: eventType,
      limit: candidateLimit,
    );
    final vectorHits = await semantic.search(
      query,
      from: from,
      to: to,
      eventType: eventType,
      limit: candidateLimit,
    );

    final timestamps = <int, DateTime?>{
      for (final row in lexical.rows)
        row.hit.eventId: row.hit.timestampNormalized,
      for (final hit in vectorHits) hit.eventId: hit.timestampNormalized,
    };
    final fused = fuseRankings([
      [for (final row in lexical.rows) row.hit.eventId],
      [for (final hit in vectorHits) hit.eventId],
    ], timestamps: timestamps);
    if (fused.isEmpty) {
      return const SearchOutcome(
        rows: [],
        totalHits: 0,
        mode: SearchMode.hybrid,
      );
    }

    final page = fused.take(limit).toList();
    final rowsById = await _loadRowsByIds([
      for (final rank in page) rank.eventId,
    ]);
    final rows = <SearchResultRow>[];
    for (final rank in page) {
      final row = rowsById[rank.eventId];
      if (row == null) continue;
      rows.add(
        SearchResultRow(
          hit: EventSearchHit(
            eventId: row.hit.eventId,
            sourceLocator: row.hit.sourceLocator,
            platform: row.hit.platform,
            eventType: row.hit.eventType,
            // The fused score is kept as ranking metadata. It is not on the
            // same scale as bm25, so no screen should print it as relevance.
            relevance: rank.score,
            timestampNormalized: row.hit.timestampNormalized,
            textContent: row.hit.textContent,
          ),
          conversationTitle: row.conversationTitle,
          personName: row.personName,
          personId: row.personId,
        ),
      );
    }

    return SearchOutcome(
      rows: rows,
      totalHits: fused.length,
      mode: SearchMode.hybrid,
    );
  }

  Future<Map<int, SearchResultRow>> _loadRowsByIds(List<int> eventIds) async {
    if (eventIds.isEmpty) return const {};
    final placeholders = List.filled(eventIds.length, '?').join(', ');
    final rows = await _database
        .customSelect(
          '''
SELECT e.id AS event_id, e.source_locator, e.platform, e.event_type,
  e.timestamp_normalized, e.text_content, e.actor_id AS person_id,
  c.title AS conversation_title, p.display_name AS person_name
FROM events AS e
LEFT JOIN conversations AS c ON c.id = e.conversation_id
LEFT JOIN people AS p ON p.id = e.actor_id
WHERE e.id IN ($placeholders)
''',
          variables: [for (final id in eventIds) Variable<int>(id)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<int>('event_id'): SearchResultRow(
          hit: EventSearchHit(
            eventId: row.read<int>('event_id'),
            sourceLocator: row.read<String>('source_locator'),
            platform: row.read<String>('platform'),
            eventType: row.read<String>('event_type'),
            relevance: 0,
            timestampNormalized: row
                .readNullable<DateTime>('timestamp_normalized')
                ?.toUtc(),
            textContent: row.readNullable<String>('text_content'),
          ),
          conversationTitle: row.readNullable<String>('conversation_title'),
          personName: row.readNullable<String>('person_name'),
          personId: row.readNullable<int>('person_id'),
        ),
    };
  }
}
