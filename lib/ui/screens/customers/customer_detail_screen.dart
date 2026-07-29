import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../data/app_database.dart';
import '../../../data/repositories.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import '../ledger/add_ledger_entry_screen.dart';
import 'add_edit_customer_screen.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final ledgerAsync = ref.watch(ledgerForCustomerProvider(customerId));

    Customer? customer;
    for (final c in customersAsync.valueOrNull ?? const <Customer>[]) {
      if (c.id == customerId) {
        customer = c;
        break;
      }
    }

    if (customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final Customer safeCustomer = customer;

    final entries = ledgerAsync.valueOrNull ?? const <LedgerEntry>[];
    final balance = LedgerRepository.balanceOf(entries);

    return Scaffold(
      appBar: AppBar(
        title: Text(safeCustomer.name),
        actions: [
          IconButton(
            icon: Icon(
                safeCustomer.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded),
            color: safeCustomer.isFavourite ? Colors.amber : null,
            onPressed: () => ref
                .read(customerRepositoryProvider)
                .update(safeCustomer.id, isFavourite: !safeCustomer.isFavourite),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddEditCustomerScreen(existing: safeCustomer)));
              } else if (value == 'block') {
                await ref
                    .read(customerRepositoryProvider)
                    .update(safeCustomer.id, isBlocked: !safeCustomer.isBlocked);
              } else if (value == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete customer?',
                  message:
                      'This removes ${safeCustomer.name} and cannot be undone. Ledger history for this customer will remain orphaned.',
                );
                if (ok) {
                  await ref.read(customerRepositoryProvider).delete(safeCustomer.id);
                  if (context.mounted) {
                    showSuccessSnack(context, 'Customer deleted');
                    Navigator.pop(context);
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit customer')),
              PopupMenuItem(
                  value: 'block',
                  child:
                      Text(safeCustomer.isBlocked ? 'Unblock customer' : 'Block customer')),
              const PopupMenuItem(value: 'delete', child: Text('Delete customer')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddLedgerEntryScreen(customerId: safeCustomer.id)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balance == 0
                        ? 'Settled up'
                        : (balance > 0 ? 'Owes you' : 'You owe them'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.money(balance.abs()),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: balance > 0
                              ? Colors.orange.shade800
                              : (balance < 0 ? Colors.green.shade700 : null),
                        ),
                  ),
                  if (safeCustomer.phone.isNotEmpty || safeCustomer.address.isNotEmpty) ...[
                    const Divider(height: 28),
                    if (safeCustomer.phone.isNotEmpty)
                      _InfoRow(icon: Icons.call_outlined, text: safeCustomer.phone),
                    if (safeCustomer.address.isNotEmpty)
                      _InfoRow(icon: Icons.location_on_outlined, text: safeCustomer.address),
                    if (safeCustomer.gstNumber != null)
                      _InfoRow(
                          icon: Icons.badge_outlined, text: 'GST: ${safeCustomer.gstNumber}'),
                    if (safeCustomer.creditLimit != null)
                      _InfoRow(
                          icon: Icons.speed_outlined,
                          text:
                              'Credit limit: ${AppFormatters.money(safeCustomer.creditLimit!)}'),
                  ],
                ],
              ),
            ),
          ),
          SectionHeader('Ledger history'),
          if (entries.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No entries yet',
              message: 'Tap "Add Entry" to record a credit or payment.',
            )
          else
            ...entries.map((e) => _LedgerTile(entry: e)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCredit = entry.type == LedgerEntryType.creditGiven;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        title: 'Delete entry?',
        message: 'This ledger entry will be permanently removed.',
      ),
      onDismissed: (_) {
        ref.read(ledgerRepositoryProvider).deleteEntry(entry.id);
        showSuccessSnack(context, 'Entry deleted');
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isCredit ? Colors.red.shade50 : Colors.green.shade50,
            child: Icon(
              isCredit ? Icons.call_made_rounded : Icons.call_received_rounded,
              color: isCredit ? Colors.red.shade600 : Colors.green.shade700,
            ),
          ),
          title: Text(isCredit ? 'Credit given' : 'Payment received'),
          subtitle: Text(
            entry.note.isEmpty
                ? AppFormatters.dateTimeStr(entry.entryDate)
                : '${entry.note}\n${AppFormatters.dateTimeStr(entry.entryDate)}',
          ),
          isThreeLine: entry.note.isNotEmpty,
          trailing: Text(
            AppFormatters.money(entry.amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isCredit ? Colors.red.shade600 : Colors.green.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
