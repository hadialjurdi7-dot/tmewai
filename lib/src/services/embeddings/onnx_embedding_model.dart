import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';

import 'embedding_model.dart';
import 'onnx_backend_contract.dart';

/// The real local text-to-vector model: `Xenova/paraphrase-multilingual-MiniLM-L12-v2`,
/// int8 ONNX, 384 dimensions.
///
/// Everything here is local. The weights are downloaded only after the user
/// asks for them (see `ModelInstaller`) and inference never opens a socket.
///
/// The tokenizer is the file that ships with this exact model, loaded with the
/// SentencePiece Unigram loader. `dart_bert_tokenizer` cannot read it: that
/// package rejects `Precompiled` normalizers and only implements WordPiece,
/// while this tokenizer is SentencePiece Unigram with a precompiled charmap.
class OnnxEmbeddingModel extends EmbeddingModel {
  OnnxEmbeddingModel({required this.modelPath, required this.backend});

  /// Stable id for this exact file. A different quantization or export must use
  /// a different id, or old vectors would be compared against new query
  /// vectors.
  static const String productionModelId = 'minilm-multilingual-l12-q';

  /// `hidden_size` of the pinned model. Mean pooling returns this many floats.
  static const int embeddingDim = 384;

  /// `max_position_embeddings` of the pinned model. A longer sequence would be
  /// rejected by the runtime, so it is clipped before the run.
  static const int maxTokens = 512;

  /// Absolute path of the verified `model_quantized.onnx`.
  final String modelPath;

  final OnnxBackend backend;

  SentencePieceTokenizer? _tokenizer;

  @override
  String get modelId => productionModelId;

  @override
  int get dim => embeddingDim;

  /// The native session handle cannot cross an isolate boundary, so the
  /// indexer calls [embed] on the calling isolate. The expensive part (the
  /// session run) still happens off the UI thread inside the runtime's own
  /// worker, which is why `ponytail:` this is not a jank source.
  @override
  bool get isSendable => false;

  /// Embeds [texts] one at a time.
  ///
  /// A single session run could carry a padded `[batch, maxTokens]` tensor, but
  /// message lengths in this archive range from three tokens to the 512 cap:
  /// padding a 64-message batch to its longest member would multiply the work
  /// by up to twenty and produce identical vectors. One run per text keeps the
  /// tensors exact; the runtime's intra-op threads still use the CPU.
  @override
  Future<List<Float32List>> embed(List<String> texts) async {
    final tokenizer = await _ensureTokenizer();
    final vectors = <Float32List>[];
    for (final text in texts) {
      final ids = _tokenize(tokenizer, text);
      final mask = List<int>.filled(ids.length, 1);
      final types = List<int>.filled(ids.length, 0);
      final hidden = await backend.run(
        inputIds: ids,
        attentionMask: mask,
        tokenTypeIds: types,
      );
      if (hidden.dim != embeddingDim) {
        throw StateError(
          'The model returned ${hidden.dim}-dimensional hidden states, '
          'expected $embeddingDim.',
        );
      }
      vectors.add(
        meanPoolAndNormalize(
          hidden: hidden.values,
          tokens: hidden.tokens,
          dim: hidden.dim,
          attentionMask: mask,
        ),
      );
    }
    return vectors;
  }

  @override
  Future<void> close() => backend.close();

  Future<SentencePieceTokenizer> _ensureTokenizer() async {
    final existing = _tokenizer;
    if (existing != null) return existing;
    // Parsing the 17 MB tokenizer takes a moment and is done once per model
    // instance, on the caller's isolate. It is small next to the first
    // inference run and is never repeated for later batches.
    final raw = await backend.readTokenizerJson();
    final tokenizer = HuggingFaceTokenizerLoader.fromJsonString(raw);
    _tokenizer = tokenizer;
    return tokenizer;
  }

  /// Token ids for [text], clipped to the model's position limit.
  ///
  /// The tokenizer's own post-processor already wrapped the sequence in
  /// `<s>`/`</s>` (0 and 2), so no special token is added here. When clipping,
  /// the final token is kept: dropping `</s>` would leave the runtime without
  /// the end-of-sequence signal the model was trained with.
  static List<int> _tokenize(SentencePieceTokenizer tokenizer, String text) {
    final ids = tokenizer.encode(text).ids;
    if (ids.length <= maxTokens) return ids;
    return [...ids.take(maxTokens - 1), ids.last];
  }
}

/// Mean-pools [hidden] over [attentionMask] and L2-normalizes the result.
///
/// Mask-weighted mean, not CLS: this model was trained for sentence similarity
/// with mean pooling, and its CLS token is not a sentence embedding. Padding or
/// masked tokens contribute nothing because their weight is zero.
///
/// Returns a zero vector when every weight is zero, which only happens for a
/// degenerate input; a zero vector scores zero against everything instead of
/// producing NaN.
Float32List meanPoolAndNormalize({
  required Float32List hidden,
  required int tokens,
  required int dim,
  required List<int> attentionMask,
}) {
  if (tokens != attentionMask.length) {
    throw ArgumentError.value(
      attentionMask.length,
      'attentionMask',
      'must have one weight per token ($tokens)',
    );
  }
  if (hidden.length != tokens * dim) {
    throw ArgumentError.value(
      hidden.length,
      'hidden',
      'must hold $tokens * $dim values',
    );
  }

  final pooled = Float32List(dim);
  var weightSum = 0;
  for (var token = 0; token < tokens; token++) {
    final weight = attentionMask[token];
    if (weight == 0) continue;
    weightSum += weight;
    final offset = token * dim;
    for (var index = 0; index < dim; index++) {
      pooled[index] += hidden[offset + index] * weight;
    }
  }
  if (weightSum == 0) return pooled;
  final inverseWeight = 1.0 / weightSum;
  var normSquared = 0.0;
  for (var index = 0; index < dim; index++) {
    pooled[index] *= inverseWeight;
    normSquared += pooled[index] * pooled[index];
  }
  if (normSquared > 0) {
    final inverseNorm = 1.0 / math.sqrt(normSquared);
    for (var index = 0; index < dim; index++) {
      pooled[index] *= inverseNorm;
    }
  }
  return pooled;
}
