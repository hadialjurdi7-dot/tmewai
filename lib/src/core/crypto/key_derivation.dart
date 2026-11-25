import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Derives an AES-256 key from a user passphrase using Argon2id.
///
/// Argon2id resists GPU and side-channel attacks far better than a plain
/// PBKDF2/SHA chain, which matters because the whole vault rests on a single
/// human-chosen passphrase.
class KeyDerivation {
  const KeyDerivation({
    this.memoryKib = 19456,
    this.iterations = 2,
    this.parallelism = 1,
    this.saltLength = 16,
  });

  /// Argon2id memory cost in KiB (OWASP baseline: 19 MiB).
  final int memoryKib;
  final int iterations;
  final int parallelism;
  final int saltLength;

  Argon2id get _argon2 => Argon2id(
        memory: memoryKib,
        iterations: iterations,
        parallelism: parallelism,
        hashLength: 32,
      );

  Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<SecretKey> derive(String passphrase, List<int> salt) {
    if (passphrase.isEmpty) {
      throw const VaultParameterException('passphrase_empty');
    }
    return _argon2.deriveKey(
      secretKey: SecretKeyData(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  /// Round-trips the derivation so a written vault header always reflects the
  /// exact parameters used to build the key.
  Map<String, Object> parameters() => {
        'kdf': 'argon2id',
        'memory_kib': memoryKib,
        'iterations': iterations,
        'parallelism': parallelism,
        'salt_length': saltLength,
      };

  static KeyDerivation fromParameters(Map<String, Object?> json) {
    return KeyDerivation(
      memoryKib: (json['memory_kib'] as num).toInt(),
      iterations: (json['iterations'] as num).toInt(),
      parallelism: (json['parallelism'] as num).toInt(),
      saltLength: (json['salt_length'] as num).toInt(),
    );
  }
}

/// A parameter or input the vault refuses to work with.
class VaultParameterException implements Exception {
  const VaultParameterException(this.code);
  final String code;

  @override
  String toString() => 'VaultParameterException($code)';
}
