import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'main_shell.dart';

const _categories = [
  'General Store / Kirana',
  'Medical Store',
  'Stationery Shop',
  'Tea Stall',
  'Restaurant',
  'Hardware Store',
  'Tailor',
  'Garage',
  'Wholesaler',
  'Freelancer',
  'Other',
];

/// Used both for first-run onboarding (no [existing] profile - creates one
/// and drops into the app) and for editing an existing profile from
/// Settings (pass [existing] - updates in place and pops back).
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key, this.existing});

  final BusinessProfile? existing;

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstCtrl;
  late String _category;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _businessNameCtrl = TextEditingController(text: p?.businessName ?? '');
    _ownerNameCtrl = TextEditingController(text: p?.ownerName ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _gstCtrl = TextEditingController(text: p?.gstNumber ?? '');
    _category = p?.category ?? _categories.first;
    if (!_categories.contains(_category)) _category = _categories.last;
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(businessRepositoryProvider);
    try {
      if (_isEditing) {
        await repo.updateProfile(
          widget.existing!,
          businessName: _businessNameCtrl.text.trim(),
          ownerName: _ownerNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
          category: _category,
        );
        if (!mounted) return;
        showSuccessSnack(context, 'Business profile updated');
        Navigator.of(context).pop();
      } else {
        await repo.createProfile(
          businessName: _businessNameCtrl.text.trim(),
          ownerName: _ownerNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
          category: _category,
        );
        ref.read(appLockedProvider.notifier).state = false;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          if (!_isEditing) ...[
            Icon(Icons.storefront_rounded, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Set up your shop', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'No account, no OTP, no internet needed. Everything is saved on this phone.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
          ],
          TextFormField(
            controller: _businessNameCtrl,
            decoration: const InputDecoration(labelText: 'Business name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ownerNameCtrl,
            decoration: const InputDecoration(labelText: 'Owner name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone number'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Shop address'),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _gstCtrl,
            decoration: const InputDecoration(labelText: 'GSTIN (optional)'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Business type'),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Start using BusinessOS'),
          ),
        ],
      ),
    );

    if (_isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Business Profile')),
        body: form,
      );
    }
    return Scaffold(body: SafeArea(child: form));
  }
}
