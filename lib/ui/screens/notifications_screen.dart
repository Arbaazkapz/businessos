import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/app_database.dart';
import '../../data/repositories.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'customers/customer_list_screen.dart';
import 'invoices/invoice_list_screen.dart';
import 'products/product_screens.dart';
import 'settings/settings_screens.dart';

/// How many days old a backup can be before we nudge the user again.
const _backupReminderDays = 7;

/// Computes how many items currently need the shopkeeper's attention.
/// Kept as a single pure function so the dashboard bell badge and this
/// full screen always agree on the same count - no risk of the two
/// getting out of sync with each other.
class AttentionCounts {
  AttentionCounts({
    required this.pendingCustomers,
    required this.lowStock,
    required this.overdueInvoices,
    required this.backupPending,
  });

  final int pendingCustomers;
  final int lowStock;
  final int overdueInvoices;
  final bool backupPending;

  int get total => pendingCustomers + lowStock + overdueInvoices + (backupPending ? 1 : 0);

  static AttentionCounts compute({
    required List<Customer> customers,
    required List<LedgerEntry> entries,
    required List<Product> products,
    required List<Invoice> invoices,
    required DateTime? lastBackupAt,
  }) {
    final pending = customers.where((c) {
      final balance = LedgerRepository.balanceOf(entries.where((e) => e.customerId == c.id));
      return balance > 0;
    }).length;

    final low = ProductRepository.lowStock(products).length;

    final now = DateTime.now();
    final overdue = invoices
        .where((i) =>
            i.status != InvoiceStatus.paid && i.dueDate != null && i.dueDate!.isBefore(now))
        .length;

    final backupPending =
        lastBackupAt == null || now.difference(lastBackupAt).inDays >= _backupReminderDays;

    return AttentionCounts(
      pendingCustomers: pending,
      lowStock: low,
      overdueInvoices: overdue,
      backupPending: backupPending,
    );
  }
}

final attentionCountsProvider = Provider<AttentionCounts>((ref) {
  final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
  final entries = ref.watch(allLedgerEntriesProvider).valueOrNull ?? const <LedgerEntry>[];
  final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
  final invoices = ref.watch(invoicesProvider).valueOrNull ?? const <Invoice>[];
  final lastBackupAt = ref.watch(lastBackupProvider).valueOrNull;

  return AttentionCounts.compute(
    customers: customers,
    entries: entries,
    products: products,
    invoices: invoices,
    lastBackupAt: lastBackupAt,
  );
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(attentionCountsProvider);
    final lastBackupAt = ref.watch(lastBackupProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Needs Attention')),
      body: counts.total == 0
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All clear',
              message: 'Nothing needs your attention right now.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (counts.pendingCustomers > 0)
                  _AttentionCard(
                    icon: Icons.people_outline,
                    color: Colors.orange.shade700,
                    title:
                        '${counts.pendingCustomers} customer${counts.pendingCustomers == 1 ? '' : 's'} pending',
                    subtitle: 'They still owe you money',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const CustomerListScreen())),
                  ),
                if (counts.lowStock > 0)
                  _AttentionCard(
                    icon: Icons.inventory_2_outlined,
                    color: Colors.purple.shade600,
                    title:
                        '${counts.lowStock} product${counts.lowStock == 1 ? '' : 's'} low on stock',
                    subtitle: 'Time to restock soon',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
                  ),
                if (counts.overdueInvoices > 0)
                  _AttentionCard(
                    icon: Icons.receipt_long_outlined,
                    color: Colors.red.shade600,
                    title:
                        '${counts.overdueInvoices} invoice${counts.overdueInvoices == 1 ? '' : 's'} overdue',
                    subtitle: 'Past their due date and still unpaid',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const InvoiceListScreen())),
                  ),
                if (counts.backupPending)
                  _AttentionCard(
                    icon: Icons.cloud_off_outlined,
                    color: Colors.blueGrey.shade600,
                    title: 'Backup reminder',
                    subtitle: lastBackupAt == null
                        ? "You haven't backed up yet"
                        : 'Last backup was ${AppFormatters.date(lastBackupAt)}',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const BackupRestoreScreen())),
                  ),
              ],
            ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
