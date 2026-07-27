import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../data/app_database.dart';
import '../../../data/repositories.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import 'add_edit_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final ledgerAsync = ref.watch(allLedgerEntriesProvider);
    final entries = ledgerAsync.valueOrNull ?? const <LedgerEntry>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddEditCustomerScreen())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                final filtered = _query.isEmpty
                    ? customers
                    : customers
                        .where((c) =>
                            c.name.toLowerCase().contains(_query) || c.phone.contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: customers.isEmpty ? 'No customers yet' : 'No matches',
                    message: customers.isEmpty
                        ? 'Add your first customer to start tracking their khata.'
                        : 'Try a different search term.',
                    actionLabel: customers.isEmpty ? 'Add Customer' : null,
                    onAction: customers.isEmpty
                        ? () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AddEditCustomerScreen()))
                        : null,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    final balance =
                        LedgerRepository.balanceOf(entries.where((e) => e.customerId == c.id));
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.isFavourite
                            ? Colors.amber.shade200
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(c.name),
                      subtitle: Text(c.phone.isEmpty ? 'No phone number' : c.phone),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.money(balance.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: balance > 0
                                  ? Colors.orange.shade800
                                  : (balance < 0 ? Colors.green.shade700 : Colors.grey),
                            ),
                          ),
                          Text(
                            balance > 0 ? 'to receive' : (balance < 0 ? 'you owe' : 'settled'),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id))),
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
