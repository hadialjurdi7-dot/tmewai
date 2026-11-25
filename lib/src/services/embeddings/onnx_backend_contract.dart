import 'dart:typed_data';

/// Hidden states of one sequence, as returned by one ONNX session run.
///
/// The backend returns a flat row-major buffer instead of nested lists: the
/// pooling step below reads it once, and a `[tokens][384]` list of lists for a
/// 512-token message would allocate 512 small objects for nothing.
class OnnxTokenHiddenStates {
  const OnnxTokenHiddenStates({
    required this.tokens,
    required this.dim,
    required this.values,
  });

  /// Number of tokens in the run sequence.
  final int tokens;

  /// Model hidden size, 384 for the pinned MiniLM.
  final int dim;

  /// `tokens * dim` floats, token-major, not pooled and not normalized.
  final Float32List values;
}

/// The native inference boundary.
///
/// It lives behind a conditional import so no web-reachable library ever
/// imports `dart:ffi`. The browser build gets a stub that reports "no model",
/// which is the same state as a model that was never downloaded.
///
/// Reading the tokenizer file is part of the boundary on purpose: the model
/// class stays free of `dart:io` so the search screen (which the web build also
/// compiles) can import it.
abstract class OnnxBackend {
  /// Contents of the verified `tokenizer.json`.
  Future<String> readTokenizerJson();

  /// Runs the model for one tokenized sequence.
  ///
  /// The three inputs are the model's declared int64 inputs, each of length
  /// `inputIds.length`. Returning token-major hidden states keeps pooling in
  /// plain Dart, where it can be tested without ONNX.
  Future<OnnxTokenHiddenStates> run({
    required List<int> inputIds,
    required List<int> attentionMask,
    required List<int> tokenTypeIds,
  });

  /// Releases the native session and environment.
  Future<void> close();
}
