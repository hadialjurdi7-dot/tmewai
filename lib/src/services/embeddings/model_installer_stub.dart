import 'model_installer_contract.dart';

/// Browser build counterpart of the native installer.
///
/// The web build has no filesystem and no native runtime, so the honest answer
/// is "this platform cannot install the model". It still implements the same
/// contract and factory so the search screen compiles unchanged, and the app
/// keeps its lexical search exactly as before.
class ModelInstaller implements SemanticModelInstaller {
  ModelInstaller({
    required String rootPath,
    ModelDownloader? downloader,
    List<ModelFileSpec>? specs,
    String manifestName = 'install.json',
  });

  @override
  bool get isSupported => false;

  @override
  String get directoryLabel => '';

  @override
  Future<ModelFiles?> verifiedFiles() async => null;

  @override
  Future<ModelInstallResult> install({
    void Function(String file, int received, int total)? onProgress,
  }) async => ModelInstallResult.failed(ModelInstallFailure.unsupported);
}

/// No model can be installed in the browser build.
Future<SemanticModelInstaller> createDefaultModelInstaller() async =>
    ModelInstaller(rootPath: '');
