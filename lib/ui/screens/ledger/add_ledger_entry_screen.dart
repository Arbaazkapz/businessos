import '../../../core/validation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../data/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class AddLedgerEntryScreen extends ConsumerStatefulWidget {
  const AddLedgerEntryScreen({super.key, this.customerId});

  /// If null, the user picks a customer from a dropdown on this screen.
  final String? customerId;

  @override
  ConsumerState<AddLedgerEntryScreen> createState() =>
      _AddLedgerEntryScreenState();
}

class _AddLedgerEntryScreenState extends ConsumerState<AddLedgerEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  LedgerEntryType _type = LedgerEntryType.creditGiven;
  DateTime _date = DateTime.now();
  String? _selectedCustomerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.customerId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(ledgerRepositoryProvider)
          .addEntry(
            customerId: _selectedCustomerId!,
            type: _type,
            amount: double.parse(_amountCtrl.text.trim()),
            note: _noteCtrl.text.trim(),
            entryDate: _date,
          );
      if (!mounted) return;
      showSuccessSnack(
        context,
        _type == LedgerEntryType.creditGiven
            ? 'Credit entry saved'
            : 'Payment recorded',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Ledger Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            if (widget.customerId == null)
              customersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (customers) => DropdownButtonFormField<String>(
                  initialValue: _selectedCustomerId,
                  decoration: const InputDecoration(labelText: 'Customer *'),
                  items: customers
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCustomerId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
            const SizedBox(height: 16),
            SegmentedButton<LedgerEntryType>(
              segments: const [
                ButtonSegment(
                  value: LedgerEntryType.creditGiven,
                  label: Text('Credit Given'),
                  icon: Icon(Icons.call_made_rounded),
                ),
                ButtonSegment(
                  value: LedgerEntryType.paymentReceived,
                  label: Text('Payment Received'),
                  icon: Icon(Icons.call_received_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payments settle this customer’s oldest unpaid invoices first. Any extra is kept as customer credit.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: 'Amount *',
                prefixText: '${AppFormatters.currencyCode} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => AppValidation.number(v, positive: true),
              inputFormatters: [DecimalInputFormatter()],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(AppFormatters.date(_date)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
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
                  : const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
