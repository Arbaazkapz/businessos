import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// TABLES
// ---------------------------------------------------------------------------

/// Singleton-style table: in practice exactly one row exists, created during
/// first-run onboarding. No login, no server account - this row *is* the
/// business's identity, stored only on this device.
@DataClassName('BusinessProfile')
class BusinessProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get businessName => text()();
  TextColumn get ownerName => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get gstNumber => text().nullable()();
  TextColumn get category =>
      text().withDefault(const Constant('General Store'))();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();
  IntColumn get nextInvoiceSeq => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Customer')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get gstNumber => text().nullable()();
  RealColumn get creditLimit => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isFavourite => boolean().withDefault(const Constant(false))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ledger entry semantics (standard "khata" convention):
///  - creditGiven      => you gave goods/money on credit; customer owes MORE
///  - paymentReceived   => customer paid you back; balance owed goes DOWN
enum LedgerEntryType { creditGiven, paymentReceived }

@DataClassName('LedgerEntry')
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get type => textEnum<LedgerEntryType>()();
  RealColumn get amount => real()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get entryDate => dateTime()();
  TextColumn get linkedInvoiceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Product')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get barcode => text().nullable()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0))();
  RealColumn get stockQty => real().withDefault(const Constant(0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(5))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

enum InvoiceStatus { paid, unpaid, partial }

@DataClassName('Invoice')
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerNameSnapshot =>
      text().withDefault(const Constant('Walk-in Customer'))();
  DateTimeColumn get invoiceDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0))();
  TextColumn get status => textEnum<InvoiceStatus>()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InvoiceItem')
class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(Invoices, #id)();
  TextColumn get productId => text().nullable()();
  TextColumn get description => text()();
  RealColumn get qty => real()();
  RealColumn get unitPrice => real()();
  RealColumn get lineTotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Note')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// DATABASE
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    BusinessProfiles,
    Customers,
    LedgerEntries,
    Products,
    Invoices,
    InvoiceItems,
    Notes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _addIndexes();
    },
    onUpgrade: (m, from, to) => transaction(() async {
      if (from < 2) {
        await m.addColumn(invoices, invoices.amountPaid);
        await customStatement(
          "UPDATE invoices SET amount_paid = total WHERE status = 'paid'",
        );
      }
      if (from < 3) {
        await m.createTable(notes);
      }
      if (from < 4) await _addIndexes();
      if (from < 5)
        await m.addColumn(businessProfiles, businessProfiles.currencyCode);
      await customStatement('PRAGMA user_version = $to');
    }),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  Future<void> _addIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ledger_customer_date ON ledger_entries(customer_id, entry_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ledger_invoice ON ledger_entries(linked_invoice_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS items_invoice ON invoice_items(invoice_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS invoices_customer_date ON invoices(customer_id, invoice_date)',
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'businessos.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  /// Absolute path to the raw sqlite file - used by BackupRepository to
  /// export/import the entire business in one encrypted file.
  static Future<File> resolveDbFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'businessos.sqlite'));
  }
}
