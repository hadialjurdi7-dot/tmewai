import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'key_derivation.dart';

/// Result of opening a vault: the plaintext payload plus its authenticated
/// manifest (file names, sizes and SHA-256 hashes recorded at seal time).
class VaultContents {
  const VaultContents({required this.payload, required this.manifest});

  final Uint8List payload;
  final Map<String, Object?> manifest;
}

/// Why a vault could not be opened. Codes are safe to show and log: they never
/// contain the passphrase, the payload or any path.
class VaultError implements Exception {
  const VaultError(this.code);
  final String code;

  static const wrongPassphrase = 'vault_wrong_passphrase';
  static const tampered = 'vault_tampered';
  static const unsupportedVersion = 'vault_unsupported_version';
  static const notAVault = 'vault_not_a_vault';
  static const truncated = 'vault_truncated';
  static const badParameters = 'vault_bad_parameters';

  @override
  String toString() => 'VaultError($code)';
}

/// Seals a payload into a self-describing, authenticated container.
///
/// Layout:
/// ```
/// magic "TMEWIA1\n" | headerLen u32le | header JSON | macLen u16le | mac | ciphertext
/// ```
/// The header carries the Argon2id parameters, salt and nonce. The header bytes
/// are passed as AEAD associated data, so editing any parameter invalidates the
/// authentication tag instead of silently re-deriving a different key.
class VaultContainer {
  const VaultContainer({this.derivation = const KeyDerivation()});

  static const magic = 'TMEWIA1\n';
  static const version = 1;

  /// Guards against a hostile header asking for absurd work.
  static const minMemoryKib = 8192;
  static const maxMemoryKib = 512 * 1024;

  final KeyDerivation derivation;

  AesGcm get _aead => AesGcm.with256bits();

  Future<Uint8List> seal({
    required String passphrase,
    required Uint8List payload,
    Map<String, Object?> manifest = const {},
  }) async {
    final salt = derivation.newSalt();
    final key = await derivation.derive(passphrase, salt);
    final nonce = _aead.newNonce();
    final header = <String, Object?>{
      'version': version,
      ...derivation.parameters(),
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
    };
    final headerBytes = utf8.encode(jsonEncode(header));
    // The manifest names files, so it is sealed with the payload instead of
    // sitting in the clear header. Only KDF parameters, salt and nonce stay
    // readable, and those are authenticated as associated data.
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    final plain = BytesBuilder()
      ..add(_u32(manifestBytes.length))
      ..add(manifestBytes)
      ..add(payload);
    final box = await _aead.encrypt(
      plain.toBytes(),
      secretKey: key,
      nonce: nonce,
      aad: headerBytes,
    );
    return _assemble(headerBytes, box.mac.bytes, box.cipherText);
  }

  Future<VaultContents> open({
    required String passphrase,
    required Uint8List container,
  }) async {
    final parsed = _parse(container);
    final params = KeyDerivation.fromParameters(parsed.header);
    if (params.memoryKib < minMemoryKib || params.memoryKib > maxMemoryKib) {
      throw const VaultError(VaultError.badParameters);
    }
    final salt = base64Decode(parsed.header['salt']! as String);
    if (salt.length != params.saltLength) {
      throw const VaultError(VaultError.badParameters);
    }
    final nonce = base64Decode(parsed.header['nonce']! as String);
    final key = await params.derive(passphrase, salt);

    final List<int> plain;
    try {
      plain = await _aead.decrypt(
        SecretBox(parsed.cipherText, nonce: nonce, mac: Mac(parsed.mac)),
        secretKey: key,
        aad: parsed.headerBytes,
      );
    } on SecretBoxAuthenticationError {
      // A wrong passphrase and an edited payload are indistinguishable by
      // design: both break the tag, and telling them apart would leak whether
      // the passphrase was right.
      throw const VaultError(VaultError.tampered);
    }

    if (plain.length < 4) {
      throw const VaultError(VaultError.tampered);
    }
    final decodedPayload = Uint8List.fromList(plain);
    final manifestLen = _readU32(decodedPayload, 0);
    if (manifestLen < 0 || 4 + manifestLen > decodedPayload.length) {
      throw const VaultError(VaultError.tampered);
    }
    final Object? decodedManifest;
    try {
      decodedManifest = jsonDecode(
        utf8.decode(decodedPayload.sublist(4, 4 + manifestLen)),
      );
    } on FormatException {
      throw const VaultError(VaultError.tampered);
    }
    return VaultContents(
      payload: decodedPayload.sublist(4 + manifestLen),
      manifest:
          decodedManifest is Map<String, Object?> ? decodedManifest : const {},
    );
  }

  /// Cheap, passphrase-free facts about a vault: everything except the KDF
  /// parameters is encrypted, so only its size is knowable from outside.
  Map<String, Object> describe(Uint8List container) {
    final parsed = _parse(container);
    return {
      'version': version,
      'container_bytes': container.length,
      'ciphertext_bytes': parsed.cipherText.length,
      'encrypted_metadata': true,
    };
  }

  Uint8List _assemble(
    List<int> headerBytes,
    List<int> mac,
    List<int> cipherText,
  ) {
    final out = BytesBuilder();
    out.add(ascii.encode(magic));
    out.add(_u32(headerBytes.length));
    out.add(headerBytes);
    out.add(_u16(mac.length));
    out.add(mac);
    out.add(cipherText);
    return out.toBytes();
  }

  _ParsedVault _parse(Uint8List bytes) {
    if (bytes.length < magic.length + 4) {
      throw const VaultError(VaultError.notAVault);
    }
    final magicBytes = ascii.encode(magic);
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw const VaultError(VaultError.notAVault);
      }
    }
    var offset = magicBytes.length;
    final headerLen = _readU32(bytes, offset);
    offset += 4;
    if (headerLen <= 0 || offset + headerLen + 2 > bytes.length) {
      throw const VaultError(VaultError.truncated);
    }
    final headerBytes = bytes.sublist(offset, offset + headerLen);
    offset += headerLen;

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(headerBytes));
    } on FormatException {
      throw const VaultError(VaultError.notAVault);
    }
    if (decoded is! Map<String, Object?>) {
      throw const VaultError(VaultError.notAVault);
    }
    if (decoded['version'] != version) {
      throw const VaultError(VaultError.unsupportedVersion);
    }

    final macLen = (bytes[offset] | (bytes[offset + 1] << 8));
    offset += 2;
    if (macLen <= 0 || offset + macLen > bytes.length) {
      throw const VaultError(VaultError.truncated);
    }
    final mac = bytes.sublist(offset, offset + macLen);
    offset += macLen;

    return _ParsedVault(
      header: decoded,
      headerBytes: headerBytes,
      mac: mac,
      cipherText: bytes.sublist(offset),
    );
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

  static Uint8List _u16(int value) => Uint8List(2)
    ..[0] = value & 0xff
    ..[1] = (value >> 8) & 0xff;
}

class _ParsedVault {
  const _ParsedVault({
    required this.header,
    required this.headerBytes,
    required this.mac,
    required this.cipherText,
  });

  final Map<String, Object?> header;
  final List<int> headerBytes;
  final List<int> mac;
  final List<int> cipherText;
}
