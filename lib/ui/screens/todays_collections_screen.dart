import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/app_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';

class _CollectionRow {
  _CollectionRow({
    required this.customerName,
    required this.amount,
    required this.time,
    required this.sourceLabel,
  });
  final String customerName;
  final double amount;
  final DateTime time;
  final String sourceLabel;
}

/// Shows exactly what makes up "Today's Collections": every ledger payment
/// received today, PLUS every invoice marked Paid today (including walk-in
/// sales, which never touch the ledger since they have no customer record).
class TodaysCollectionsScreen extends ConsumerWidget {
  const TodaysCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final entries = ref.watch(allLedgerEntriesProvider).valueOrNull ?? const <LedgerEntry>[];
    final invoices = ref.watch(invoicesProvider).valueOrNull ?? const <Invoice>[];

    String nameFor(String customerId) {
      for (final c in customers) {
        if (c.id == customerId) return c.name;
      }
      return 'Unknown customer';
    }

    final rows = <_CollectionRow>[];

    for (final e in entries) {
      if (e.type == LedgerEntryType.paymentReceived && AppFormatters.isToday(e.entryDate)) {
        rows.add(_CollectionRow(
          customerName: nameFor(e.customerId),
          amount: e.amount,
          time: e.entryDate,
          sourceLabel: e.note.isEmpty ? 'Payment received' : e.note,
        ));
      }
    }

    for (final inv in invoices) {
      if (inv.status == InvoiceStatus.paid && AppFormatters.isToday(inv.invoiceDate)) {
        rows.add(_CollectionRow(
          customerName: inv.customerNameSnapshot,
          amount: inv.amountPaid,
          time: inv.invoiceDate,
          sourceLabel: 'Invoice ${inv.invoiceNumber} - paid in full',
        ));
      }
    }

    rows.sort((a, b) => b.time.compareTo(a.time));
    final total = rows.fold(0.0, (a, b) => a + b.amount);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Collections")),
      body: rows.isEmpty
          ? const EmptyState(
              icon: Icons.savings_outlined,
              title: 'No collections yet today',
              message: 'Payments received and fully-paid invoices from today will show up here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  color: Colors.green.shade700.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total collected today',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          AppFormatters.money(total),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...rows.map((r) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: Icon(Icons.call_received_rounded, color: Colors.green.shade700),
                        ),
                        title: Text(r.customerName),
                        subtitle: Text('${r.sourceLabel}\n${AppFormatters.dateTimeStr(r.time)}'),
                        isThreeLine: true,
                        trailing: Text(
                          AppFormatters.money(r.amount),
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade700),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}
