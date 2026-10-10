import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:businessos/services/backup_codec.dart';

void main() {
  const password = 'correct horse battery staple';
  final bytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
  test('authenticated backup round trip and randomized encryption', () async {
    final a = await BackupCodec.encode(bytes, password);
    final b = await BackupCodec.encode(bytes, password);
    expect(a, isNot(equals(b)));
    expect(await BackupCodec.decode(a, password), bytes);
  });
  test(
    'wrong passphrase, tampered header, nonce and ciphertext rejected',
    () async {
      final encoded = await BackupCodec.encode(bytes, password);
      await expectLater(
        BackupCodec.decode(encoded, 'wrong password'),
        throwsFormatException,
      );
      for (final offset in [8, 24, 36, encoded.length - 1]) {
        final changed = Uint8List.fromList(encoded);
        changed[offset] ^= 1;
        await expectLater(
          BackupCodec.decode(changed, password),
          throwsFormatException,
        );
      }
    },
  );
  test('short passphrases are rejected; no passphrase uses the built-in key',
      () async {
    await expectLater(BackupCodec.encode(bytes, '1234'), throwsFormatException);
    final encoded = await BackupCodec.encode(bytes, '');
    expect(await BackupCodec.decode(encoded, ''), bytes);
    // A backup made with a real passphrase cannot be opened without it.
    final protected = await BackupCodec.encode(bytes, 'my long passphrase');
    await expectLater(BackupCodec.decode(protected, ''), throwsFormatException);
    expect(await BackupCodec.decode(protected, 'my long passphrase'), bytes);
  });
  test('legacy CBC backup remains readable', () async {
    final key = enc.Key(
      Uint8List.fromList(sha256.convert(utf8.encode('1234')).bytes),
    );
    final iv = enc.IV(Uint8List(16));
    final old = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
        .encryptBytes(bytes, iv: iv);
    expect(
      await BackupCodec.decode([...iv.bytes, ...old.bytes], '1234'),
      bytes,
    );
  });
}
