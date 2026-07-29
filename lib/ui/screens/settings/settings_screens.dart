import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import '../business_setup_screen.dart';
import '../pin_screens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
                  Text(profile.businessName, style: Theme.of(context).textTheme.headlineSmall),
                  Text(profile.ownerName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        builder: (_) => BusinessSetupScreen(existing: profile))),
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
                          onTap: () => Navigator.pop(ctx, ThemeMode.light)),
                      ListTile(
                          title: const Text('Dark'), onTap: () => Navigator.pop(ctx, ThemeMode.dark)),
                      ListTile(
                          title: const Text('Follow system'),
                          onTap: () => Navigator.pop(ctx, ThemeMode.system)),
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
                      context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
                  ref.invalidate(hasPinProvider);
                } else {
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove PIN lock?'),
                          content:
                              const Text('Anyone who opens the app will see your business data.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove')),
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
                    context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
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
                context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())),
          ),
          const Divider(),
          const _SectionLabel('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('BusinessOS v1.0'),
            subtitle: Text(
                'Your Shop. Your Data. Always Available.\nWorks fully offline - no account, no server, no ads.'),
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
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;

  Future<String?> _askPassphrase({required String title, required String message}) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN / passphrase'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    return result;
  }

  Future<void> _export() async {
    final hasPin = await ref.read(authRepositoryProvider).hasPin();
    final passphrase = await _askPassphrase(
      title: 'Secure your backup',
      message: hasPin
          ? 'Enter your app PIN. You will need it to restore this backup.'
          : 'You have not set a PIN. Enter a passphrase to encrypt this backup - remember it, you will need it to restore.',
    );
    if (passphrase == null) return;

    setState(() => _busy = true);
    try {
      final file = await ref.read(backupRepositoryProvider).exportEncrypted(passphrase: passphrase);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'BusinessOS Backup',
          text: 'BusinessOS encrypted backup - keep this file and your passphrase safe.',
        ),
      );
      if (mounted) showSuccessSnack(context, 'Backup created');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore backup?'),
            content: const Text(
                'This will replace ALL current data on this phone with the data from the backup file. This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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

    final passphrase = await _askPassphrase(
      title: 'Enter backup passphrase',
      message: 'Enter the PIN or passphrase you used when this backup was created.',
    );
    if (passphrase == null) return;

    setState(() => _busy = true);
    try {
      final backupFile = File(result.files.single.path!);
      await ref
          .read(backupRepositoryProvider)
          .restoreEncrypted(backupFile, passphrase: passphrase);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text(
              'Please close BusinessOS completely and reopen it to load the restored data.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Backups are AES-256 encrypted and stored only where you choose to save or share them. BusinessOS never uploads your data automatically.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
