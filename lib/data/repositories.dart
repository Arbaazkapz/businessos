import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as secure;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../services/backup_codec.dart';

import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import '../core/formatters.dart';

const _uuid = Uuid();

void _nonNegative(double value, String label) {
  if (!value.isFinite || value < 0 || value > 1000000000000) {
    throw ArgumentError(
      '$label must be a finite, non-negative number (up to 1 trillion).',
    );
  }
}

double _money(double value) => (value * 100).round() / 100;

// ---------------------------------------------------------------------------
// BUSINESS PROFILE
// ---------------------------------------------------------------------------

class BusinessRepository {
  BusinessRepository(this._db);
  final AppDatabase _db;

  Future<BusinessProfile?> getProfile() =>
      (_db.select(_db.businessProfiles)..limit(1)).getSingleOrNull();

  Stream<BusinessProfile?> watchProfile() =>
      (_db.select(_db.businessProfiles)..limit(1)).watchSingleOrNull();

  Future<void> createProfile({
    required String businessName,
    required String ownerName,
    String phone = '',
    String address = '',
    String? gstNumber,
    String category = 'General Store',
    String currencyCode = 'INR',
  }) => _db.transaction(() async {
    if (await getProfile() != null)
      throw StateError('A business is already set up.');
    if (businessName.trim().isEmpty || ownerName.trim().isEmpty)
      throw ArgumentError('Business and owner names are required.');
    if (!AppFormatters.currencies.containsKey(currencyCode))
      throw ArgumentError('Unsupported currency.');
    await _db
        .into(_db.businessProfiles)
        .insert(
          BusinessProfilesCompanion.insert(
            businessName: businessName.trim(),
            ownerName: ownerName.trim(),
            phone: Value(phone),
            address: Value(address),
            gstNumber: Value(gstNumber),
            category: Value(category),
            currencyCode: Value(currencyCode),
          ),
        );
  });

  Future<void> updateProfile(
    BusinessProfile profile, {
    String? businessName,
    String? ownerName,
    String? phone,
    String? address,
    String? gstNumber,
    String? category,
    String? invoicePrefix,
  }) {
    return (_db.update(
      _db.businessProfiles,
    )..where((t) => t.id.equals(profile.id))).write(
      BusinessProfilesCompanion(
        businessName: businessName != null
            ? Value(businessName)
            : const Value.absent(),
        ownerName: ownerName != null ? Value(ownerName) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        gstNumber: gstNumber != null ? Value(gstNumber) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        invoicePrefix: invoicePrefix != null
            ? Value(invoicePrefix)
            : const Value.absent(),
      ),
    );
  }

  /// Atomically reserves and returns the next invoice number, e.g. INV-0007.
  /// Fully offline: numbering never depends on a server.
  Future<String> nextInvoiceNumber() async {
    return _db.transaction(() async {
      final profile = await getProfile();
      if (profile == null) {
        throw StateError('Business profile is not set up yet.');
      }
      final number =
          '${profile.invoicePrefix}-${profile.nextInvoiceSeq.toString().padLeft(4, '0')}';
      await (_db.update(
        _db.businessProfiles,
      )..where((t) => t.id.equals(profile.id))).write(
        BusinessProfilesCompanion(
          nextInvoiceSeq: Value(profile.nextInvoiceSeq + 1),
        ),
      );
      return number;
    });
  }
}

// ---------------------------------------------------------------------------
// CUSTOMERS
// ---------------------------------------------------------------------------

class CustomerRepository {
  CustomerRepository(this._db);
  final AppDatabase _db;

  Stream<List<Customer>> watchAll() => (_db.select(
    _db.customers,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Customer?> getById(String id) => (_db.select(
    _db.customers,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    String phone = '',
    String address = '',
    String? gstNumber,
    double? creditLimit,
    String notes = '',
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required.');
    if (creditLimit != null) _nonNegative(creditLimit, 'Credit limit');
    final id = _uuid.v4();
    await _db
        .into(_db.customers)
        .insert(
          CustomersCompanion.insert(
            id: id,
            name: name,
            phone: Value(phone),
            address: Value(address),
            gstNumber: Value(gstNumber),
            creditLimit: Value(creditLimit),
            notes: Value(notes),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    String? phone,
    String? address,
    String? gstNumber,
    double? creditLimit,
    bool clearCreditLimit = false,
    String? notes,
    bool? isFavourite,
    bool? isBlocked,
  }) {
    if (creditLimit != null) _nonNegative(creditLimit, 'Credit limit');
    if (name != null && name.trim().isEmpty)
      throw ArgumentError('Customer name is required.');
    return (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        gstNumber: gstNumber != null ? Value(gstNumber) : const Value.absent(),
        creditLimit: clearCreditLimit
            ? const Value(null)
            : creditLimit != null
            ? Value(creditLimit)
            : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        isFavourite: isFavourite != null
            ? Value(isFavourite)
            : const Value.absent(),
        isBlocked: isBlocked != null ? Value(isBlocked) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) => _db.transaction(() async {
    final ledger =
        await (_db.select(_db.ledgerEntries)
              ..where((t) => t.customerId.equals(id))
              ..limit(1))
            .get();
    final invoices =
        await (_db.select(_db.invoices)
              ..where((t) => t.customerId.equals(id))
              ..limit(1))
            .get();
    if (ledger.isNotEmpty || invoices.isNotEmpty) {
      throw StateError(
        'This customer has financial records. Keep the customer to preserve your books.',
      );
    }
    await (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
  });
}

// ---------------------------------------------------------------------------
// LEDGER
// ---------------------------------------------------------------------------

class LedgerRepository {
  LedgerRepository(this._db);
  final AppDatabase _db;

  Stream<List<LedgerEntry>> watchAll() => _db.select(_db.ledgerEntries).watch();

  Stream<List<LedgerEntry>> watchForCustomer(String customerId) {
    return (_db.select(_db.ledgerEntries)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]))
        .watch();
  }

  Future<String> addEntry({
    required String customerId,
    required LedgerEntryType type,
    required double amount,
    String note = '',
    DateTime? entryDate,
    String? linkedInvoiceId,
  }) async {
    _nonNegative(amount, 'Amount');
    amount = _money(amount);
    if (amount <= 0) throw ArgumentError('Amount must be at least 0.01.');
    return _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();
      if (customer == null) throw StateError('Customer no longer exists.');
      if (type == LedgerEntryType.creditGiven) {
        if (customer.isBlocked)
          throw StateError('Unblock this customer before giving more credit.');
        final entries = await (_db.select(
          _db.ledgerEntries,
        )..where((t) => t.customerId.equals(customerId))).get();
        // Invoice creation checks its NET outstanding amount as a unit.
        if (linkedInvoiceId == null &&
            customer.creditLimit != null &&
            _money(balanceOf(entries) + amount) > customer.creditLimit!) {
          throw StateError('This entry exceeds the customer credit limit.');
        }
      }
      final id = _uuid.v4();
      Future<void> insert(String rowId, double value, String? invoiceId) => _db
          .into(_db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: rowId,
              customerId: customerId,
              type: type,
              amount: value,
              note: Value(note),
              entryDate: entryDate ?? DateTime.now(),
              linkedInvoiceId: Value(invoiceId),
            ),
          );
      // Customer payments settle oldest outstanding invoices first. Any
      // remainder stays as customer advance credit, never negative invoice due.
      if (type == LedgerEntryType.paymentReceived && linkedInvoiceId == null) {
        final open =
            await (_db.select(_db.invoices)
                  ..where(
                    (t) =>
                        t.customerId.equals(customerId) &
                        (t.status.equals(InvoiceStatus.unpaid.name) |
                            t.status.equals(InvoiceStatus.partial.name)),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.asc(t.invoiceDate),
                    (t) => OrderingTerm.asc(t.id),
                  ]))
                .get();
        var remaining = amount;
        var first = true;
        for (final invoice in open) {
          final due = _money(invoice.total - invoice.amountPaid);
          if (due <= 0 || remaining <= 0) continue;
          final allocated = remaining < due ? remaining : due;
          final paid = _money(invoice.amountPaid + allocated);
          await (_db.update(
            _db.invoices,
          )..where((t) => t.id.equals(invoice.id))).write(
            InvoicesCompanion(
              amountPaid: Value(paid),
              status: Value(
                paid >= invoice.total
                    ? InvoiceStatus.paid
                    : InvoiceStatus.partial,
              ),
            ),
          );
          await insert(first ? id : _uuid.v4(), allocated, invoice.id);
          first = false;
          remaining = _money(remaining - allocated);
        }
        if (remaining > 0)
          await insert(first ? id : _uuid.v4(), remaining, null);
      } else {
        await insert(id, amount, linkedInvoiceId);
      }
      return id;
    });
  }

  Future<void> updateEntry(
    String id, {
    double? amount,
    String? note,
    DateTime? entryDate,
  }) => _db.transaction(() async {
    final entry = await (_db.select(
      _db.ledgerEntries,
    )..where((t) => t.id.equals(id))).getSingle();
    if (entry.linkedInvoiceId != null)
      throw StateError(
        'Invoice-linked entries cannot be edited independently.',
      );
    if (amount != null) {
      _nonNegative(amount, 'Amount');
      if (_money(amount) <= 0) throw ArgumentError('Amount must be positive.');
    }
    await (_db.update(_db.ledgerEntries)..where((t) => t.id.equals(id))).write(
      LedgerEntriesCompanion(
        amount: amount != null ? Value(_money(amount)) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        entryDate: entryDate != null ? Value(entryDate) : const Value.absent(),
      ),
    );
  });

  Future<void> deleteEntry(String id) => _db.transaction(() async {
    final entry = await (_db.select(
      _db.ledgerEntries,
    )..where((t) => t.id.equals(id))).getSingle();
    if (entry.linkedInvoiceId != null)
      throw StateError(
        'Invoice-linked entries cannot be deleted independently.',
      );
    await (_db.delete(_db.ledgerEntries)..where((t) => t.id.equals(id))).go();
  });

  // ---- Pure-Dart aggregation helpers (simple, auditable, no surprises) ----

  /// Positive = customer owes the shop money. Negative = shop owes customer (overpaid).
  static double balanceOf(Iterable<LedgerEntry> entries) {
    var bal = 0.0;
    for (final e in entries) {
      bal += e.type == LedgerEntryType.creditGiven ? e.amount : -e.amount;
    }
    return bal;
  }

  static double sumToday(Iterable<LedgerEntry> entries, LedgerEntryType type) {
    final now = DateTime.now();
    return entries
        .where(
          (e) =>
              e.type == type &&
              e.entryDate.year == now.year &&
              e.entryDate.month == now.month &&
              e.entryDate.day == now.day,
        )
        .fold(0.0, (a, b) => a + b.amount);
  }

  /// Sum of every customer's positive balance ("money to receive" on the dashboard).
  static double totalReceivable(Iterable<LedgerEntry> entries) {
    final Map<String, double> perCustomer = {};
    for (final e in entries) {
      final delta = e.type == LedgerEntryType.creditGiven
          ? e.amount
          : -e.amount;
      perCustomer.update(e.customerId, (v) => v + delta, ifAbsent: () => delta);
    }
    return perCustomer.values.where((v) => v > 0).fold(0.0, (a, b) => a + b);
  }
}

// ---------------------------------------------------------------------------
// PRODUCTS / INVENTORY
// ---------------------------------------------------------------------------

class ProductRepository {
  ProductRepository(this._db);
  final AppDatabase _db;

  Stream<List<Product>> watchAll() => (_db.select(
    _db.products,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Product?> getById(String id) => (_db.select(
    _db.products,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    String category = '',
    String? barcode,
    double purchasePrice = 0,
    double sellingPrice = 0,
    double stockQty = 0,
    double lowStockThreshold = 5,
    String unit = 'pcs',
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Product name is required.');
    for (final value in [
      purchasePrice,
      sellingPrice,
      stockQty,
      lowStockThreshold,
    ]) {
      _nonNegative(value, 'Product value');
    }
    final id = _uuid.v4();
    await _db
        .into(_db.products)
        .insert(
          ProductsCompanion.insert(
            id: id,
            name: name,
            category: Value(category),
            barcode: Value(barcode),
            purchasePrice: Value(purchasePrice),
            sellingPrice: Value(sellingPrice),
            stockQty: Value(stockQty),
            lowStockThreshold: Value(lowStockThreshold),
            unit: Value(unit),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    String? category,
    String? barcode,
    double? purchasePrice,
    double? sellingPrice,
    double? stockQty,
    double? lowStockThreshold,
    String? unit,
  }) {
    for (final value in [
      purchasePrice,
      sellingPrice,
      stockQty,
      lowStockThreshold,
    ]) {
      if (value != null) _nonNegative(value, 'Product value');
    }
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        barcode: barcode != null ? Value(barcode) : const Value.absent(),
        purchasePrice: purchasePrice != null
            ? Value(purchasePrice)
            : const Value.absent(),
        sellingPrice: sellingPrice != null
            ? Value(sellingPrice)
            : const Value.absent(),
        stockQty: stockQty != null ? Value(stockQty) : const Value.absent(),
        lowStockThreshold: lowStockThreshold != null
            ? Value(lowStockThreshold)
            : const Value.absent(),
        unit: unit != null ? Value(unit) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();

  Future<void> adjustStock(
    String id,
    double delta,
  ) => _db.transaction(() async {
    if (!delta.isFinite) throw ArgumentError('Invalid stock quantity.');
    final product = await getById(id);
    if (product == null) throw StateError('Product no longer exists.');
    final next = double.parse((product.stockQty + delta).toStringAsFixed(6));
    if (next < 0)
      throw StateError(
        'Not enough stock for ${product.name}. Available: ${product.stockQty} ${product.unit}.',
      );
    await update(id, stockQty: next);
  });

  static List<Product> lowStock(Iterable<Product> products) =>
      products.where((p) => p.stockQty <= p.lowStockThreshold).toList();
}

// ---------------------------------------------------------------------------
// INVOICES
// ---------------------------------------------------------------------------

class InvoiceLineInput {
  InvoiceLineInput({
    required this.description,
    required this.qty,
    required this.unitPrice,
    this.productId,
  });
  final String? productId;
  final String description;
  final double qty;
  final double unitPrice;
  double get lineTotal => _money(qty * unitPrice);
}

class InvoiceRepository {
  InvoiceRepository(this._db, this._business, this._products, this._ledger);
  final AppDatabase _db;
  final BusinessRepository _business;
  final ProductRepository _products;
  final LedgerRepository _ledger;

  Stream<List<Invoice>> watchAll() => (_db.select(
    _db.invoices,
  )..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)])).watch();

  Future<Invoice?> getById(String id) => (_db.select(
    _db.invoices,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceItem>> itemsFor(String invoiceId) => (_db.select(
    _db.invoiceItems,
  )..where((t) => t.invoiceId.equals(invoiceId))).get();

  /// Creates an invoice, its line items, decrements product stock, and
  /// (optionally) posts the resulting due/paid amounts straight into the
  /// customer's ledger so books always stay in sync automatically.
  Future<String> createInvoice({
    required String? customerId,
    required String customerNameSnapshot,
    required List<InvoiceLineInput> lines,
    double discount = 0,
    double taxPercent = 0,
    required InvoiceStatus status,
    double amountPaidNow = 0,
    String notes = '',
    DateTime? dueDate,
    bool postToLedger = true,
  }) async {
    if (lines.isEmpty) throw ArgumentError('Add at least one invoice item.');
    for (final line in lines) {
      _nonNegative(line.qty, 'Quantity');
      _nonNegative(line.unitPrice, 'Price');
      if (line.qty <= 0 || line.description.trim().isEmpty)
        throw ArgumentError('Every item needs a name and positive quantity.');
    }
    _nonNegative(discount, 'Discount');
    _nonNegative(taxPercent, 'Tax');
    _nonNegative(amountPaidNow, 'Payment');
    if (taxPercent > 100)
      throw ArgumentError('Tax must be between 0 and 100%.');
    final invoiceId = _uuid.v4();
    final subtotal = lines.fold<double>(0, (a, l) => a + l.lineTotal);
    _nonNegative(subtotal, 'Invoice subtotal');
    if (discount > subtotal)
      throw ArgumentError('Discount cannot exceed the subtotal.');
    final afterDiscount = _money(subtotal - discount);
    final taxAmount = _money(afterDiscount * (taxPercent / 100));
    final total = _money(afterDiscount + taxAmount);
    if (amountPaidNow > total)
      throw ArgumentError('Payment cannot exceed the invoice total.');
    final amountPaid = switch (status) {
      InvoiceStatus.paid => total,
      InvoiceStatus.partial => _money(amountPaidNow),
      InvoiceStatus.unpaid => 0.0,
    };

    final actualStatus = amountPaid >= total
        ? InvoiceStatus.paid
        : amountPaid > 0
        ? InvoiceStatus.partial
        : InvoiceStatus.unpaid;
    if (actualStatus != InvoiceStatus.paid && customerId == null)
      throw ArgumentError('Select a customer for unpaid invoices.');
    if (customerId != null &&
        !postToLedger &&
        actualStatus != InvoiceStatus.paid)
      throw ArgumentError('Credit invoices must be posted to the ledger.');
    await _db.transaction(() async {
      if (customerId != null) {
        final customer = await (_db.select(
          _db.customers,
        )..where((t) => t.id.equals(customerId))).getSingleOrNull();
        if (customer == null) throw StateError('Customer no longer exists.');
        final due = _money(total - amountPaid);
        if (due > 0) {
          if (customer.isBlocked)
            throw StateError('Customer is blocked for credit.');
          final entries = await (_db.select(
            _db.ledgerEntries,
          )..where((t) => t.customerId.equals(customerId))).get();
          if (customer.creditLimit != null &&
              _money(LedgerRepository.balanceOf(entries) + due) >
                  customer.creditLimit!) {
            throw StateError('Invoice exceeds the customer credit limit.');
          }
        }
      }
      final invoiceNumber = await _business.nextInvoiceNumber();
      await _db
          .into(_db.invoices)
          .insert(
            InvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: invoiceNumber,
              customerId: Value(customerId),
              customerNameSnapshot: Value(customerNameSnapshot),
              invoiceDate: DateTime.now(),
              dueDate: Value(dueDate),
              subtotal: subtotal,
              discount: Value(discount),
              taxPercent: Value(taxPercent),
              total: total,
              amountPaid: Value(amountPaid),
              status: actualStatus,
              notes: Value(notes),
            ),
          );

      for (final line in lines) {
        await _db
            .into(_db.invoiceItems)
            .insert(
              InvoiceItemsCompanion.insert(
                id: _uuid.v4(),
                invoiceId: invoiceId,
                productId: Value(line.productId),
                description: line.description,
                qty: line.qty,
                unitPrice: line.unitPrice,
                lineTotal: line.lineTotal,
              ),
            );
        if (line.productId != null) {
          await _products.adjustStock(line.productId!, -line.qty);
        }
      }

      if (customerId != null && postToLedger) {
        if (actualStatus == InvoiceStatus.unpaid) {
          await _ledger.addEntry(
            customerId: customerId,
            type: LedgerEntryType.creditGiven,
            amount: total,
            note: 'Invoice $invoiceNumber',
            linkedInvoiceId: invoiceId,
          );
        } else if (actualStatus == InvoiceStatus.partial) {
          await _ledger.addEntry(
            customerId: customerId,
            type: LedgerEntryType.creditGiven,
            amount: total,
            note: 'Invoice $invoiceNumber',
            linkedInvoiceId: invoiceId,
          );
          if (amountPaid > 0) {
            await _ledger.addEntry(
              customerId: customerId,
              type: LedgerEntryType.paymentReceived,
              amount: amountPaid,
              note: 'Partial payment - $invoiceNumber',
              linkedInvoiceId: invoiceId,
            );
          }
        }
      }
    });

    return invoiceId;
  }
}

// ---------------------------------------------------------------------------
// NOTES (simple notepad)
// ---------------------------------------------------------------------------

class NoteRepository {
  NoteRepository(this._db);
  final AppDatabase _db;

  Stream<List<Note>> watchAll() => (_db.select(
    _db.notes,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<String> create(String content) async {
    final id = _uuid.v4();
    await _db
        .into(_db.notes)
        .insert(NotesCompanion.insert(id: id, content: content));
    return id;
  }

  Future<void> update(String id, String content) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(content: Value(content), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
}

// ---------------------------------------------------------------------------
// BACKUP & RESTORE (fully local, AES-256 encrypted, no cloud involved)
// ---------------------------------------------------------------------------

class BackupRepository {
  BackupRepository(this._db);
  final AppDatabase _db;
  static bool _busy = false;

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy)
      throw StateError('Another backup or restore is already running.');
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<File> exportEncrypted({required String passphrase}) =>
      _exclusive(() async {
        if (passphrase.trim().length < 10) {
          throw const FormatException(
            'Use a backup passphrase of at least 10 characters.',
          );
        }
        final folder = await getTemporaryDirectory();
        final id = _uuid.v4();
        final snapshot = File(p.join(folder.path, 'snapshot_$id.sqlite'));
        try {
          // VACUUM INTO includes committed WAL data and makes one consistent snapshot.
          await _db.customStatement('VACUUM INTO ?', [snapshot.path]);
          if (await snapshot.length() > BackupCodec.maxBytes - 1024) {
            throw const FormatException(
              'This backup exceeds the supported 64 MB limit.',
            );
          }
          final bytes = await snapshot.readAsBytes();
          final encrypted = await BackupCodec.encodeInBackground(
            bytes,
            passphrase,
          );
          final stamp = AppFormatters.fileTimestamp(DateTime.now());
          final output = File(
            p.join(folder.path, 'shophisab_backup_${stamp}_$id.bosb'),
          );
          await output.writeAsBytes(encrypted, flush: true);
          return output;
        } finally {
          if (await snapshot.exists()) await snapshot.delete();
        }
      });

  /// Stage, validate and migrate an isolated database BEFORE touching live data.
  /// Replace rows in a single SQLite transaction; interruption rolls everything
  /// back. Keep the live connection open so subscribed screens refresh safely.
  Future<void> restoreEncrypted(
    File backupFile, {
    required String passphrase,
  }) => _exclusive(() async {
    if (await backupFile.length() > BackupCodec.maxBytes) {
      throw const FormatException('Backup exceeds the supported 64 MB limit.');
    }
    final encrypted = await backupFile.readAsBytes();
    final bytes = await BackupCodec.decodeInBackground(encrypted, passphrase);
    if (bytes.length < 100 ||
        utf8.decode(bytes.sublist(0, 16), allowMalformed: true) !=
            'SQLite format 3\u0000') {
      throw const FormatException('This file is not a ShopHisab database.');
    }
    final folder = await getTemporaryDirectory();
    final stagedFile = File(
      p.join(folder.path, 'restore_${_uuid.v4()}.sqlite'),
    );
    AppDatabase? staged;
    try {
      await stagedFile.writeAsBytes(bytes, flush: true);
      final check = raw.sqlite3.open(stagedFile.path);
      try {
        final version =
            check.select('PRAGMA user_version').first.values.first as int;
        if (version < 1 || version > _db.schemaVersion) {
          throw const FormatException(
            'Unsupported backup version. Update ShopHisab first.',
          );
        }
        if (check
            .select('PRAGMA integrity_check')
            .any((row) => row.values.first != 'ok')) {
          throw const FormatException('Backup integrity check failed.');
        }
        final tables = check
            .select("SELECT name FROM sqlite_master WHERE type = 'table'")
            .map((row) => row['name'])
            .toSet();
        if (!tables.containsAll([
          'business_profiles',
          'customers',
          'ledger_entries',
          'products',
          'invoices',
          'invoice_items',
        ])) {
          throw const FormatException('Required ShopHisab tables are missing.');
        }
      } finally {
        check.dispose();
      }
      final source = AppDatabase.forExecutor(NativeDatabase(stagedFile));
      staged = source;
      // Forces all supported legacy migrations on the disposable copy.
      final profile = await source.select(source.businessProfiles).get();
      if (profile.length != 1 || profile.first.businessName.trim().isEmpty) {
        throw const FormatException(
          'Backup must contain exactly one valid business profile.',
        );
      }
      if ((await source.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw const FormatException('Backup contains broken record links.');
      }
      // Force typed decoding and basic ledger checks before committing anything.
      final customers = await source.select(source.customers).get();
      final products = await source.select(source.products).get();
      final invoices = await source.select(source.invoices).get();
      final items = await source.select(source.invoiceItems).get();
      final entries = await source.select(source.ledgerEntries).get();
      final notes = await source.select(source.notes).get();
      if (entries.any((e) => !e.amount.isFinite || e.amount <= 0) ||
          invoices.any(
            (i) =>
                !i.total.isFinite ||
                i.total < 0 ||
                !i.amountPaid.isFinite ||
                i.amountPaid < 0 ||
                i.amountPaid > i.total,
          ) ||
          items.any(
            (i) =>
                !i.qty.isFinite ||
                i.qty <= 0 ||
                !i.unitPrice.isFinite ||
                i.unitPrice < 0,
          )) {
        throw const FormatException(
          'Backup contains invalid amounts. Current data is unchanged.',
        );
      }
      await _db.transaction(() async {
        await _db.delete(_db.invoiceItems).go();
        await _db.delete(_db.ledgerEntries).go();
        await _db.delete(_db.invoices).go();
        await _db.delete(_db.customers).go();
        await _db.delete(_db.products).go();
        await _db.delete(_db.notes).go();
        await _db.delete(_db.businessProfiles).go();
        await _db.batch((batch) {
          batch.insertAll(
            _db.businessProfiles,
            profile.map((r) => r.toCompanion(false)).toList(),
          );
          batch.insertAll(
            _db.customers,
            customers.map((r) => r.toCompanion(false)).toList(),
          );
          batch.insertAll(
            _db.products,
            products.map((r) => r.toCompanion(false)).toList(),
          );
          batch.insertAll(
            _db.invoices,
            invoices.map((r) => r.toCompanion(false)).toList(),
          );
          batch.insertAll(
            _db.invoiceItems,
            items.map((r) => r.toCompanion(false)).toList(),
          );
          batch.insertAll(
            _db.ledgerEntries,
            entries.map((r) => r.toCompanion(false)).toList(),
          );
          batch.insertAll(
            _db.notes,
            notes.map((r) => r.toCompanion(false)).toList(),
          );
        });
      });
    } finally {
      await staged?.close();
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final file = File('${stagedFile.path}$suffix');
        if (await file.exists()) await file.delete();
      }
    }
  });
}

// ---------------------------------------------------------------------------
// SECURITY: PIN lock + biometric unlock
// ---------------------------------------------------------------------------

Future<List<int>> _derivePinHash(String pin, List<int> salt) =>
    Isolate.run(() async {
      final key = await secure.Pbkdf2(
        macAlgorithm: secure.Hmac.sha256(),
        iterations: 100000,
        bits: 256,
      ).deriveKey(secretKey: secure.SecretKey(utf8.encode(pin)), nonce: salt);
      return key.extractBytes();
    });

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  static const _pinHashKey = 'businessos_pin_hash_v1';
  static const _latestBackupPassphraseKey =
      'businessos_latest_backup_passphrase_v1';

  String _backupPassphraseKey(String backupId) =>
      'businessos_backup_passphrase_${sha256.convert(utf8.encode(backupId)).toString()}';

  String _hash(String pin) =>
      sha256.convert(utf8.encode('pin-salt-v1:$pin')).toString();

  // Backup passphrases are kept only in Android/iOS secure storage so a
  // successful biometric check can unlock the same backup credential on
  // this device. A fresh install still requires the user's passphrase.
  Future<void> saveBackupPassphrase(String backupId, String passphrase) async {
    await _storage.write(
      key: _backupPassphraseKey(backupId),
      value: passphrase,
    );
    await _storage.write(key: _latestBackupPassphraseKey, value: passphrase);
  }

  Future<String?> getBackupPassphrase([String? backupId]) => _storage.read(
    key: backupId == null
        ? _latestBackupPassphraseKey
        : _backupPassphraseKey(backupId),
  );

  Future<void> clearBackupPassphrases() async {
    final all = await _storage.readAll();
    for (final key in all.keys.where(
      (k) =>
          k.startsWith('businessos_backup_passphrase_') ||
          k == _latestBackupPassphraseKey,
    )) {
      await _storage.delete(key: key);
    }
  }

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin))
      throw ArgumentError('PIN must be 4–6 digits.');
    final salt = secure.SecretKeyData.random(length: 16).bytes;
    final hash = await _derivePinHash(pin, salt);
    await _storage.write(
      key: _pinHashKey,
      value: jsonEncode({
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
      }),
    );
    await _storage.delete(key: 'pin_failures');
    await _storage.delete(key: 'pin_locked_until');
  }

  Future<int> pinCooldownSeconds() async {
    final until = DateTime.tryParse(
      await _storage.read(key: 'pin_locked_until') ?? '',
    );
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining + 1 : 0;
  }

  Future<bool> verifyPin(String pin) async {
    if (await pinCooldownSeconds() > 0) return false;
    final stored = await _storage.read(key: _pinHashKey);
    if (stored == null) return false;
    bool ok;
    if (stored.startsWith('{')) {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      final salt = base64Decode(data['salt'] as String);
      final expected = base64Decode(data['hash'] as String);
      final actual = await _derivePinHash(pin, salt);
      var difference = expected.length ^ actual.length;
      for (var i = 0; i < expected.length && i < actual.length; i++) {
        difference |= expected[i] ^ actual[i];
      }
      ok = difference == 0;
    } else {
      ok = stored == _hash(pin);
      if (ok)
        await setPin(
          pin,
        ); // Migrate old PIN only after successful verification.
    }
    if (ok) {
      await _storage.delete(key: 'pin_failures');
      await _storage.delete(key: 'pin_locked_until');
    } else {
      final attempts =
          (int.tryParse(await _storage.read(key: 'pin_failures') ?? '') ?? 0) +
          1;
      await _storage.write(key: 'pin_failures', value: '$attempts');
      if (attempts >= 5) {
        await _storage.write(
          key: 'pin_locked_until',
          value: DateTime.now()
              .add(const Duration(seconds: 60))
              .toIso8601String(),
        );
        await _storage.write(key: 'pin_failures', value: '0');
      }
    }
    return ok;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: 'pin_failures');
    await _storage.delete(key: 'pin_locked_until');
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock ShopHisab',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
