import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import '../core/formatters.dart';

const _uuid = Uuid();

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
  }) {
    return _db.into(_db.businessProfiles).insert(BusinessProfilesCompanion.insert(
          businessName: businessName,
          ownerName: ownerName,
          phone: Value(phone),
          address: Value(address),
          gstNumber: Value(gstNumber),
          category: Value(category),
        ));
  }

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
    return (_db.update(_db.businessProfiles)..where((t) => t.id.equals(profile.id))).write(
      BusinessProfilesCompanion(
        businessName: businessName != null ? Value(businessName) : const Value.absent(),
        ownerName: ownerName != null ? Value(ownerName) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        gstNumber: gstNumber != null ? Value(gstNumber) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        invoicePrefix: invoicePrefix != null ? Value(invoicePrefix) : const Value.absent(),
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
      final number = '${profile.invoicePrefix}-${profile.nextInvoiceSeq.toString().padLeft(4, '0')}';
      await (_db.update(_db.businessProfiles)..where((t) => t.id.equals(profile.id))).write(
        BusinessProfilesCompanion(nextInvoiceSeq: Value(profile.nextInvoiceSeq + 1)),
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

  Stream<List<Customer>> watchAll() =>
      (_db.select(_db.customers)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Customer?> getById(String id) =>
      (_db.select(_db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    String phone = '',
    String address = '',
    String? gstNumber,
    double? creditLimit,
    String notes = '',
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: name,
          phone: Value(phone),
          address: Value(address),
          gstNumber: Value(gstNumber),
          creditLimit: Value(creditLimit),
          notes: Value(notes),
        ));
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    String? phone,
    String? address,
    String? gstNumber,
    double? creditLimit,
    String? notes,
    bool? isFavourite,
    bool? isBlocked,
  }) {
    return (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        gstNumber: gstNumber != null ? Value(gstNumber) : const Value.absent(),
        creditLimit: creditLimit != null ? Value(creditLimit) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        isFavourite: isFavourite != null ? Value(isFavourite) : const Value.absent(),
        isBlocked: isBlocked != null ? Value(isBlocked) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
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
    final id = _uuid.v4();
    await _db.into(_db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: id,
          customerId: customerId,
          type: type,
          amount: amount,
          note: Value(note),
          entryDate: entryDate ?? DateTime.now(),
          linkedInvoiceId: Value(linkedInvoiceId),
        ));
    return id;
  }

  Future<void> updateEntry(String id, {double? amount, String? note, DateTime? entryDate}) {
    return (_db.update(_db.ledgerEntries)..where((t) => t.id.equals(id))).write(
      LedgerEntriesCompanion(
        amount: amount != null ? Value(amount) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        entryDate: entryDate != null ? Value(entryDate) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteEntry(String id) =>
      (_db.delete(_db.ledgerEntries)..where((t) => t.id.equals(id))).go();

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
        .where((e) =>
            e.type == type &&
            e.entryDate.year == now.year &&
            e.entryDate.month == now.month &&
            e.entryDate.day == now.day)
        .fold(0.0, (a, b) => a + b.amount);
  }

  /// Sum of every customer's positive balance ("money to receive" on the dashboard).
  static double totalReceivable(Iterable<LedgerEntry> entries) {
    final Map<String, double> perCustomer = {};
    for (final e in entries) {
      final delta = e.type == LedgerEntryType.creditGiven ? e.amount : -e.amount;
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

  Stream<List<Product>> watchAll() =>
      (_db.select(_db.products)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Product?> getById(String id) =>
      (_db.select(_db.products)..where((t) => t.id.equals(id))).getSingleOrNull();

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
    final id = _uuid.v4();
    await _db.into(_db.products).insert(ProductsCompanion.insert(
          id: id,
          name: name,
          category: Value(category),
          barcode: Value(barcode),
          purchasePrice: Value(purchasePrice),
          sellingPrice: Value(sellingPrice),
          stockQty: Value(stockQty),
          lowStockThreshold: Value(lowStockThreshold),
          unit: Value(unit),
        ));
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
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        barcode: barcode != null ? Value(barcode) : const Value.absent(),
        purchasePrice: purchasePrice != null ? Value(purchasePrice) : const Value.absent(),
        sellingPrice: sellingPrice != null ? Value(sellingPrice) : const Value.absent(),
        stockQty: stockQty != null ? Value(stockQty) : const Value.absent(),
        lowStockThreshold:
            lowStockThreshold != null ? Value(lowStockThreshold) : const Value.absent(),
        unit: unit != null ? Value(unit) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();

  Future<void> adjustStock(String id, double delta) async {
    final product = await getById(id);
    if (product == null) return;
    await update(id, stockQty: product.stockQty + delta);
  }

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
  double get lineTotal => qty * unitPrice;
}

class InvoiceRepository {
  InvoiceRepository(this._db, this._business, this._products, this._ledger);
  final AppDatabase _db;
  final BusinessRepository _business;
  final ProductRepository _products;
  final LedgerRepository _ledger;

  Stream<List<Invoice>> watchAll() =>
      (_db.select(_db.invoices)..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)])).watch();

  Future<Invoice?> getById(String id) =>
      (_db.select(_db.invoices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceItem>> itemsFor(String invoiceId) =>
      (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();

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
    final invoiceId = _uuid.v4();
    final invoiceNumber = await _business.nextInvoiceNumber();
    final subtotal = lines.fold<double>(0, (a, l) => a + l.lineTotal);
    final afterDiscount = subtotal - discount < 0 ? 0.0 : subtotal - discount;
    final taxAmount = afterDiscount * (taxPercent / 100);
    final total = afterDiscount + taxAmount;
    final amountPaid = switch (status) {
      InvoiceStatus.paid => total,
      InvoiceStatus.partial => amountPaidNow.clamp(0, total),
      InvoiceStatus.unpaid => 0.0,
    };

    await _db.transaction(() async {
      await _db.into(_db.invoices).insert(InvoicesCompanion.insert(
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
            status: status,
            notes: Value(notes),
          ));

      for (final line in lines) {
        await _db.into(_db.invoiceItems).insert(InvoiceItemsCompanion.insert(
              id: _uuid.v4(),
              invoiceId: invoiceId,
              productId: Value(line.productId),
              description: line.description,
              qty: line.qty,
              unitPrice: line.unitPrice,
              lineTotal: line.lineTotal,
            ));
        if (line.productId != null) {
          await _products.adjustStock(line.productId!, -line.qty);
        }
      }

      if (customerId != null && postToLedger) {
        if (status == InvoiceStatus.unpaid) {
          await _ledger.addEntry(
            customerId: customerId,
            type: LedgerEntryType.creditGiven,
            amount: total,
            note: 'Invoice $invoiceNumber',
            linkedInvoiceId: invoiceId,
          );
        } else if (status == InvoiceStatus.partial) {
          await _ledger.addEntry(
            customerId: customerId,
            type: LedgerEntryType.creditGiven,
            amount: total,
            note: 'Invoice $invoiceNumber',
            linkedInvoiceId: invoiceId,
          );
          if (amountPaidNow > 0) {
            await _ledger.addEntry(
              customerId: customerId,
              type: LedgerEntryType.paymentReceived,
              amount: amountPaidNow,
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
// BACKUP & RESTORE (fully local, AES-256 encrypted, no cloud involved)
// ---------------------------------------------------------------------------

class BackupRepository {
  BackupRepository(this._db);
  final AppDatabase _db;

  Future<File> exportEncrypted({required String passphrase}) async {
    await _db.customStatement('PRAGMA wal_checkpoint(FULL);');
    final dbFile = await AppDatabase.resolveDbFile();
    final rawBytes = await dbFile.readAsBytes();

    final key = _deriveKey(passphrase);
    final random = Random.secure();
    final iv = enc.IV(Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256))));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(rawBytes, iv: iv);

    final tempDir = await getTemporaryDirectory();
    final stamp = AppFormatters.fileTimestamp(DateTime.now());
    final outFile = File(p.join(tempDir.path, 'businessos_backup_$stamp.bosb'));
    await outFile.writeAsBytes([...iv.bytes, ...encrypted.bytes], flush: true);
    return outFile;
  }

  /// Overwrites the live database with a decrypted backup. The caller MUST
  /// prompt the user to fully restart the app afterwards - the db connection
  /// is closed here and cannot safely be reopened mid-session.
  Future<void> restoreEncrypted(File backupFile, {required String passphrase}) async {
    final all = await backupFile.readAsBytes();
    if (all.length <= 16) {
      throw const FormatException('Backup file is invalid or corrupted.');
    }
    final ivBytes = Uint8List.fromList(all.sublist(0, 16));
    final cipherBytes = Uint8List.fromList(all.sublist(16));
    final key = _deriveKey(passphrase);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    late final List<int> decrypted;
    try {
      decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    } catch (_) {
      throw const FormatException(
          'Could not decrypt backup. Wrong PIN/passphrase, or the file is corrupted.');
    }

    await _db.close();
    final dbFile = await AppDatabase.resolveDbFile();
    await dbFile.writeAsBytes(decrypted, flush: true);
  }

  enc.Key _deriveKey(String passphrase) {
    final normalized = passphrase.isEmpty ? 'businessos-default-passphrase-v1' : passphrase;
    final digest = sha256.convert(utf8.encode(normalized));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }
}

// ---------------------------------------------------------------------------
// SECURITY: PIN lock + biometric unlock
// ---------------------------------------------------------------------------

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  static const _pinHashKey = 'businessos_pin_hash_v1';

  String _hash(String pin) => sha256.convert(utf8.encode('pin-salt-v1:$pin')).toString();

  Future<bool> hasPin() async => (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) => _storage.write(key: _pinHashKey, value: _hash(pin));

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    return stored != null && stored == _hash(pin);
  }

  Future<void> clearPin() => _storage.delete(key: _pinHashKey);

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
        localizedReason: 'Unlock BusinessOS',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
