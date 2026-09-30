import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:businessos/data/app_database.dart';
import 'package:businessos/data/repositories.dart';

void main() {
  late AppDatabase db;
  late BusinessRepository business;
  late CustomerRepository customers;
  late ProductRepository products;
  late LedgerRepository ledger;
  late InvoiceRepository invoices;
  late String customer;
  late String product;
  setUp(() async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    business = BusinessRepository(db);
    customers = CustomerRepository(db);
    products = ProductRepository(db);
    ledger = LedgerRepository(db);
    invoices = InvoiceRepository(db, business, products, ledger);
    await business.createProfile(businessName: 'Test shop', ownerName: 'Owner');
    customer = await customers.create(name: 'Customer');
    product = await products.create(
      name: 'Pen',
      stockQty: 10,
      sellingPrice: 10,
    );
  });
  tearDown(() => db.close());
  Future<String> invoice({
    double quantity = 2,
    InvoiceStatus status = InvoiceStatus.partial,
    double paid = 5,
  }) => invoices.createInvoice(
    customerId: customer,
    customerNameSnapshot: 'Customer',
    lines: [
      InvoiceLineInput(
        productId: product,
        description: 'Pen',
        qty: quantity,
        unitPrice: 10,
      ),
    ],
    status: status,
    amountPaidNow: paid,
  );
  test(
    'partial invoice matches ledger; next payment settles invoice',
    () async {
      final id = await invoice();
      expect((await invoices.getById(id))!.amountPaid, 5);
      expect(
        LedgerRepository.balanceOf(await db.select(db.ledgerEntries).get()),
        15,
      );
      await ledger.addEntry(
        customerId: customer,
        type: LedgerEntryType.paymentReceived,
        amount: 15,
      );
      expect((await invoices.getById(id))!.status, InvoiceStatus.paid);
      expect(
        LedgerRepository.balanceOf(await db.select(db.ledgerEntries).get()),
        0,
      );
      expect((await products.getById(product))!.stockQty, 8);
    },
  );
  test('insufficient stock rolls back all writes and numbering', () async {
    await expectLater(invoice(quantity: 11), throwsStateError);
    expect(await db.select(db.invoices).get(), isEmpty);
    expect(await db.select(db.invoiceItems).get(), isEmpty);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
    expect((await products.getById(product))!.stockQty, 10);
    expect((await business.getProfile())!.nextInvoiceSeq, 1);
  });
  test('invalid payment and NaN rejected without mutations', () async {
    await expectLater(invoice(paid: 100), throwsArgumentError);
    await expectLater(
      ledger.addEntry(
        customerId: customer,
        type: LedgerEntryType.creditGiven,
        amount: double.nan,
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.invoices).get(), isEmpty);
  });
  test('concurrent stock adjustments do not lose an update', () async {
    await Future.wait([
      products.adjustStock(product, 2),
      products.adjustStock(product, 3),
    ]);
    expect((await products.getById(product))!.stockQty, 15);
  });
  test('financial history prevents customer deletion', () async {
    await invoice();
    await expectLater(customers.delete(customer), throwsStateError);
    expect(await customers.getById(customer), isNotNull);
  });
  test('blocked customer and credit limit protect credit sales', () async {
    await customers.update(customer, creditLimit: 10);
    await expectLater(invoice(), throwsStateError);
    await customers.update(customer, isBlocked: true);
    await expectLater(
      ledger.addEntry(
        customerId: customer,
        type: LedgerEntryType.creditGiven,
        amount: 1,
      ),
      throwsStateError,
    );
  });
  test('invoice-linked entries cannot be deleted separately', () async {
    await invoice();
    final rows = await db.select(db.ledgerEntries).get();
    await expectLater(ledger.deleteEntry(rows.first.id), throwsStateError);
  });
}
