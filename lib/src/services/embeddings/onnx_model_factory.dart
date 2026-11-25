/// The model factory for the platform this build targets.
///
/// Native builds construct a real `OnnxEmbeddingModel`; the browser build gets
/// a stub that always returns null. UI code imports only this file, so
/// `package:onnxruntime` (and its `dart:ffi` imports) is never part of a web
/// compilation.
library;

export 'onnx_model_factory_stub.dart'
    if (dart.library.io) 'onnx_model_factory_native.dart';
