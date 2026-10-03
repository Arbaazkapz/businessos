import '../../../core/validation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../data/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

const _units = ['pcs', 'kg', 'g', 'litre', 'ml', 'box', 'packet', 'dozen'];

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _lowOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjust(Product product) async {
    final controller = TextEditingController(text: '1');
    final form = GlobalKey<FormState>();
    final delta = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust ${product.name}'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${product.stockQty} ${product.unit}'),
              TextFormField(
                controller: controller,
                inputFormatters: [DecimalInputFormatter(decimals: 3)],
                validator: (text) => AppValidation.number(
                  text,
                  label: 'Quantity',
                  positive: true,
                  decimals: 3,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity (${product.unit})',
                ),
              ),
              const Text(
                'Use adjustments for deliveries or stock corrections. Sales reduce stock through invoices.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final n = double.tryParse(controller.text);
              if (n != null && n.isFinite && n > 0) Navigator.pop(ctx, -n);
            },
            icon: const Icon(Icons.remove),
            label: const Text('Remove'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final n = double.tryParse(controller.text);
              if (n != null && n.isFinite && n > 0) Navigator.pop(ctx, n);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (delta == null || !mounted) return;
    try {
      await ref.read(productRepositoryProvider).adjustStock(product.id, delta);
      if (mounted) showSuccessSnack(context, 'Stock updated');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          FilterChip(
            label: const Text('Low stock'),
            selected: _lowOnly,
            onSelected: (v) => setState(() => _lowOnly = v),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search by name, category or barcode',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = products
                    .where(
                      (p) =>
                          (!_lowOnly || p.stockQty <= p.lowStockThreshold) &&
                          (_query.isEmpty ||
                              p.name.toLowerCase().contains(_query) ||
                              p.category.toLowerCase().contains(_query) ||
                              (p.barcode ?? '').toLowerCase().contains(_query)),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: products.isEmpty ? 'No products yet' : 'No matches',
                    message: products.isEmpty
                        ? 'Add your products to track stock and use them in invoices.'
                        : 'Try a different search term.',
                    actionLabel: products.isEmpty ? 'Add Product' : null,
                    onAction: products.isEmpty
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddEditProductScreen(),
                            ),
                          )
                        : null,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final low = p.stockQty <= p.lowStockThreshold;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: low
                            ? Colors.orange.shade100
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          low
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          color: low ? Colors.orange.shade800 : null,
                        ),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.category.isEmpty ? 'Uncategorised' : p.category} · ${AppFormatters.money(p.sellingPrice)} · ${p.stockQty.toStringAsFixed(p.stockQty % 1 == 0 ? 0 : 1)} ${p.unit} in stock',
                      ),
                      trailing: IconButton(
                        tooltip: 'Add or remove stock',
                        icon: const Icon(Icons.exposure_rounded),
                        onPressed: () => _adjust(p),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditProductScreen(existing: p),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AddEditProductScreen extends ConsumerStatefulWidget {
  const AddEditProductScreen({super.key, this.existing});
  final Product? existing;

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _lowStockCtrl;
  String _unit = _units.first;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _purchasePriceCtrl = TextEditingController(
      text: p?.purchasePrice.toString() ?? '',
    );
    _sellingPriceCtrl = TextEditingController(
      text: p?.sellingPrice.toString() ?? '',
    );
    _stockCtrl = TextEditingController(text: p?.stockQty.toString() ?? '0');
    _lowStockCtrl = TextEditingController(
      text: p?.lowStockThreshold.toString() ?? '5',
    );
    _unit = p?.unit ?? _units.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _barcodeCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _stockCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(productRepositoryProvider);
    try {
      if (_isEditing) {
        await repo.update(
          widget.existing!.id,
          name: _nameCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          purchasePrice: double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0,
          sellingPrice: double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0,
          stockQty: double.tryParse(_stockCtrl.text.trim()) ?? 0,
          lowStockThreshold: double.tryParse(_lowStockCtrl.text.trim()) ?? 5,
          unit: _unit,
        );
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          purchasePrice: double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0,
          sellingPrice: double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0,
          stockQty: double.tryParse(_stockCtrl.text.trim()) ?? 0,
          lowStockThreshold: double.tryParse(_lowStockCtrl.text.trim()) ?? 5,
          unit: _unit,
        );
      }
      if (!mounted) return;
      showSuccessSnack(
        context,
        _isEditing ? 'Product updated' : 'Product added',
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

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete product?',
      message: 'This cannot be undone.',
    );
    if (ok) {
      await ref.read(productRepositoryProvider).delete(widget.existing!.id);
      if (mounted) {
        showSuccessSnack(context, 'Product deleted');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Product name *'),
              validator: (v) =>
                  AppValidation.title(v, label: 'Product name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Category'),
              validator: (v) =>
                  AppValidation.optionalText(v, label: 'Category', max: 60),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Barcode (optional)',
              ),
              validator: AppValidation.barcode,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceCtrl,
                    inputFormatters: [DecimalInputFormatter(decimals: 2)],
                    validator: (v) => AppValidation.number(
                      v,
                      label: 'Purchase price',
                      decimals: 2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Purchase price',
                      prefixText: '${AppFormatters.currencyCode} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPriceCtrl,
                    inputFormatters: [DecimalInputFormatter(decimals: 2)],
                    validator: (v) => AppValidation.number(
                      v,
                      label: 'Selling price',
                      positive: true,
                      decimals: 2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Selling price *',
                      prefixText: '${AppFormatters.currencyCode} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    inputFormatters: [DecimalInputFormatter(decimals: 3)],
                    validator: (v) => AppValidation.number(
                      v,
                      label: 'Stock quantity',
                      decimals: 3,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Current stock',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _lowStockCtrl,
              inputFormatters: [DecimalInputFormatter(decimals: 3)],
              validator: (v) => AppValidation.number(
                v,
                label: 'Low stock threshold',
                decimals: 3,
              ),
              decoration: const InputDecoration(
                labelText: 'Low stock alert threshold',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 28),
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
                  : Text(_isEditing ? 'Save Changes' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
