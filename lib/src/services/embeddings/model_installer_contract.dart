/// Platform-free contract of the model download/verify step.
///
/// The real installer (native) and the browser stub both implement
/// [SemanticModelInstaller] under the same names, behind a conditional import.
/// Keeping the data types here means the search screen can talk about the model
/// without importing `dart:io` and without making the web build worse.
library;

/// Where a downloaded file came from and what it must hash to.
class ModelFileSpec {
  const ModelFileSpec({
    required this.role,
    required this.name,
    required this.url,
    required this.bytes,
    required this.sha256,
  });

  /// Which of the two model files this spec describes.
  final ModelFileRole role;

  /// File name inside the model directory.
  final String name;

  /// `https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/<path>`
  final Uri url;

  /// Exact size in bytes. Checked before hashing so a truncated download is
  /// rejected without reading 118 MB twice.
  final int bytes;

  /// Lowercase hex sha256 of the pinned file.
  final String sha256;
}

enum ModelFileRole { model, tokenizer }

/// Directory name used for the pinned model. Changing the model must change
/// this, so old files are never mistaken for the new model.
const String semanticModelDirectoryName = 'minilm-multilingual-l12-q';

/// Resolve URL root of the pinned model repository.
const String semanticModelBaseUrl =
    'https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/'
    'resolve/main/';

/// The two files that must both verify before the model is usable.
///
/// The sizes and hashes were measured on the exact files this app was verified
/// against; a different quantization or repository revision will not match.
///
/// A `final` list rather than a `const` one: `Uri.parse` is a factory
/// constructor and cannot be evaluated in a constant expression.
final List<ModelFileSpec> productionModelSpecs = [
  ModelFileSpec(
    role: ModelFileRole.model,
    name: 'model_quantized.onnx',
    url: Uri.parse('${semanticModelBaseUrl}onnx/model_quantized.onnx'),
    bytes: 118308126,
    sha256:
        '66fc00f5f29afcaff34092e1bdd20008ca3918265a82fb9695a551e510cc4ebc',
  ),
  ModelFileSpec(
    role: ModelFileRole.tokenizer,
    name: 'tokenizer.json',
    url: Uri.parse('${semanticModelBaseUrl}tokenizer.json'),
    bytes: 17082913,
    sha256:
        'b60b6b43406a48bf3638526314f3d232d97058bc93472ff2de930d43686fa441',
  ),
];

/// Both verified model files, ready to load.
class ModelFiles {
  const ModelFiles({required this.modelPath, required this.tokenizerPath});

  final String modelPath;
  final String tokenizerPath;

  @override
  bool operator ==(Object other) =>
      other is ModelFiles &&
      other.modelPath == modelPath &&
      other.tokenizerPath == tokenizerPath;

  @override
  int get hashCode => Object.hash(modelPath, tokenizerPath);
}

/// Why an install attempt did not produce a usable model.
enum ModelInstallFailure {
  /// This platform cannot install the model (the browser build).
  unsupported,

  /// The download itself failed: no network, an HTTP error or a read error.
  network,

  /// The downloaded file is not the declared length.
  sizeMismatch,

  /// The downloaded file has the right length but the wrong sha256.
  hashMismatch,

  /// A local filesystem operation failed.
  io,
}

class ModelInstallResult {
  const ModelInstallResult._({
    required this.installed,
    this.downloaded = const [],
    this.failure,
  });

  /// The model is usable after this call.
  factory ModelInstallResult.installed({List<String> downloaded = const []}) =>
      ModelInstallResult._(installed: true, downloaded: downloaded);

  factory ModelInstallResult.failed(ModelInstallFailure failure) =>
      ModelInstallResult._(installed: false, failure: failure);

  final bool installed;

  /// File names fetched by this call; empty when everything was already there.
  final List<String> downloaded;

  final ModelInstallFailure? failure;

  /// True when every file was already present and verified, so nothing was
  /// downloaded.
  bool get wasAlreadyInstalled => installed && downloaded.isEmpty;
}

/// Bytes source for one file.
///
/// It writes to a path string rather than a `File` so the contract stays free
/// of `dart:io`; the native implementation is the only one that exists.
abstract class ModelDownloader {
  /// Downloads [url] to [destinationPath], overwriting it.
  ///
  /// [onProgress] receives bytes written and the declared content length, or
  /// zero when the server does not send one. A failure must throw; a partial
  /// destination file must be left for the installer to delete.
  Future<void> download(
    Uri url,
    String destinationPath, {
    void Function(int received, int total)? onProgress,
  });
}

/// Raised by a downloader or by verification; the installer turns it into a
/// [ModelInstallFailure] instead of letting it reach the UI.
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.failure, this.message);

  final ModelInstallFailure failure;
  final String message;

  @override
  String toString() => 'ModelDownloadException($failure): $message';
}

/// Installs and reports the local semantic model.
abstract class SemanticModelInstaller {
  /// False in the browser build, where there is no filesystem or native
  /// runtime to install into. The screen then shows no semantic controls.
  bool get isSupported;

  /// Human-readable location of the model directory.
  String get directoryLabel;

  /// Both files, only when they exist at the declared size and the install
  /// manifest records the pinned hashes. Null means "no semantic model".
  Future<ModelFiles?> verifiedFiles();

  /// Downloads and verifies whatever is missing. Safe to call repeatedly.
  Future<ModelInstallResult> install({
    void Function(String file, int received, int total)? onProgress,
  });
}

/// Total download size the consent/downgrade copy shows the user.
int get semanticModelDownloadBytes =>
    productionModelSpecs.fold(0, (sum, spec) => sum + spec.bytes);
