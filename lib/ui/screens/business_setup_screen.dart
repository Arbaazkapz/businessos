import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/country_codes.dart';
import '../../data/app_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'main_shell.dart';
import 'settings/settings_screens.dart';

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

// Longest dial codes first, so parsing an existing stored number (e.g.
// matching Trinidad's "+1868" rather than stopping early at Canada's "+1")
// picks the most specific match.
final List<CountryCode> _codesByLengthDesc = List.of(countryCodes)
  ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

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
  late CountryCode _country;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _businessNameCtrl = TextEditingController(text: p?.businessName ?? '');
    _ownerNameCtrl = TextEditingController(text: p?.ownerName ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _gstCtrl = TextEditingController(text: p?.gstNumber ?? '');
    _category = p?.category ?? _categories.first;
    if (!_categories.contains(_category)) _category = _categories.last;

    // Try to split a previously-stored phone number ("+91 98765...") back
    // into country code + local number. Falls back to India + the raw
    // stored value untouched if nothing matches (e.g. older data saved
    // before this field existed) - never loses data either way.
    final storedPhone = p?.phone.trim() ?? '';
    CountryCode? matched;
    String localNumber = storedPhone;
    for (final c in _codesByLengthDesc) {
      if (storedPhone.startsWith(c.dialCode)) {
        matched = c;
        localNumber = storedPhone.substring(c.dialCode.length).trim();
        break;
      }
    }
    _country = matched ?? countryCodes.first; // India
    _phoneCtrl = TextEditingController(text: localNumber);
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

  String? _validatePhone(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null; // optional field
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 12) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateGst(String? v) {
    final text = v?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return null; // optional field
    final pattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!pattern.hasMatch(text)) {
      return 'GSTIN should look like 27ABCDE1234F1Z5';
    }
    return null;
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CountryPickerSheet(current: _country),
    );
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(businessRepositoryProvider);
    final phoneText = _phoneCtrl.text.trim();
    final fullPhone = phoneText.isEmpty ? '' : '${_country.dialCode} $phoneText';
    try {
      if (_isEditing) {
        await repo.updateProfile(
          widget.existing!,
          businessName: _businessNameCtrl.text.trim(),
          ownerName: _ownerNameCtrl.text.trim(),
          phone: fullPhone,
          address: _addressCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase(),
          category: _category,
        );
        if (!mounted) return;
        showSuccessSnack(context, 'Business profile updated');
        Navigator.of(context).pop();
      } else {
        await repo.createProfile(
          businessName: _businessNameCtrl.text.trim(),
          ownerName: _ownerNameCtrl.text.trim(),
          phone: fullPhone,
          address: _addressCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase(),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickCountry,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Code'),
                    child: Text('${_country.iso}  ${_country.dialCode}',
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
              ),
            ],
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
            validator: _validateGst,
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
                : Text(_isEditing ? 'Save Changes' : 'Start using ShopHisab'),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                      ),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Already have a backup? Restore old data'),
            ),
          ],
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

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.current});
  final CountryCode current;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? countryCodes
        : countryCodes
            .where((c) =>
                c.name.toLowerCase().contains(_query) ||
                c.dialCode.contains(_query) ||
                c.iso.toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final selected = c.iso == widget.current.iso;
                  return ListTile(
                    title: Text(c.name),
                    trailing: Text(c.dialCode,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    selected: selected,
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
