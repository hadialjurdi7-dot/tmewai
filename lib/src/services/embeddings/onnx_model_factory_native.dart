import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'model_installer_contract.dart';
import 'onnx_backend_contract.dart';
import 'onnx_embedding_model.dart';

/// Builds the real model from verified files, or null when this platform has
/// no ONNX runtime.
///
/// Creating the model does not touch the native library: the session is opened
/// on the first inference. That keeps app start (and a search screen rebuild)
/// cheap, and means a broken install cannot crash anything until a real embed
/// is requested — where the caller already degrades to lexical search.
OnnxEmbeddingModel? createOnnxEmbeddingModel(ModelFiles files) {
  return OnnxEmbeddingModel(
    modelPath: files.modelPath,
    backend: _OrtBackend(files.modelPath, files.tokenizerPath),
  );
}

/// ONNX Runtime environment, created once per isolate.
///
/// `OrtEnv` is a process-wide singleton inside the package; creating a second
/// environment for a second model object would leak the first one.
bool _environmentReady = false;

class _OrtBackend implements OnnxBackend {
  _OrtBackend(this._modelPath, this._tokenizerPath);

  final String _modelPath;
  final String _tokenizerPath;

  OrtSession? _session;
  bool _closed = false;

  /// Runs are serialized: the package shares one output channel per session,
  /// so two overlapping `runAsync` calls would mix their results.
  Future<void> _queue = Future<void>.value();

  @override
  Future<String> readTokenizerJson() => File(_tokenizerPath).readAsString();

  @override
  Future<OnnxTokenHiddenStates> run({
    required List<int> inputIds,
    required List<int> attentionMask,
    required List<int> tokenTypeIds,
  }) async {
    final previous = _queue;
    final gate = Completer<void>();
    _queue = gate.future;
    await previous;
    try {
      return await _run(
        inputIds: inputIds,
        attentionMask: attentionMask,
        tokenTypeIds: tokenTypeIds,
      );
    } finally {
      gate.complete();
    }
  }

  Future<OnnxTokenHiddenStates> _run({
    required List<int> inputIds,
    required List<int> attentionMask,
    required List<int> tokenTypeIds,
  }) async {
    if (_closed) throw StateError('The ONNX model has been closed.');
    final session = await _ensureSession();

    final ids = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(inputIds),
      [1, inputIds.length],
    );
    final mask = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(attentionMask),
      [1, attentionMask.length],
    );
    final types = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(tokenTypeIds),
      [1, tokenTypeIds.length],
    );
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(runOptions, {
        'input_ids': ids,
        'attention_mask': mask,
        'token_type_ids': types,
      }, ['last_hidden_state']);
      final produced = outputs;
      final output = produced == null || produced.isEmpty
          ? null
          : produced.first;
      if (output is! OrtValueTensor) {
        throw StateError('The model did not return a hidden-state tensor.');
      }
      final value = output.value;
      if (value is! List || value.isEmpty || value.first is! List) {
        throw StateError('The hidden-state tensor has an unexpected shape.');
      }
      final sequence = value.first as List;
      final tokens = sequence.length;
      if (tokens != inputIds.length) {
        throw StateError(
          'The model returned $tokens hidden states for '
          '${inputIds.length} tokens.',
        );
      }
      final firstRow = sequence.first;
      if (firstRow is! List) {
        throw StateError('The hidden-state tensor has no token dimension.');
      }
      final dim = firstRow.length;
      final flat = Float32List(tokens * dim);
      var offset = 0;
      for (final row in sequence) {
        if (row is! List || row.length != dim) {
          throw StateError('The hidden-state tensor is not rectangular.');
        }
        for (final value in row) {
          flat[offset++] = (value as num).toDouble();
        }
      }
      return OnnxTokenHiddenStates(tokens: tokens, dim: dim, values: flat);
    } finally {
      ids.release();
      mask.release();
      types.release();
      runOptions.release();
      if (outputs != null) {
        for (final output in outputs) {
          output?.release();
        }
      }
    }
  }

  Future<OrtSession> _ensureSession() async {
    final existing = _session;
    if (existing != null) return existing;
    if (!_environmentReady) {
      OrtEnv.instance.init();
      _environmentReady = true;
    }
    final options = OrtSessionOptions();
    try {
      final session = OrtSession.fromFile(File(_modelPath), options);
      _session = session;
      return session;
    } finally {
      options.release();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _queue;
    } on Object {
      // A failed run does not keep the session usable; releasing is still right.
    }
    _session?.release();
    _session = null;
  }
}
