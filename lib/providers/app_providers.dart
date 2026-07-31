import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_strings.dart';
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

final noteRepositoryProvider = Provider((ref) => NoteRepository(ref.watch(databaseProvider)));

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

final notesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchAll();
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

// ---------------------------------------------------------------------------
// LANGUAGE (persisted, same pattern as theme mode)
// ---------------------------------------------------------------------------

class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.en) {
    _load();
  }

  static const _key = 'app_locale_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    state = saved == 'hi' ? AppLocale.hi : AppLocale.en;
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale == AppLocale.hi ? 'hi' : 'en');
  }

  Future<void> toggle() => setLocale(state == AppLocale.en ? AppLocale.hi : AppLocale.en);
}

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) => LocaleNotifier());

final appStringsProvider = Provider<AppStrings>((ref) => AppStrings(ref.watch(localeProvider)));

// ---------------------------------------------------------------------------
// BACKUP REMINDER TRACKING (used by the notifications bell)
// ---------------------------------------------------------------------------

class LastBackupNotifier extends StateNotifier<AsyncValue<DateTime?>> {
  LastBackupNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _key = 'last_backup_at_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_key);
    state = AsyncValue.data(iso != null ? DateTime.tryParse(iso) : null);
  }

  Future<void> markBackedUpNow() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, now.toIso8601String());
    state = AsyncValue.data(now);
  }
}

final lastBackupProvider =
    StateNotifierProvider<LastBackupNotifier, AsyncValue<DateTime?>>((ref) => LastBackupNotifier());
