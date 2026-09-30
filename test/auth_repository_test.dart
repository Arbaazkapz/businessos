import 'dart:convert';

import 'package:businessos/data/repositories.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('PIN hashing and persisted cooldown survive a new repository', () async {
    final auth = AuthRepository();
    await auth.setPin('123456');
    expect(await auth.verifyPin('123456'), isTrue);
    for (var i = 0; i < 5; i++) {
      expect(await auth.verifyPin('000000'), isFalse);
    }
    final reopened = AuthRepository();
    expect(await reopened.pinCooldownSeconds(), greaterThan(0));
    expect(await reopened.verifyPin('123456'), isFalse);
  });

  test('successful legacy PIN verification upgrades the stored hash', () async {
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'businessos_pin_hash_v1',
      value: sha256.convert(utf8.encode('pin-salt-v1:1234')).toString(),
    );
    final auth = AuthRepository();
    expect(await auth.verifyPin('1234'), isTrue);
    final upgraded =
        jsonDecode((await storage.read(key: 'businessos_pin_hash_v1'))!) as Map;
    expect(upgraded['salt'], isNotEmpty);
    expect(upgraded['hash'], isNotEmpty);
    expect(await AuthRepository().verifyPin('1234'), isTrue);
  });
}
