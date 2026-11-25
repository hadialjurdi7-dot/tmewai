import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/database/app_database.dart';
import 'embedding_model.dart';
import 'embedding_vector.dart';

/// One vector-search result before row details are loaded.
class VectorSearchHit {
  const VectorSearchHit({
    required this.eventId,
    required this.score,
    this.timestampNormalized,
  });

  final int eventId;
  final double score;
  final DateTime? timestampNormalized;
}

/// Brute-force cosine search over the vectors stored for one model.
///
/// `ponytail:` vectors live in SQLite as BLOBs and are swept in a Dart isolate.
/// That keeps one portable SQLite build for Windows, Linux, macOS, Android and
/// iOS instead of requiring the sqlite-vec loadable extension, which
/// `package:sqlite3` 3.8.0 no longer exposes. At the measured archive size
/// (139k events × 384 float32 ≈ 213 MB) one dot-product sweep is under a
/// second. The practical ceiling is around 1M rows; past it, switch to
/// sqlite-vec or an ANN index once a custom SQLite build exists, without
/// changing the embedding table or this service's public API.
///
/// Filters are applied in SQL before any blob is read. Without them the sweep
/// would load the whole archive just to discard most of it in Dart.
class VectorSearchService {
  const VectorSearchService(this._database, this._model);

  final AppDatabase _database;
  final EmbeddingModel _model;

  /// True when at least one current-model vector exists.
  ///
  /// Search uses this before embedding the query: without an index the fake or
  /// real model is never loaded for a lexical search.
  Future<bool> hasIndex() async {
    final rows = await _database
        .customSelect(
          '''
SELECT 1 AS present
FROM event_embeddings
WHERE model_id = ? AND dim = ?
LIMIT 1
''',
          variables: [
            Variable<String>(_model.modelId),
            Variable<int>(_model.dim),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Returns the [limit] closest events, highest cosine first.
  ///
  /// [from], [to] and [eventType] use the same meaning as `SearchService.search`.
  /// Malformed blobs are skipped rather than making an otherwise healthy index
  /// unusable; the indexer always writes the current dimension, so a bad row
  /// means a damaged file, not a normal state.
  Future<List<VectorSearchHit>> search(
    String query, {
    DateTime? from,
    DateTime? to,
    String? eventType,
    int limit = 50,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (query.trim().isEmpty) return const [];
    if (!await hasIndex()) return const [];

    final conditions = <String>[
      'ee.model_id = ?',
      'ee.dim = ?',
      'length(ee.vector) = ?',
    ];
    final variables = <Variable<Object>>[
      Variable<String>(_model.modelId),
      Variable<int>(_model.dim),
      Variable<int>(_model.dim * 4),
    ];
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

    final rows = await _database.customSelect('''
SELECT ee.event_id AS event_id, ee.vector AS vector,
  e.timestamp_normalized AS timestamp_normalized
FROM event_embeddings AS ee
JOIN events AS e ON e.id = ee.event_id
WHERE ${conditions.join(' AND ')}
''', variables: variables).get();
    if (rows.isEmpty) return const [];

    final eventIds = <int>[];
    final vectors = <Uint8List>[];
    final timestamps = <DateTime?>[];
    for (final row in rows) {
      eventIds.add(row.read<int>('event_id'));
      vectors.add(row.read<Uint8List>('vector'));
      timestamps.add(
        row.readNullable<DateTime>('timestamp_normalized')?.toUtc(),
      );
    }

    final model = _model;
    final queryVectors = await _embedQuery(model, query);
    if (queryVectors.isEmpty || queryVectors.single.length != model.dim) {
      throw StateError(
        'Embedding model returned an invalid query vector for a '
        '${model.dim}-dimensional index.',
      );
    }

    return _inBackground(
      () => _cosineTop(
        eventIds: eventIds,
        vectors: vectors,
        timestamps: timestamps,
        query: queryVectors.single,
        dim: model.dim,
        limit: limit,
      ),
    );
  }

  /// Embeds the query off the UI isolate when the model instance can be sent.
  ///
  /// A native runtime owns a session handle that cannot cross an isolate
  /// boundary; it runs its own inference off-thread, so it is called in place.
  static Future<List<Float32List>> _embedQuery(
    EmbeddingModel model,
    String query,
  ) {
    if (kIsWeb || !model.isSendable) return model.embed([query]);
    return _inBackground(() => model.embed([query]));
  }
}

/// Runs CPU work off the UI thread where the platform allows it.
///
/// The browser has no isolate support, so it runs inline like the importer's
/// archive scan does; the native builds keep the UI responsive.
Future<T> _inBackground<T>(FutureOr<T> Function() work) =>
    kIsWeb ? Future<T>.value(work()) : Isolate.run(work);

/// The part that must run off the UI isolate: decoding every candidate blob and
/// computing cosine similarity. It captures only plain collections, never the
/// database or the service instance.
List<VectorSearchHit> _cosineTop({
  required List<int> eventIds,
  required List<Uint8List> vectors,
  required List<DateTime?> timestamps,
  required Float32List query,
  required int dim,
  required int limit,
}) {
  var queryNormSquared = 0.0;
  for (final value in query) {
    queryNormSquared += value * value;
  }
  final queryNorm = math.sqrt(queryNormSquared);
  if (queryNorm == 0) return const [];

  final hits = <VectorSearchHit>[];
  for (var index = 0; index < eventIds.length; index++) {
    final bytes = vectors[index];
    if (bytes.length != dim * 4) continue;
    final vector = decodeFloat32Vector(bytes, dim: dim);
    var dot = 0.0;
    var vectorNormSquared = 0.0;
    for (var offset = 0; offset < dim; offset++) {
      dot += query[offset] * vector[offset];
      vectorNormSquared += vector[offset] * vector[offset];
    }
    final vectorNorm = math.sqrt(vectorNormSquared);
    final score = vectorNorm == 0 ? 0.0 : dot / (queryNorm * vectorNorm);
    hits.add(
      VectorSearchHit(
        eventId: eventIds[index],
        score: score,
        timestampNormalized: timestamps[index],
      ),
    );
  }

  hits.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.eventId.compareTo(b.eventId);
  });
  if (hits.length > limit) hits.removeRange(limit, hits.length);
  return hits;
}
