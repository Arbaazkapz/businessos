import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'main_shell.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final auth = ref.read(authRepositoryProvider);
    if (await auth.canUseBiometrics()) {
      final ok = await auth.authenticateBiometric();
      if (ok) _unlock();
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await ref.read(authRepositoryProvider).verifyPin(_pinCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _checking = false;
      });
      _pinCtrl.clear();
    }
  }

  void _unlock() {
    ref.read(appLockedProvider.notifier).state = false;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 48, color: scheme.primary),
                const SizedBox(height: 16),
                Text('Enter PIN', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 12),
                  decoration: InputDecoration(errorText: _error, counterText: ''),
                  onSubmitted: (_) => _submitPin(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _checking ? null : _submitPin,
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Unlock'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use fingerprint / face unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Used from Settings to turn on (or change) the PIN lock.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    if (_pinCtrl.text.trim().length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    if (_pinCtrl.text.trim() != _confirmCtrl.text.trim()) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(authRepositoryProvider).setPin(_pinCtrl.text.trim());
    if (!mounted) return;
    showSuccessSnack(context, 'PIN saved');
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN lock')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose a 4-6 digit PIN to lock BusinessOS.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(labelText: 'New PIN'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(labelText: 'Confirm PIN', errorText: _error),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
