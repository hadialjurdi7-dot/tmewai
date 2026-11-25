import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/database/app_database.dart';
import 'embedding_consent.dart';
import 'embedding_model.dart';
import 'embedding_vector.dart';

/// How much of the embeddable archive currently has a vector for [modelId].
///
/// [total] counts events with non-empty text, which is exactly the set the
/// indexer can embed. [indexed] counts current-model rows only, so vectors left
/// by an older model do not make the UI claim the index is complete.
class EmbeddingIndexStatus {
  const EmbeddingIndexStatus({
    required this.indexed,
    required this.total,
    this.available = true,
  });

  const EmbeddingIndexStatus.unavailable()
    : indexed = 0,
      total = 0,
      available = false;

  final int indexed;
  final int total;
  final bool available;

  bool get hasText => total > 0;

  /// Any semantic ranking can run.
  bool get hasIndex => indexed > 0;

  /// Some rows are embedded, but newer events still need a vector. This is the
  /// only state the search screen reports, because an empty or complete index
  /// needs no explanation.
  bool get isPartial => indexed > 0 && indexed < total;

  bool get isComplete => total > 0 && indexed >= total;
}

/// Completed / total rows for one indexing run.
class EmbeddingIndexProgress {
  const EmbeddingIndexProgress({required this.done, required this.total});

  final int done;
  final int total;

  bool get isComplete => done >= total;
}

/// Fills [event_embeddings] for one model, in batches.
///
/// Indexing reads archive text, so it is gated on a stored consent row: without
/// one, [indexPending] throws instead of embedding anything. The import path
/// only starts an index run when that row already exists and never awaits it,
/// so an unavailable model can never make an import fail or block its result.
class EmbeddingIndexer {
  EmbeddingIndexer(this._database, this._model, {EmbeddingConsent? consent})
    : consent = consent ?? EmbeddingConsent(_database);

  final AppDatabase _database;
  final EmbeddingModel _model;

  /// The approval that must exist before any text is embedded.
  final EmbeddingConsent consent;

  final StreamController<EmbeddingIndexProgress> _progress =
      StreamController<EmbeddingIndexProgress>.broadcast();

  /// The run currently in flight, if any.
  ///
  /// The search action and the after-import action can fire close together;
  /// sharing the run keeps them from embedding the same rows twice and from
  /// reporting two interleaved progress streams.
  Future<int>? _running;

  /// Rows done / total of the current run.
  Stream<EmbeddingIndexProgress> get progress => _progress.stream;

  /// Embeds every event that has no current-model vector yet.
  ///
  /// Batches keep the isolate message and transaction bounded. A batch is
  /// embedded first and then written in one transaction, so an interrupted run
  /// loses at most the batch that was in flight; everything already committed
  /// stays.
  ///
  /// The text sent to the model is `events.text_content` only. Conversation
  /// titles are deliberately not prepended: a title would give every message
  /// in a thread the same context and make unrelated replies look similar.
  /// Search folds are not applied either; the model's tokenizer already handles
  /// Arabic spelling variants, and folding here would destroy information the
  /// model was trained on.
  Future<int> indexPending({int batch = 64}) {
    if (batch <= 0) {
      throw ArgumentError.value(batch, 'batch', 'must be positive');
    }
    return _running ??= _indexPending(
      batch: batch,
    ).whenComplete(() => _running = null);
  }

  Future<int> _indexPending({required int batch}) async {
    // Refuse before reading a single row: the consent row is the user's
    // approval to turn archive text into vectors.
    if (!await consent.isGranted()) {
      throw const EmbeddingConsentRequired();
    }

    final status = await this.status();
    final pending = status.total - status.indexed;
    var done = 0;
    _progress.add(EmbeddingIndexProgress(done: done, total: pending));
    if (pending <= 0) return 0;

    while (true) {
      final rows = await _database
          .customSelect(
            '''
SELECT e.id AS event_id, e.text_content AS text_content
FROM events AS e
LEFT JOIN event_embeddings AS ee
  ON ee.event_id = e.id AND ee.model_id = ? AND ee.dim = ?
WHERE ee.event_id IS NULL
  AND e.text_content IS NOT NULL
  AND length(trim(e.text_content)) > 0
ORDER BY e.id ASC
LIMIT ?
''',
            variables: [
              Variable<String>(_model.modelId),
              Variable<int>(_model.dim),
              Variable<int>(batch),
            ],
          )
          .get();
      if (rows.isEmpty) break;

      final eventIds = <int>[];
      final texts = <String>[];
      for (final row in rows) {
        final text = row.read<String>('text_content');
        if (text.trim().isEmpty) continue;
        eventIds.add(row.read<int>('event_id'));
        texts.add(text);
      }
      if (texts.isEmpty) break;

      final vectors = await _embedInIsolate(texts);
      if (vectors.length != texts.length) {
        throw StateError(
          'Embedding model returned ${vectors.length} vectors for '
          '${texts.length} texts.',
        );
      }
      final encoded = <Uint8List>[];
      for (final vector in vectors) {
        if (vector.length != _model.dim) {
          throw StateError(
            'Embedding model returned a ${vector.length}-dimensional vector, '
            'expected ${_model.dim}.',
          );
        }
        encoded.add(encodeFloat32Vector(vector));
      }

      await _database.transaction(() async {
        for (var index = 0; index < eventIds.length; index++) {
          await _database
              .into(_database.eventEmbeddings)
              .insertOnConflictUpdate(
                EventEmbeddingsCompanion.insert(
                  eventId: Value(eventIds[index]),
                  modelId: _model.modelId,
                  dim: _model.dim,
                  vector: encoded[index],
                ),
              );
        }
      });

      done += eventIds.length;
      _progress.add(EmbeddingIndexProgress(done: done, total: pending));
    }

    return done;
  }

  /// Removes vectors from any model other than the current one.
  ///
  /// The primary key allows only one vector per event, so this is mainly for
  /// databases written by an older model build. Returning the count lets the
  /// caller report real work instead of guessing.
  Future<int> pruneStale() {
    return (_database.delete(
      _database.eventEmbeddings,
    )..where((row) => row.modelId.isNotValue(_model.modelId))).go();
  }

  /// Current index coverage for this model.
  Future<EmbeddingIndexStatus> status() async {
    final totalRows = await _database.customSelect('''
SELECT COUNT(*) AS n
FROM events AS e
WHERE e.text_content IS NOT NULL AND length(trim(e.text_content)) > 0
''').getSingle();
    final indexedRows = await _database
        .customSelect(
          '''
SELECT COUNT(*) AS n
FROM event_embeddings AS ee
JOIN events AS e ON e.id = ee.event_id
WHERE ee.model_id = ? AND ee.dim = ?
  AND e.text_content IS NOT NULL AND length(trim(e.text_content)) > 0
''',
          variables: [
            Variable<String>(_model.modelId),
            Variable<int>(_model.dim),
          ],
        )
        .getSingle();
    return EmbeddingIndexStatus(
      indexed: indexedRows.read<int>('n'),
      total: totalRows.read<int>('n'),
    );
  }

  /// Runs the model off the UI isolate when the implementation allows it.
  ///
  /// The model object itself is the message payload here, so a runtime whose
  /// instance holds a native session handle cannot be sent. [EmbeddingModel]
  /// reports that with `isSendable`; such a model runs its own inference off
  /// the UI thread and is called in place.
  Future<List<Float32List>> _embedInIsolate(List<String> texts) {
    final model = _model;
    // The browser has no isolate support; the same batch runs inline there,
    // where the archive is already bounded by the web picker's limits.
    if (kIsWeb || !model.isSendable) return model.embed(texts);
    return Isolate.run(() => model.embed(texts));
  }

  Future<void> dispose() => _progress.close();
}
