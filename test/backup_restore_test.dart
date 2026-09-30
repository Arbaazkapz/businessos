import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:businessos/services/backup_codec.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:businessos/data/app_database.dart';
import 'package:businessos/data/repositories.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late AppDatabase db;
  late BackupRepository backup;
  late CustomerRepository customers;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shophisab-test-');
    PathProviderPlatform.instance = _Paths(temp.path);
    db = AppDatabase.forExecutor(
      NativeDatabase(File('${temp.path}/businessos.sqlite')),
    );
    await BusinessRepository(db).createProfile(
      businessName: 'Original',
      ownerName: 'Owner',
      currencyCode: 'USD',
    );
    backup = BackupRepository(db);
    customers = CustomerRepository(db);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });
  test('round trip restores records and keeps live database usable', () async {
    await customers.create(name: 'Before backup');
    final file = await backup.exportEncrypted(
      passphrase: 'a long test passphrase',
    );
    await customers.create(name: 'After backup');
    await backup.restoreEncrypted(file, passphrase: 'a long test passphrase');
    expect((await db.select(db.customers).get()).map((c) => c.name), [
      'Before backup',
    ]);
    expect((await BusinessRepository(db).getProfile())!.currencyCode, 'USD');
    await customers.create(name: 'Still usable');
    expect((await db.select(db.customers).get()).length, 2);
  });
  test('wrong password or corrupt file leaves existing data intact', () async {
    await customers.create(name: 'Keep me');
    final file = await backup.exportEncrypted(
      passphrase: 'a long test passphrase',
    );
    await expectLater(
      backup.restoreEncrypted(file, passphrase: 'wrong password'),
      throwsFormatException,
    );
    final bytes = await file.readAsBytes();
    bytes[bytes.length - 1] ^= 1;
    await file.writeAsBytes(bytes);
    await expectLater(
      backup.restoreEncrypted(file, passphrase: 'a long test passphrase'),
      throwsFormatException,
    );
    expect((await db.select(db.customers).get()).single.name, 'Keep me');
  });
  test(
    'version 1 backup migrates paid invoices and default currency',
    () async {
      final legacyFile = File('${temp.path}/legacy.sqlite');
      final legacy = AppDatabase.forExecutor(NativeDatabase(legacyFile));
      await BusinessRepository(legacy)
          .createProfile(businessName: 'Legacy', ownerName: 'Owner');
      await legacy.customStatement(
        "INSERT INTO invoices (id, invoice_number, invoice_date, subtotal, total, status) VALUES ('old', 'INV-1', 1, 42, 42, 'paid')",
      );
      await legacy.close();
      final sql = raw.sqlite3.open(legacyFile.path);
      try {
        sql.execute('ALTER TABLE invoices DROP COLUMN amount_paid');
        sql.execute('ALTER TABLE business_profiles DROP COLUMN currency_code');
        sql.execute('DROP TABLE notes');
        sql.execute('PRAGMA user_version = 1');
      } finally {
        sql.dispose();
      }
      final encrypted = File('${temp.path}/legacy.bosb');
      await encrypted.writeAsBytes(
        await BackupCodec.encode(
          await legacyFile.readAsBytes(),
          'legacy backup password',
        ),
      );
      await backup.restoreEncrypted(
        encrypted,
        passphrase: 'legacy backup password',
      );
      expect((await db.select(db.invoices).get()).single.amountPaid, 42);
      expect((await BusinessRepository(db).getProfile())!.currencyCode, 'INR');
      expect(await db.select(db.notes).get(), isEmpty);
    },
  );
}
