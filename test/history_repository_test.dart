import 'package:businessos/data/app_database.dart';
import 'package:businessos/data/history_repository.dart';
import 'package:businessos/data/repositories.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InvoiceRepository invoices;
  late LedgerRepository ledger;
  late HistoryRepository history;
  late String customer;
  final today = DateTime(2026, 10, 1);
  setUp(() async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    final business = BusinessRepository(db);
    await business.createProfile(businessName: 'Shop', ownerName: 'Owner');
    customer = await CustomerRepository(db).create(name: 'Customer');
    ledger = LedgerRepository(db);
    invoices = InvoiceRepository(db, business, ProductRepository(db), ledger);
    history = HistoryRepository(db);
  });
  tearDown(() => db.close());
  Future<String> invoice(InvoiceStatus status, {double paid = 0}) async {
    final id = await invoices.createInvoice(
      customerId: customer,
      customerNameSnapshot: 'Customer',
      lines: [InvoiceLineInput(description: 'Goods', qty: 1, unitPrice: 100)],
      status: status,
      amountPaidNow: paid,
    );
    await (db.update(db.invoices)..where((t) => t.id.equals(id))).write(
      InvoicesCompanion(invoiceDate: Value(today)),
    );
    await (db.update(db.ledgerEntries)
          ..where((t) => t.linkedInvoiceId.equals(id)))
        .write(LedgerEntriesCompanion(entryDate: Value(today)));
    return id;
  }

  test('cash invoice and partial payment count once; later settlement belongs to its actual day', () async {
    await invoice(InvoiceStatus.paid);
    await invoice(InvoiceStatus.partial, paid: 20);
    await ledger.addEntry(
      customerId: customer,
      type: LedgerEntryType.paymentReceived,
      amount: 80,
      entryDate: DateTime(2026, 10, 2),
    );
    final days = await history.watchDays(today, DateTime(2026, 10, 3)).first;
    expect(days.length, 2);
    expect(days[0].received, 80);
    expect(days[0].sales, 0);
    expect(days[1].sales, 200);
    expect(days[1].received, 120);
    expect(days[1].credit, 100);
    expect(days[1].invoiceCount, 2);
  });
  test('date bounds are exclusive at next midnight; detail pagination is deterministic', () async {
    for (var i = 0; i < 4; i++) {
      await ledger.addEntry(
        customerId: customer,
        type: LedgerEntryType.creditGiven,
        amount: 10,
        entryDate: today.add(Duration(hours: i)),
      );
    }
    await ledger.addEntry(
      customerId: customer,
      type: LedgerEntryType.creditGiven,
      amount: 99,
      entryDate: DateTime(2026, 10, 2),
    );
    final days = await history.watchDays(today, DateTime(2026, 10, 2)).first;
    expect(days.single.credit, 40);
    final records = await history.watchRecords(today, limit: 2).first;
    expect(records.length, 2);
    expect(records[0].time.hour, 3);
    expect(records[1].time.hour, 2);
  });
}
