import 'model_installer_contract.dart';
import 'onnx_embedding_model.dart';

/// The browser build has no ONNX Runtime.
///
/// Returning null is not an error state: the app simply has no semantic index,
/// which is exactly the behaviour before this feature existed. Keeping the same
/// signature behind the conditional import is what stops `dart:ffi` from being
/// reachable by the web build.
OnnxEmbeddingModel? createOnnxEmbeddingModel(ModelFiles files) => null;
