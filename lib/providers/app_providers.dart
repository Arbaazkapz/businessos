import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/repositories.dart';

// ---------------------------------------------------------------------------
// DATABASE + REPOSITORIES
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final businessRepositoryProvider =
    Provider((ref) => BusinessRepository(ref.watch(databaseProvider)));

final customerRepositoryProvider =
    Provider((ref) => CustomerRepository(ref.watch(databaseProvider)));

final ledgerRepositoryProvider =
    Provider((ref) => LedgerRepository(ref.watch(databaseProvider)));

final productRepositoryProvider =
    Provider((ref) => ProductRepository(ref.watch(databaseProvider)));

final invoiceRepositoryProvider = Provider((ref) => InvoiceRepository(
      ref.watch(databaseProvider),
      ref.watch(businessRepositoryProvider),
      ref.watch(productRepositoryProvider),
      ref.watch(ledgerRepositoryProvider),
    ));

final backupRepositoryProvider =
    Provider((ref) => BackupRepository(ref.watch(databaseProvider)));

final authRepositoryProvider = Provider((ref) => AuthRepository());

// ---------------------------------------------------------------------------
// REACTIVE DATA STREAMS - UI rebuilds automatically whenever the local
// SQLite database changes, with zero manual refresh logic anywhere.
// ---------------------------------------------------------------------------

final businessProfileProvider = StreamProvider<BusinessProfile?>((ref) {
  return ref.watch(businessRepositoryProvider).watchProfile();
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAll();
});

final allLedgerEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAll();
});

final ledgerForCustomerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) {
  return ref.watch(ledgerRepositoryProvider).watchForCustomer(customerId);
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

final invoicesProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchAll();
});

// ---------------------------------------------------------------------------
// APP SETTINGS: theme mode (persisted) + lock-screen state (session only)
// ---------------------------------------------------------------------------

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    switch (saved) {
      case 'light':
        state = ThemeMode.light;
      case 'dark':
        state = ThemeMode.dark;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// True while the PIN/biometric lock screen should be blocking the UI.
/// Re-evaluated once at cold start in SplashScreen; flips to false after a
/// successful unlock for the remainder of the session.
final appLockedProvider = StateProvider<bool>((ref) => true);

final hasPinProvider = FutureProvider<bool>((ref) => ref.watch(authRepositoryProvider).hasPin());
