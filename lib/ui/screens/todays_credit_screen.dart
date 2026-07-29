import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/app_database.dart';
import '../../data/repositories.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'customers/customer_detail_screen.dart';

class _CreditRow {
  _CreditRow({required this.customer, required this.givenToday, required this.currentBalance});
  final Customer customer;
  final double givenToday;
  final double currentBalance;
}

/// Shows who was extended credit today, alongside their CURRENT outstanding
/// balance (not the original today-only amount). If a customer has since
/// paid off what they owed - even later the same day - they correctly show
/// as "Cleared" here. The original ledger entry for today's credit is never
/// modified or deleted: it stays as a permanent, auditable record that
/// credit was given. What changes is the derived balance shown alongside it.
class TodaysCreditGivenScreen extends ConsumerWidget {
  const TodaysCreditGivenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final entries = ref.watch(allLedgerEntriesProvider).valueOrNull ?? const <LedgerEntry>[];

    final Map<String, double> givenTodayByCustomer = {};
    for (final e in entries) {
      if (e.type == LedgerEntryType.creditGiven && AppFormatters.isToday(e.entryDate)) {
        givenTodayByCustomer.update(e.customerId, (v) => v + e.amount, ifAbsent: () => e.amount);
      }
    }

    final rows = <_CreditRow>[];
    givenTodayByCustomer.forEach((customerId, givenToday) {
      Customer? customer;
      for (final c in customers) {
        if (c.id == customerId) {
          customer = c;
          break;
        }
      }
      if (customer == null) return;
      final balance =
          LedgerRepository.balanceOf(entries.where((e) => e.customerId == customerId));
      rows.add(_CreditRow(customer: customer, givenToday: givenToday, currentBalance: balance));
    });

    rows.sort((a, b) => b.givenToday.compareTo(a.givenToday));
    final totalGivenToday = rows.fold(0.0, (a, b) => a + b.givenToday);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Credit Given")),
      body: rows.isEmpty
          ? const EmptyState(
              icon: Icons.call_made_rounded,
              title: 'No credit given today',
              message: 'Customers you extend credit to today will show up here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  color: Colors.red.shade400.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total credit given today',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          AppFormatters.money(totalGivenToday),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: Colors.red.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Each row shows what was credited today and what that customer currently owes overall. If they\'ve since paid it off, it shows as Cleared - today\'s credit record itself is kept exactly as it happened.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                ...rows.map((r) {
                  final cleared = r.currentBalance <= 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cleared ? Colors.green.shade50 : Colors.orange.shade50,
                        child: Icon(
                          cleared ? Icons.check_circle_outline : Icons.hourglass_bottom_rounded,
                          color: cleared ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                      ),
                      title: Text(r.customer.name),
                      subtitle: Text('Credited today: ${AppFormatters.money(r.givenToday)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            cleared ? 'Cleared' : AppFormatters.money(r.currentBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cleared ? Colors.green.shade700 : Colors.orange.shade800,
                            ),
                          ),
                          if (!cleared)
                            Text('still owes', style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(customerId: r.customer.id)),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
