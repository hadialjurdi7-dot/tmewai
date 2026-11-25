import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/database/search_text.dart';

/// The local text-to-vector contract.
///
/// Nothing in this interface opens a network connection. A provider-backed
/// embedding service would violate the app's local-first rule, so the contract
/// is deliberately small: a stable model id, a fixed dimensionality and a
/// synchronous list in, list out batch operation.
abstract class EmbeddingModel {
  /// Const so the test double can stay a const value.
  const EmbeddingModel();

  /// Stable identifier stored with every vector. Changing the model or its
  /// quantization must change this id, otherwise old vectors are compared with
  /// a new model's query vectors and the scores are meaningless.
  String get modelId;

  /// Number of float32 values in each returned vector.
  int get dim;

  /// Embeds [texts] in the same order. Implementations must return exactly one
  /// vector per input.
  Future<List<Float32List>> embed(List<String> texts);

  /// Whether an instance may be sent to `Isolate.run` as a message.
  ///
  /// The phase-1 double is a value object and can be sent; a native runtime
  /// holds an ONNX session handle that cannot cross an isolate boundary, and it
  /// already runs its inference off the UI thread. Callers must check this
  /// before wrapping [embed] in an isolate.
  bool get isSendable => true;

  /// Releases any native resources. The default has nothing to release.
  Future<void> close() async {}
}

/// Deterministic test double for the embedding pipeline.
///
/// It hashes normalized tokens into [dim] buckets and L2-normalizes the result.
/// That makes repeated calls reproducible and gives identical texts identical
/// vectors, which is all a pipeline test needs. It carries no meaning: two
/// semantically related Arabic words do not land near each other. Real search
/// quality is the job of the ONNX model described in the task notes; this class
/// exists so indexing, storage, ranking and UI can be tested without it.
class HashMapEmbedder extends EmbeddingModel {
  const HashMapEmbedder();

  /// Id reserved for the phase-1 double. It intentionally differs from the
  /// production `minilm-multilingual-l12-q` id so fake vectors can never be
  /// mistaken for real model output.
  static const String fakeModelId = 'hashmap-debug-v1';

  static const int embeddingDim = 384;

  @override
  String get modelId => fakeModelId;

  @override
  int get dim => embeddingDim;

  @override
  Future<List<Float32List>> embed(List<String> texts) async => [
    for (final text in texts) _embedOne(text),
  ];

  Float32List _embedOne(String text) {
    final vector = Float32List(embeddingDim);
    // The lexical folds make spelling variants of one word hash together,
    // which keeps this double stable across common Arabic keyboard spellings.
    final folded = normalizeSearchText(text).toLowerCase();
    for (final token in folded.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final bucket = _fnv1a(token) % embeddingDim;
      final sign = _fnv1a('sign:$token').isEven ? 1.0 : -1.0;
      vector[bucket] += sign;
    }
    var normSquared = 0.0;
    for (final value in vector) {
      normSquared += value * value;
    }
    if (normSquared > 0) {
      final inverseNorm = 1.0 / math.sqrt(normSquared);
      for (var index = 0; index < vector.length; index++) {
        vector[index] *= inverseNorm;
      }
    }
    return vector;
  }

  /// FNV-1a over UTF-16 code units. `String.hashCode` is not promised to stay
  /// stable across runs or platforms; a persisted fake index needs a hash that
  /// does.
  static int _fnv1a(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
