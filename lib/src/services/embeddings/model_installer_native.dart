import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_installer_contract.dart';

/// Installs the pinned model into the app support directory.
///
/// Two rules drive this class:
///
/// 1. A file is used only after its exact size and sha256 match the pinned
///    values. A truncated or corrupted download is deleted, never renamed into
///    place, so a half-finished download can never be treated as a model.
/// 2. An installed model is not downloaded again. A second call is a no-op,
///    because 135 MB of background traffic on every app start would be a
///    privacy and bandwidth bug.
///
/// After both files verify, a small manifest records their sizes and hashes.
/// Startup reads that manifest instead of re-hashing 135 MB; the hashes are
/// enforced at write time and again whenever a file has to be (re)installed.
class ModelInstaller implements SemanticModelInstaller {
  ModelInstaller({
    required String rootPath,
    ModelDownloader? downloader,
    List<ModelFileSpec>? specs,
    this.manifestName = 'install.json',
  }) : _root = Directory(rootPath),
       _downloader = downloader ?? HttpModelDownloader(),
       _specs = specs ?? productionModelSpecs;

  final Directory _root;
  final ModelDownloader _downloader;
  final List<ModelFileSpec> _specs;
  final String manifestName;

  /// `<root>/minilm-multilingual-l12-q/`
  Directory get directory =>
      Directory(p.join(_root.path, semanticModelDirectoryName));

  @override
  bool get isSupported => true;

  @override
  String get directoryLabel => directory.path;

  @override
  Future<ModelFiles?> verifiedFiles() async {
    final manifest = await _readManifest();
    if (manifest == null) return null;
    final paths = <ModelFileRole, String>{};
    for (final spec in _specs) {
      final path = _pathFor(spec);
      final file = File(path);
      if (!await file.exists()) return null;
      // A file that changed size since it was verified is not the verified
      // file; refusing it costs one stat and avoids trusting a swapped model.
      if (await file.length() != spec.bytes) return null;
      final recorded = manifest[spec.name];
      if (recorded == null ||
          recorded['bytes'] != spec.bytes ||
          recorded['sha256'] != spec.sha256) {
        return null;
      }
      paths[spec.role] = path;
    }
    final modelPath = paths[ModelFileRole.model];
    final tokenizerPath = paths[ModelFileRole.tokenizer];
    if (modelPath == null || tokenizerPath == null) return null;
    return ModelFiles(modelPath: modelPath, tokenizerPath: tokenizerPath);
  }

  @override
  Future<ModelInstallResult> install({
    void Function(String file, int received, int total)? onProgress,
  }) async {
    try {
      if (await verifiedFiles() != null) {
        return ModelInstallResult.installed();
      }
      await directory.create(recursive: true);
      final downloaded = <String>[];
      for (final spec in _specs) {
        final target = File(_pathFor(spec));
        if (await _isAlreadyValid(spec, target)) continue;
        await _downloadAndVerify(spec, target, onProgress);
        downloaded.add(spec.name);
      }
      await _writeManifest();
      return ModelInstallResult.installed(downloaded: downloaded);
    } on ModelDownloadException catch (error) {
      return ModelInstallResult.failed(error.failure);
    } on Object {
      return ModelInstallResult.failed(ModelInstallFailure.io);
    }
  }

  /// True when [target] already holds exactly the pinned bytes.
  ///
  /// A file that fails either check is deleted here: leaving a corrupt model on
  /// disk would let a later read trust a size that happens to match.
  Future<bool> _isAlreadyValid(ModelFileSpec spec, File target) async {
    if (!await target.exists()) return false;
    if (await target.length() != spec.bytes ||
        await _sha256Of(target) != spec.sha256) {
      await _deleteIfPresent(target);
      return false;
    }
    return true;
  }

  Future<void> _downloadAndVerify(
    ModelFileSpec spec,
    File target,
    void Function(String file, int received, int total)? onProgress,
  ) async {
    // A partial file from an earlier attempt is never resumed or trusted: it
    // may belong to the other revision of the same URL.
    final partial = File('${target.path}.part');
    await _deleteIfPresent(partial);
    await _downloader.download(
      spec.url,
      partial.path,
      onProgress: (received, total) =>
          onProgress?.call(spec.name, received, total),
    );
    if (!await partial.exists() || await partial.length() != spec.bytes) {
      await _deleteIfPresent(partial);
      throw ModelDownloadException(
        ModelInstallFailure.sizeMismatch,
        '${spec.name} did not match its ${spec.bytes}-byte size',
      );
    }
    if (await _sha256Of(partial) != spec.sha256) {
      await _deleteIfPresent(partial);
      await _deleteIfPresent(target);
      throw ModelDownloadException(
        ModelInstallFailure.hashMismatch,
        '${spec.name} did not match its pinned sha256',
      );
    }
    // Rename only after verification, so the final path never holds a file
    // that was not checked.
    await _deleteIfPresent(target);
    await partial.rename(target.path);
  }

  Future<String> _sha256Of(File file) async =>
      (await sha256.bind(file.openRead()).single).toString();

  Future<Map<String, Map<String, Object?>>?> _readManifest() async {
    final file = File(p.join(directory.path, manifestName));
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['model'] != semanticModelDirectoryName) {
        return null;
      }
      final files = decoded['files'];
      if (files is! Map) return null;
      final result = <String, Map<String, Object?>>{};
      for (final entry in files.entries) {
        final value = entry.value;
        if (value is! Map) return null;
        result['${entry.key}'] = {
          'bytes': value['bytes'],
          'sha256': value['sha256'],
        };
      }
      return result;
    } on Object {
      // A damaged manifest means "not installed", not a crash: the model can
      // be installed again from the settings/search action.
      return null;
    }
  }

  Future<void> _writeManifest() async {
    final manifest = {
      'model': semanticModelDirectoryName,
      'files': {
        for (final spec in _specs)
          spec.name: {'bytes': spec.bytes, 'sha256': spec.sha256},
      },
    };
    final target = File(p.join(directory.path, manifestName));
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(manifest), flush: true);
    await _deleteIfPresent(target);
    await temporary.rename(target.path);
  }

  String _pathFor(ModelFileSpec spec) => p.join(directory.path, spec.name);

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

/// Downloads one file over HTTP(S) with Dart's own client.
///
/// No retry loop: the user asked once, and a failed attempt must leave the app
/// on lexical search rather than retrying behind their back.
class HttpModelDownloader implements ModelDownloader {
  HttpModelDownloader({this.connectTimeout = const Duration(seconds: 20)});

  final Duration connectTimeout;

  @override
  Future<void> download(
    Uri url,
    String destinationPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = connectTimeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw ModelDownloadException(
          ModelInstallFailure.network,
          'HTTP ${response.statusCode} for ${url.path}',
        );
      }
      final total = response.contentLength > 0 ? response.contentLength : 0;
      sink = File(destinationPath).openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } on ModelDownloadException {
      rethrow;
    } on Object catch (error) {
      throw ModelDownloadException(
        ModelInstallFailure.network,
        'download failed: $error',
      );
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }
}

/// The model location the app uses: `<application support>/models/`.
Future<SemanticModelInstaller> createDefaultModelInstaller() async {
  final support = await getApplicationSupportDirectory();
  return ModelInstaller(rootPath: p.join(support.path, 'models'));
}
