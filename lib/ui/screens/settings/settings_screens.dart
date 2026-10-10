import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/formatters.dart';
import '../../../providers/app_providers.dart';
import '../../../services/google_drive_service.dart';
import '../../widgets/common_widgets.dart';
import '../business_setup_screen.dart';
import '../splash_screen.dart';
import '../pin_screens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    final firstStep = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch business / reset app?'),
        content: const Text(
          'This permanently deletes everything on this phone: customers, ledger, '
          'products, invoices, and notes. There is no undo unless you have a backup.\n\n'
          'If you don\'t already have one, back it up first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'backup'),
            child: const Text('Back Up First'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstStep == 'backup') {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
        );
      }
      return;
    }
    if (firstStep != 'continue') return;
    if (!context.mounted) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'All business data on this phone will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );
    if (finalConfirm != true) return;
    if (!context.mounted) return;

    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.delete(db.invoiceItems).go();
      await db.delete(db.ledgerEntries).go();
      await db.delete(db.invoices).go();
      await db.delete(db.customers).go();
      await db.delete(db.products).go();
      await db.delete(db.notes).go();
      await db.delete(db.businessProfiles).go();
    });
    await ref.read(authRepositoryProvider).clearPin();
    await ref.read(authRepositoryProvider).clearBackupPassphrases();
    await ref.read(lastBackupProvider.notifier).clear();
    ref.invalidate(hasPinProvider);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final hasPinAsync = ref.watch(hasPinProvider);
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.businessName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    profile.ownerName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          const _SectionLabel('Business'),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Edit business profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: profile == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessSetupScreen(existing: profile),
                    ),
                  ),
          ),
          const Divider(),
          const _SectionLabel('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(switch (themeMode) {
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
              ThemeMode.system => 'Follow system',
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final mode = await showModalBottomSheet<ThemeMode>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('Light'),
                        onTap: () => Navigator.pop(ctx, ThemeMode.light),
                      ),
                      ListTile(
                        title: const Text('Dark'),
                        onTap: () => Navigator.pop(ctx, ThemeMode.dark),
                      ),
                      ListTile(
                        title: const Text('Follow system'),
                        onTap: () => Navigator.pop(ctx, ThemeMode.system),
                      ),
                    ],
                  ),
                ),
              );
              if (mode != null) {
                await ref.read(themeModeProvider.notifier).setMode(mode);
              }
            },
          ),
          const Divider(),
          const _SectionLabel('Security'),
          hasPinAsync.when(
            loading: () => const ListTile(title: Text('Loading...')),
            error: (e, _) => ListTile(title: Text('Error: $e')),
            data: (hasPin) => SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('PIN lock'),
              subtitle: Text(hasPin ? 'Enabled - tap to change' : 'Disabled'),
              value: hasPin,
              onChanged: (enable) async {
                if (enable) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                  );
                  ref.invalidate(hasPinProvider);
                } else {
                  final confirmed =
                      await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove PIN lock?'),
                          content: const Text(
                            'Anyone who opens the app will see your business data.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (confirmed) {
                    await ref.read(authRepositoryProvider).clearPin();
                    ref.invalidate(hasPinProvider);
                  }
                }
              },
            ),
          ),
          if (hasPinAsync.valueOrNull == true)
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                );
                ref.invalidate(hasPinProvider);
              },
            ),
          const Divider(),
          const _SectionLabel('Data'),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Encrypted local backup - no cloud required'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
            ),
          ),
          const Divider(),
          const _SectionLabel('Danger zone'),
          ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Switch business / Reset app',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text(
              'There\'s no account to "log out" of - this clears all data on this phone so you can set up a different business, or hand the phone to someone else',
            ),
            isThreeLine: true,
            onTap: () => _resetApp(context, ref),
          ),
          const Divider(),
          const _SectionLabel('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ShopHisab v1.9'),
            subtitle: const Text(
              'Your Shop. Your Data. Always Available.\nWorks fully offline for everyday use - no account needed. Optional Google Drive backup available if you connect it.',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BACKUP & RESTORE
// ---------------------------------------------------------------------------

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key, this.autoOpenCloudRestore = false});

  /// Used only from first-run onboarding. When true, the screen immediately
  /// connects to Google Drive and loads the user's existing cloud backups,
  /// so a fresh install can discover an old backup before a local business
  /// profile exists. Normal Settings usage keeps the existing manual flow.
  final bool autoOpenCloudRestore;

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;
  GoogleSignInAccount? _driveAccount;
  static const _usePassphraseKey = 'backup_use_own_passphrase_v1';
  // Off by default: backups run in one tap. When on, the user chooses their
  // own passphrase for every new backup (needed again to restore).
  bool _usePassphrase = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _usePassphrase = prefs.getBool(_usePassphraseKey) ?? false);
      }
    });
    if (widget.autoOpenCloudRestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreFromDrive();
      });
    }
  }

  Future<String?> _askPassphrase({
    required String title,
    required String message,
    bool allowBiometric = false,
    String? backupKey,
    bool newBackup = false,
  }) async {
    final ctrl = TextEditingController();
    final auth = ref.read(authRepositoryProvider);
    final biometricAvailable =
        allowBiometric &&
        await auth.canUseBiometrics() &&
        await auth.getBackupPassphrase(backupKey) != null;

    if (!mounted) {
      ctrl.dispose();
      return null;
    }
    final confirm = TextEditingController();
    String? error;
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Backup passphrase',
                      errorText: error,
                    ),
                    autofocus: !biometricAvailable,
                  ),
                  if (newBackup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm passphrase',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (biometricAvailable)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await auth.authenticateBiometric();
                    if (!ctx.mounted || !ok) return;
                    final saved = await auth.getBackupPassphrase(backupKey);
                    if (!ctx.mounted) return;
                    if (saved != null && saved.isNotEmpty) {
                      Navigator.pop(ctx, saved);
                    }
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use biometric'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (newBackup && ctrl.text.trim().length < 10) {
                    update(() => error = 'Use at least 10 characters.');
                    return;
                  }
                  if (newBackup && ctrl.text != confirm.text) {
                    update(() => error = 'Passphrases do not match.');
                    return;
                  }
                  Navigator.pop(ctx, ctrl.text);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
      return result;
    } finally {
      ctrl.dispose();
      confirm.dispose();
    }
  }

  /// Passphrase for a NEW backup. Returns '' (no passphrase) unless the user
  /// switched on "Protect backups with my own passphrase"; null = cancelled.
  Future<String?> _passphraseForNewBackup(String title) async {
    if (!_usePassphrase) return '';
    return _askPassphrase(
      title: title,
      message:
          'Choose a passphrase of at least 10 characters. Keep it safe: it is needed to restore and cannot be recovered.',
      newBackup: true,
    );
  }

  /// Restores [file]. Tries one-tap restore first; only if the backup was
  /// protected with a personal passphrase does it ask for it.
  /// Returns true when the data was restored.
  Future<bool> _restoreFileSmart(File file, String backupKey) async {
    final repo = ref.read(backupRepositoryProvider);
    try {
      await repo.restoreEncrypted(file, passphrase: '');
      return true;
    } on FormatException catch (e) {
      if (!e.message.contains('Wrong passphrase')) rethrow;
    }
    final passphrase = await _askPassphrase(
      title: 'Enter backup passphrase',
      message:
          'This backup is protected with a passphrase. Enter the passphrase you chose when you created it.',
      allowBiometric: true,
      backupKey: backupKey,
    );
    if (passphrase == null || !mounted) return false;
    await repo.restoreEncrypted(file, passphrase: passphrase);
    return true;
  }

  Future<void> _finishRestore() async {
    await ref.read(lastBackupProvider.notifier).clear();
    final profile = await ref.read(businessRepositoryProvider).getProfile();
    AppFormatters.currencyCode = profile?.currencyCode ?? 'INR';
    ref.read(appLockedProvider.notifier).state = true;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    final passphrase = await _passphraseForNewBackup('Secure your backup');
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final file = await ref
          .read(backupRepositoryProvider)
          .exportEncrypted(passphrase: passphrase);
      if (passphrase.isNotEmpty) {
        await ref
            .read(authRepositoryProvider)
            .saveBackupPassphrase(p.basename(file.path), passphrase);
      }
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'ShopHisab Backup',
          text: 'ShopHisab encrypted backup - keep this file safe.',
        ),
      );
      if (shareResult.status == ShareResultStatus.success) {
        await ref.read(lastBackupProvider.notifier).markBackedUpNow();
        if (mounted)
          showSuccessSnack(
            context,
            passphrase.isEmpty
                ? 'Backup shared. Keep the file safe.'
                : 'Backup shared. Keep the file and passphrase safe.',
          );
      } else if (mounted) {
        showSuccessSnack(
          context,
          'Backup created, but saving was not confirmed. Export again to keep a copy.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore backup?'),
            content: const Text(
              'This will replace ALL current data on this phone with the data from the backup file. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    setState(() => _busy = true);
    try {
      final backupFile = File(result.files.single.path!);
      final restored = await _restoreFileSmart(
        backupFile,
        p.basename(backupFile.path),
      );
      if (!restored || !mounted) return;
      await _finishRestore();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _connectDrive() async {
    setState(() => _busy = true);
    try {
      final signIn = await ref.read(googleSignInProvider.future);
      final account = await ref.read(googleDriveServiceProvider).signIn(signIn);
      if (!mounted) return false;
      setState(() => _driveAccount = account);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to Google Drive: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectDrive() async {
    setState(() => _busy = true);
    try {
      final signIn = await ref.read(googleSignInProvider.future);
      await ref.read(googleDriveServiceProvider).signOut(signIn);
      if (mounted) setState(() => _driveAccount = null);
    } catch (_) {
      if (mounted)
        showSuccessSnack(context, 'Could not disconnect. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupToDrive() async {
    if (_driveAccount == null && !await _connectDrive()) return;

    if (_busy) return;
    final passphrase = await _passphraseForNewBackup('Secure your Drive backup');
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final file = await ref
          .read(backupRepositoryProvider)
          .exportEncrypted(passphrase: passphrase);
      final bytes = await file.readAsBytes();
      final fileName =
          'shophisab_backup_${AppFormatters.fileTimestamp(DateTime.now())}.bosb';
      await ref
          .read(googleDriveServiceProvider)
          .uploadBackup(
            account: _driveAccount!,
            fileBytes: bytes,
            fileName: fileName,
          );
      if (passphrase.isNotEmpty) {
        await ref
            .read(authRepositoryProvider)
            .saveBackupPassphrase(fileName, passphrase);
      }
      if (mounted) showSuccessSnack(context, 'Backed up to Google Drive');
      await ref.read(lastBackupProvider.notifier).markBackedUpNow();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Drive backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    if (_driveAccount == null && !await _connectDrive()) return;

    setState(() => _busy = true);
    List<DriveBackupFile> backups = [];
    try {
      backups = await ref
          .read(googleDriveServiceProvider)
          .listBackups(_driveAccount!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not list Drive backups: $e')),
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backups found in Google Drive yet.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<DriveBackupFile>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: backups
              .map(
                (b) => ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(b.name),
                  subtitle: Text(AppFormatters.dateTimeStr(b.createdTime)),
                  onTap: () => Navigator.pop(ctx, b),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore this backup?'),
            content: Text(
              'This replaces ALL current data on this phone with "${picked.name}". This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(googleDriveServiceProvider)
          .downloadBackup(account: _driveAccount!, fileId: picked.id);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'drive_restore_temp.bosb'));
      await tempFile.writeAsBytes(bytes);
      bool restored;
      try {
        restored = await _restoreFileSmart(tempFile, picked.name);
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
      if (!restored || !mounted) return;
      await _finishRestore();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Drive restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: PopScope(
        canPop: !_busy,
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Backups are AES-256 encrypted. Nothing leaves this phone unless you explicitly tap Share or connect Google Drive below - ShopHisab never uploads anything automatically.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your PIN, biometric settings, theme and language stay on this device. Backups contain your business records. A restore replaces records; it does not merge devices.',
              ),
              const SizedBox(height: 8),
              ref
                  .watch(lastBackupProvider)
                  .when(
                    data: (date) => Text(
                      date == null
                          ? 'No confirmed backup on this device'
                          : 'Last confirmed backup: ${AppFormatters.dateTimeStr(date)}',
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Protect backups with my own passphrase'),
                subtitle: Text(
                  _usePassphrase
                      ? 'On: you choose a passphrase for each backup and need it to restore. It cannot be recovered if forgotten.'
                      : 'Off: backup and restore work in one tap. Drive backups stay in your private Google Drive app folder.',
                ),
                value: _usePassphrase,
                onChanged: _busy
                    ? null
                    : (v) async {
                        setState(() => _usePassphrase = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_usePassphraseKey, v);
                      },
              ),
              SectionHeader('Local backup'),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Export encrypted backup'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Restore from backup file'),
              ),
              SectionHeader('Cloud backup (Google Drive)'),
              if (_driveAccount == null) ...[
                Text(
                  'Optional. Connects only to a private space this app creates in your Drive - it can never see your other files.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _connectDrive,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Connect Google Drive'),
                ),
              ] else ...[
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: Text(_driveAccount!.email),
                    subtitle: const Text('Connected'),
                    trailing: TextButton(
                      onPressed: _busy ? null : _disconnectDrive,
                      child: const Text('Disconnect'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _backupToDrive,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Backup to Google Drive'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restoreFromDrive,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Restore from Google Drive'),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
