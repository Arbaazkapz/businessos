import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../data/app_database.dart';
import '../../../data/repositories.dart';
import '../../../providers/app_providers.dart';
import 'invoice_preview_screen.dart';

class _LineDraft {
  _LineDraft({this.productId, String description = '', double qty = 1, double unitPrice = 0})
      : descriptionCtrl = TextEditingController(text: description),
        qtyCtrl = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString()),
        priceCtrl = TextEditingController(text: unitPrice.toString());

  String? productId;
  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  double get qty => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get lineTotal => qty * unitPrice;

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final List<_LineDraft> _lines = [_LineDraft()];
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  String? _customerId;
  String _customerName = 'Walk-in Customer';
  InvoiceStatus _status = InvoiceStatus.paid;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _amountPaidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (a, l) => a + l.lineTotal);
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0;
  double get _taxPercent => double.tryParse(_taxCtrl.text.trim()) ?? 0;
  double get _afterDiscount => (_subtotal - _discount) < 0 ? 0 : _subtotal - _discount;
  double get _taxAmount => _afterDiscount * (_taxPercent / 100);
  double get _total => _afterDiscount + _taxAmount;

  void _addLine() => setState(() => _lines.add(_LineDraft()));

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _pickProduct(int lineIndex) async {
    final products = ref.read(productsProvider).valueOrNull ?? const <Product>[];
    if (products.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No products yet - add some in the Products tab')));
      return;
    }
    final selected = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: products
              .map((p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text('${AppFormatters.money(p.sellingPrice)} · ${p.stockQty.toStringAsFixed(0)} ${p.unit} left'),
                    onTap: () => Navigator.pop(ctx, p),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _lines[lineIndex].productId = selected.id;
        _lines[lineIndex].descriptionCtrl.text = selected.name;
        _lines[lineIndex].priceCtrl.text = selected.sellingPrice.toString();
      });
    }
  }

  Future<void> _pickCustomer() async {
    final customers = ref.read(customersProvider).valueOrNull ?? const <Customer>[];
    final selected = await showModalBottomSheet<Customer?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Walk-in Customer'),
              onTap: () => Navigator.pop(ctx, null),
            ),
            const Divider(),
            ...customers.map((c) => ListTile(
                  title: Text(c.name),
                  subtitle: Text(c.phone),
                  onTap: () => Navigator.pop(ctx, c),
                )),
          ],
        ),
      ),
    );
    setState(() {
      _customerId = selected?.id;
      _customerName = selected?.name ?? 'Walk-in Customer';
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final validLines = _lines.where((l) => l.qty > 0 && l.unitPrice > 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one item with a quantity and a unit price')));
      return;
    }
    if (_status != InvoiceStatus.paid && _customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unpaid/partial invoices need a customer, not "Walk-in"')));
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(invoiceRepositoryProvider).createInvoice(
            customerId: _customerId,
            customerNameSnapshot: _customerName,
            lines: validLines
                .asMap()
                .entries
                .map((entry) => InvoiceLineInput(
                      description: entry.value.descriptionCtrl.text.trim().isEmpty
                          ? 'Item ${entry.key + 1}'
                          : entry.value.descriptionCtrl.text.trim(),
                      qty: entry.value.qty,
                      unitPrice: entry.value.unitPrice,
                      productId: entry.value.productId,
                    ))
                .toList(),
            discount: _discount,
            taxPercent: _taxPercent,
            status: _status,
            amountPaidNow: double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
            notes: _notesCtrl.text.trim(),
            dueDate: _dueDate,
          );
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: id)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Invoice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_customerName),
              subtitle: const Text('Tap to change customer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCustomer,
            ),
          ),
          const SizedBox(height: 20),
          Text('Items', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._lines.asMap().entries.map((entry) {
            final i = entry.key;
            final line = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: line.descriptionCtrl,
                            decoration: const InputDecoration(labelText: 'Item description'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.inventory_2_outlined),
                          tooltip: 'Pick from products',
                          onPressed: () => _pickProduct(i),
                        ),
                        if (_lines.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeLine(i),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: line.qtyCtrl,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: line.priceCtrl,
                            decoration: const InputDecoration(labelText: 'Unit price', prefixText: '₹ '),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 80,
                          child: Text(
                            AppFormatters.money(line.lineTotal),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text('Add line item'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtrl,
                  decoration: const InputDecoration(labelText: 'Discount', prefixText: '₹ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  decoration: const InputDecoration(labelText: 'Tax / GST %', suffixText: '%'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set the tax rate that applies to your business - check with your accountant for the correct GST rate and CGST/SGST split.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text('Payment status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<InvoiceStatus>(
            segments: const [
              ButtonSegment(value: InvoiceStatus.paid, label: Text('Paid')),
              ButtonSegment(value: InvoiceStatus.unpaid, label: Text('Unpaid')),
              ButtonSegment(value: InvoiceStatus.partial, label: Text('Partial')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          if (_status == InvoiceStatus.partial) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _amountPaidCtrl,
              decoration: const InputDecoration(labelText: 'Amount received now', prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          if (_status != InvoiceStatus.paid) ...[
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_dueDate == null ? 'No due date set' : AppFormatters.date(_dueDate!)),
              trailing: TextButton(onPressed: _pickDueDate, child: const Text('Set due date')),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow('Subtotal', _subtotal),
                  _SummaryRow('Discount', -_discount),
                  _SummaryRow('Tax', _taxAmount),
                  const Divider(),
                  _SummaryRow('Total', _total, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Invoice'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.bold = false});
  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(AppFormatters.money(value), style: style),
        ],
      ),
    );
  }
}
