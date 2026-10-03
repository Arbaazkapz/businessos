import 'package:businessos/data/app_database.dart';
import 'package:businessos/data/repositories.dart';
import 'package:businessos/providers/app_providers.dart';
import 'package:businessos/ui/screens/history_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('daily history opens records in a compact window', (
    tester,
  ) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      await BusinessRepository(db)
          .createProfile(businessName: 'Shop', ownerName: 'Owner');
      final customer = await CustomerRepository(db).create(name: 'Asha');
      await LedgerRepository(db).addEntry(
        customerId: customer,
        type: LedgerEntryType.creditGiven,
        amount: 50,
        note: 'Groceries',
      );
    });
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 record'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Groceries'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
