import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../../core/crypto/vault_container.dart';

/// One workspace file recovered from a vault.
class VaultEntry {
  const VaultEntry({
    required this.relativePath,
    required this.bytes,
    required this.sha256,
  });

  final String relativePath;
  final Uint8List bytes;
  final String sha256;
}

/// Seals a workspace directory into a single authenticated `.tmewia` file and
/// restores it back.
///
/// The whole file set is sealed as one AEAD message, so the vault size is
/// bounded by available RAM. That ceiling is deliberate until large media
/// archives are actually imported; a chunked streaming format can follow.
class VaultService {
  const VaultService({this.container = const VaultContainer()});

  final VaultContainer container;

  static const fileExtension = '.tmewia';
  static const manifestKey = 'entries';

  /// Seals every regular file under [workspaceDir] (symlinks are skipped, never
  /// followed) and writes the container to [targetFile].
  Future<Uint8List> sealDirectory({
    required Directory workspaceDir,
    required String passphrase,
    required File targetFile,
  }) async {
    final entries = <Map<String, Object?>>[];
    final payload = BytesBuilder();

    final rootPath = workspaceDir.absolute.path;
    final files = workspaceDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final filePath = file.absolute.path;
      if (!filePath.startsWith('$rootPath${Platform.pathSeparator}')) {
        throw const VaultError(VaultError.tampered);
      }
      // Vault manifests store portable paths: a vault sealed on Windows must
      // restore the same folder tree on Linux and macOS, so the native
      // separator is normalised to '/' before it is written to the manifest.
      final relative = _portablePath(filePath.substring(rootPath.length + 1));
      entries.add({
        'path': relative,
        'size': bytes.length,
        'sha256': crypto.sha256.convert(bytes).toString(),
      });
      payload.add(_u32(bytes.length));
      payload.add(bytes);
    }

    final manifest = <String, Object?>{
      manifestKey: entries,
      'file_count': entries.length,
      'total_bytes': entries.fold<int>(
        0,
        (sum, entry) => sum + (entry['size']! as int),
      ),
      'format': 'tmewia-vault-v1',
    };

    final sealed = await container.seal(
      passphrase: passphrase,
      payload: payload.toBytes(),
      manifest: manifest,
    );
    targetFile.parent.createSync(recursive: true);
    targetFile.writeAsBytesSync(sealed);
    return sealed;
  }

  /// Opens a vault and writes its files under [targetDir].
  ///
  /// Nothing is written until the container authenticates, so a wrong
  /// passphrase or a tampered file leaves the destination untouched.
  Future<List<VaultEntry>> extractTo({
    required File vaultFile,
    required String passphrase,
    required Directory targetDir,
  }) async {
    final contents = await container.open(
      passphrase: passphrase,
      container: vaultFile.readAsBytesSync(),
    );
    final chunks = _splitPayload(contents.payload);
    final declared = contents.manifest[manifestKey];
    if (declared is! List || declared.length != chunks.length) {
      throw const VaultError(VaultError.tampered);
    }

    final entries = <VaultEntry>[];
    for (var i = 0; i < chunks.length; i++) {
      final meta = declared[i];
      if (meta is! Map) {
        throw const VaultError(VaultError.tampered);
      }
      final path = meta['path'];
      final expectedHash = meta['sha256'];
      if (path is! String || expectedHash is! String) {
        throw const VaultError(VaultError.tampered);
      }
      final actualHash = crypto.sha256.convert(chunks[i]).toString();
      if (actualHash != expectedHash) {
        throw const VaultError(VaultError.tampered);
      }
      if (!_isSafeRelativePath(path)) {
        throw const VaultError(VaultError.tampered);
      }
      entries.add(
        VaultEntry(relativePath: path, bytes: chunks[i], sha256: actualHash),
      );
    }

    targetDir.createSync(recursive: true);
    for (final entry in entries) {
      final target = File('${targetDir.path}/${entry.relativePath}');
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(entry.bytes);
    }
    return entries;
  }

  /// Passphrase-free facts about a vault. Metadata is encrypted, so this
  /// exposes sizes only, never file names.
  Map<String, Object> describe(File vaultFile) =>
      container.describe(vaultFile.readAsBytesSync());

  List<Uint8List> _splitPayload(Uint8List payload) {
    final chunks = <Uint8List>[];
    var offset = 0;
    while (offset < payload.length) {
      if (offset + 4 > payload.length) {
        throw const VaultError(VaultError.tampered);
      }
      final length = _readU32(payload, offset);
      offset += 4;
      if (length < 0 || offset + length > payload.length) {
        throw const VaultError(VaultError.tampered);
      }
      chunks.add(payload.sublist(offset, offset + length));
      offset += length;
    }
    return chunks;
  }

  /// Manifest paths always use '/' regardless of the sealing platform, so a
  /// Windows-sealed vault restores as nested folders everywhere.
  static String _portablePath(String path) => Platform.isWindows
      ? path.replaceAll(Platform.pathSeparator, '/')
      : path;

  /// A restored path must stay inside the destination: no absolute paths, no
  /// `..` segments, no NUL bytes, no Windows drive letters.
  static bool _isSafeRelativePath(String path) {
    if (path.isEmpty || path.contains('\u0000')) {
      return false;
    }
    if (path.startsWith('/') || path.startsWith('\\')) {
      return false;
    }
    if (path.length > 1 && path[1] == ':') {
      return false;
    }
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.every((segment) => segment != '..' && segment.isNotEmpty);
  }

  static int _readU32(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  static Uint8List _u32(int value) => Uint8List(4)
    ..[0] = value & 0xff
    ..[1] = (value >> 8) & 0xff
    ..[2] = (value >> 16) & 0xff
    ..[3] = (value >> 24) & 0xff;
}
