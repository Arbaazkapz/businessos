import '../../../core/validation.dart';
import '../../../core/formatters.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import 'contact_import_screen.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  const AddEditCustomerScreen({super.key, this.existing});

  final Customer? existing;

  @override
  ConsumerState<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _creditLimitCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _gstCtrl = TextEditingController(text: e?.gstNumber ?? '');
    _creditLimitCtrl = TextEditingController(
      text: e?.creditLimit?.toString() ?? '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _creditLimitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(customerRepositoryProvider);
    final creditLimit = double.tryParse(_creditLimitCtrl.text.trim());
    try {
      final String customerId;
      if (_isEditing) {
        customerId = widget.existing!.id;
        await repo.update(
          customerId,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
          creditLimit: creditLimit,
          clearCreditLimit: _creditLimitCtrl.text.trim().isEmpty,
          notes: _notesCtrl.text.trim(),
        );
      } else {
        customerId = await repo.create(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
          creditLimit: creditLimit,
          notes: _notesCtrl.text.trim(),
        );
      }
      // Read the record straight back from the database (not the reactive
      // stream, which may not have re-emitted yet) so the caller gets a
      // guaranteed-fresh Customer immediately, with no race condition.
      final saved = await repo.getById(customerId);
      if (!mounted) return;
      showSuccessSnack(
        context,
        _isEditing ? 'Customer updated' : 'Customer added',
      );
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importFromContacts() async {
    final imported = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const ContactImportScreen()),
    );
    // Contacts were saved as customers: this form is no longer needed.
    if (imported != null && imported > 0 && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          children: [
            if (!_isEditing) ...[
              OutlinedButton.icon(
                onPressed: _saving ? null : _importFromContacts,
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('Import from contacts'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name *'),
              validator: (v) =>
                  AppValidation.personName(v, label: 'Customer name'),
              inputFormatters: [personNameFormatter],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              validator: (v) => AppValidation.phone(v),
              inputFormatters: [PhoneInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Phone number (optional)',
                helperText:
                    'Not required. India: 10 digits. International: +country code.',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (v) =>
                  AppValidation.optionalText(v, label: 'Address', max: 250),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _gstCtrl,
              validator: (v) => AppValidation.taxId(
                v,
                india: AppFormatters.currencyCode == 'INR',
              ),
              decoration: InputDecoration(
                labelText: AppFormatters.currencyCode == 'INR'
                    ? 'GSTIN (optional)'
                    : 'Tax ID (optional)',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _creditLimitCtrl,
              inputFormatters: [DecimalInputFormatter()],
              validator: (v) => AppValidation.number(
                v,
                label: 'Credit limit',
                optional: true,
              ),
              decoration: InputDecoration(
                labelText: 'Credit limit (optional)',
                prefixText: '${AppFormatters.currencyCode} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              validator: (v) =>
                  AppValidation.optionalText(v, label: 'Notes', max: 500),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
