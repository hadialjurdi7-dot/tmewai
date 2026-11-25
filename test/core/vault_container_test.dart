import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/crypto/key_derivation.dart';
import 'package:personal_data_agent/src/core/crypto/vault_container.dart';
import 'package:personal_data_agent/src/services/vault/vault_service.dart';

void main() {
  group('VaultContainer', () {
    // Fast parameters keep the unit suite quick; production defaults live in
    // KeyDerivation and are asserted separately.
    const fast = KeyDerivation(memoryKib: 8192, iterations: 1, parallelism: 1);
    const container = VaultContainer(derivation: fast);

    test('round-trips a payload and keeps the manifest readable', () async {
      final payload = Uint8List.fromList(utf8.encode('رسالة خاصة 12345'));
      final sealed = await container.seal(
        passphrase: 'correct horse battery staple',
        payload: payload,
        manifest: const {'file_count': 1},
      );

      final opened = await container.open(
        passphrase: 'correct horse battery staple',
        container: sealed,
      );

      expect(opened.payload, equals(payload));
      expect(opened.manifest['file_count'], 1);
      expect(container.describe(sealed)['encrypted_metadata'], isTrue);
    });

    test('a wrong passphrase never yields plaintext', () async {
      final sealed = await container.seal(
        passphrase: 'right-passphrase',
        payload: Uint8List.fromList(utf8.encode('top secret')),
      );

      await expectLater(
        container.open(passphrase: 'wrong-passphrase', container: sealed),
        throwsA(
          isA<VaultError>()
              .having((e) => e.code, 'code', VaultError.tampered),
        ),
      );
    });

    test('flipping a ciphertext byte is detected', () async {
      final sealed = await container.seal(
        passphrase: 'passphrase-1',
        payload: Uint8List.fromList(utf8.encode('payload content')),
      );
      final tampered = Uint8List.fromList(sealed);
      tampered[tampered.length - 1] ^= 0x01;

      await expectLater(
        container.open(passphrase: 'passphrase-1', container: tampered),
        throwsA(
          isA<VaultError>()
              .having((e) => e.code, 'code', VaultError.tampered),
        ),
      );
    });

    test('the sealed container does not contain the plaintext', () async {
      const secret = 'MySecretMessageText42';
      final sealed = await container.seal(
        passphrase: 'passphrase-2',
        payload: Uint8List.fromList(utf8.encode(secret)),
      );

      expect(utf8.decode(sealed, allowMalformed: true).contains(secret),
          isFalse);
    });

    test('foreign bytes are rejected as not-a-vault', () async {
      final junk = Uint8List.fromList(utf8.encode('this is not a vault'));
      await expectLater(
        container.open(passphrase: 'x', container: junk),
        throwsA(
          isA<VaultError>()
              .having((e) => e.code, 'code', VaultError.notAVault),
        ),
      );
    });

    test('an empty passphrase is refused before any work', () async {
      await expectLater(
        container.seal(passphrase: '', payload: Uint8List(0)),
        throwsA(isA<VaultParameterException>()),
      );
    });

    test('a hostile memory cost in the header is refused', () async {
      // Build a container with production parameters, then rewrite the header
      // memory cost to an absurd value. Because the header is authenticated,
      // the parameter guard fires before key derivation.
      final sealed = await container.seal(
        passphrase: 'passphrase-3',
        payload: Uint8List.fromList(utf8.encode('data')),
      );
      final headerLen = sealed[8] |
          (sealed[9] << 8) |
          (sealed[10] << 16) |
          (sealed[11] << 24);
      final headerJson = utf8.decode(sealed.sublist(12, 12 + headerLen));
      final rewritten = headerJson.replaceFirst('"memory_kib":8192',
          '"memory_kib":999999999');
      expect(rewritten, isNot(headerJson));

      final newHeader = utf8.encode(rewritten);
      final rebuilt = BytesBuilder()
        ..add(sealed.sublist(0, 8))
        ..add(_u32(newHeader.length))
        ..add(newHeader)
        ..add(sealed.sublist(12 + headerLen));
      final hostile = rebuilt.toBytes();

      await expectLater(
        container.open(passphrase: 'passphrase-3', container: hostile),
        throwsA(
          isA<VaultError>()
              .having((e) => e.code, 'code', VaultError.badParameters),
        ),
      );
    });
  });

  group('VaultService', () {
    const fast = KeyDerivation(memoryKib: 8192, iterations: 1, parallelism: 1);
    const service = VaultService(container: VaultContainer(derivation: fast));

    late Directory workspace;
    late Directory restore;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('tmewia-vault-src');
      restore = Directory.systemTemp.createTempSync('tmewia-vault-dst');
      Directory('${workspace.path}/nested').createSync(recursive: true);
      File('${workspace.path}/workspace.sqlite')
          .writeAsBytesSync(Uint8List.fromList(List<int>.generate(64, (i) => i)));
      File('${workspace.path}/nested/notes.txt')
          .writeAsStringSync('ملاحظات محلية');
    });

    tearDown(() {
      for (final dir in [workspace, restore]) {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
    });

    test('seals a directory and restores identical bytes', () async {
      final vault = File('${restore.path}/backup.tmewia');
      await service.sealDirectory(
        workspaceDir: workspace,
        passphrase: 'vault-pass',
        targetFile: vault,
      );
      expect(vault.existsSync(), isTrue);
      expect(vault.lengthSync(), greaterThan(0));

      final outDir = Directory('${restore.path}/out');
      final entries = await service.extractTo(
        vaultFile: vault,
        passphrase: 'vault-pass',
        targetDir: outDir,
      );

      expect(entries.map((e) => e.relativePath).toSet(),
          {'workspace.sqlite', 'nested/notes.txt'});
      expect(
        File('${outDir.path}/nested/notes.txt').readAsStringSync(),
        'ملاحظات محلية',
      );
      expect(File('${outDir.path}/workspace.sqlite').lengthSync(), 64);
    });

    test('a wrong passphrase writes nothing to the destination', () async {
      final vault = File('${restore.path}/backup.tmewia');
      await service.sealDirectory(
        workspaceDir: workspace,
        passphrase: 'vault-pass',
        targetFile: vault,
      );
      final outDir = Directory('${restore.path}/out');

      await expectLater(
        service.extractTo(
          vaultFile: vault,
          passphrase: 'nope',
          targetDir: outDir,
        ),
        throwsA(isA<VaultError>()),
      );
      expect(outDir.existsSync(), isFalse);
    });

    test('the vault file contains no workspace filename in clear', () async {
      final vault = File('${restore.path}/backup.tmewia');
      await service.sealDirectory(
        workspaceDir: workspace,
        passphrase: 'vault-pass',
        targetFile: vault,
      );
      final asText =
          utf8.decode(vault.readAsBytesSync(), allowMalformed: true);
      expect(asText.contains('workspace.sqlite'), isFalse);
      expect(asText.contains('ملاحظات'), isFalse);
    });

    test('describe exposes sizes only, never the manifest', () async {
      final vault = File('${restore.path}/backup.tmewia');
      await service.sealDirectory(
        workspaceDir: workspace,
        passphrase: 'vault-pass',
        targetFile: vault,
      );
      final info = service.describe(vault);
      expect(info['encrypted_metadata'], isTrue);
      expect(info['container_bytes'], vault.lengthSync());
      expect(info.keys, isNot(contains('entry_list')));
    });
  });
}

Uint8List _u32(int value) => Uint8List(4)
  ..[0] = value & 0xff
  ..[1] = (value >> 8) & 0xff
  ..[2] = (value >> 16) & 0xff
  ..[3] = (value >> 24) & 0xff;
