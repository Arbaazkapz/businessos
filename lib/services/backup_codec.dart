import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as legacy;
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Versioned, authenticated envelope. Never reuse the app PIN as a new
/// backup password. Legacy CBC exports remain readable for migration.
class BackupCodec {
  // Keep isolate closures outside repositories: a repository closure can
  // capture its live SQLite connection, which cannot cross isolate boundaries.
  static Future<Uint8List> encodeInBackground(
    List<int> bytes,
    String password,
  ) => Isolate.run(() => encode(bytes, password));

  static Future<Uint8List> decodeInBackground(
    List<int> bytes,
    String password,
  ) => Isolate.run(() => decode(bytes, password));

  static const maxBytes = 64 * 1024 * 1024;
  static const iterations = 210000;
  static final _magic = utf8.encode('SHOPHB02');

  /// Used when the user does not choose their own passphrase, so a backup can
  /// be restored on any phone with one tap. Backups made this way are still
  /// AES-256-GCM encrypted, but the key is built into the app: protection then
  /// comes from the private Google Drive app folder, not from a secret.
  static const defaultPassphrase = 'ShopHisab::built-in-backup-key::v1';

  static String _effective(String password) =>
      password.trim().isEmpty ? defaultPassphrase : password;

  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Future<Uint8List> encode(List<int> bytes, String password) async {
    // An empty passphrase means "no passphrase": use the built-in key.
    if (password.trim().isNotEmpty && password.trim().length < 10) {
      throw const FormatException(
        'Use a backup passphrase of at least 10 characters.',
      );
    }
    final secret = _effective(password);
    if (bytes.length > maxBytes - 1024) {
      throw const FormatException(
        'This backup exceeds the supported 64 MB limit.',
      );
    }
    final cipher = AesGcm.with256bits();
    final salt = SecretKeyData.random(length: 16).bytes;
    final header = [..._magic, ...salt];
    final box = await cipher.encrypt(
      bytes,
      secretKey: await _key(secret, salt),
      aad: header,
    );
    return Uint8List.fromList([
      ...header,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  static Future<Uint8List> decode(List<int> bytes, String password) async {
    if (bytes.length > maxBytes || bytes.length < 32) {
      throw const FormatException('Invalid backup size (maximum 64 MB).');
    }
    try {
      final modern =
          bytes.length >= 52 &&
          List.generate(8, (i) => bytes[i] == _magic[i]).every((v) => v);
      if (modern) {
        final box = SecretBox(
          bytes.sublist(52),
          nonce: bytes.sublist(24, 36),
          mac: Mac(bytes.sublist(36, 52)),
        );
        return Uint8List.fromList(
          await AesGcm.with256bits().decrypt(
            box,
            secretKey: await _key(_effective(password), bytes.sublist(8, 24)),
            aad: bytes.sublist(0, 24),
          ),
        );
      }
      final oldPassword = password.isEmpty
          ? 'businessos-default-passphrase-v1'
          : password;
      final key = enc.Key(
        Uint8List.fromList(
          legacy.sha256.convert(utf8.encode(oldPassword)).bytes,
        ),
      );
      return Uint8List.fromList(
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc)).decryptBytes(
          enc.Encrypted(Uint8List.fromList(bytes.sublist(16))),
          iv: enc.IV(Uint8List.fromList(bytes.sublist(0, 16))),
        ),
      );
    } catch (_) {
      throw const FormatException(
        'Wrong passphrase or damaged backup. Current data has not changed.',
      );
    }
  }
}
