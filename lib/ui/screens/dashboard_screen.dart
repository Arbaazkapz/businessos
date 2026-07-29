import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/app_database.dart';
import '../../data/repositories.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'customers/add_edit_customer_screen.dart';
import 'customers/customer_detail_screen.dart';
import 'invoices/create_invoice_screen.dart';
import 'ledger/add_ledger_entry_screen.dart';
import 'settings/settings_screens.dart';
import 'todays_collections_screen.dart';
import 'todays_credit_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final ledgerAsync = ref.watch(allLedgerEntriesProvider);
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    final invoicesAsync = ref.watch(invoicesProvider);

    final businessName = profileAsync.valueOrNull?.businessName ?? 'Your Shop';
    final entries = ledgerAsync.valueOrNull ?? const <LedgerEntry>[];
    final customers = customersAsync.valueOrNull ?? const <Customer>[];
    final products = productsAsync.valueOrNull ?? const <Product>[];
    final invoices = invoicesAsync.valueOrNull ?? const <Invoice>[];

    // "Paid" invoices (walk-in or customer) never post a ledger entry at all
    // (there's no debt to track), so they must be added separately here or
    // they'd silently vanish from today's collections total. Partial-payment
    // amounts are NOT included in this second sum - those are already
    // captured via their ledger paymentReceived entry below, so adding them
    // again here would double-count them.
    final paidInvoiceCollectionsToday = invoices
        .where((i) => i.status == InvoiceStatus.paid && AppFormatters.isToday(i.invoiceDate))
        .fold(0.0, (a, b) => a + b.amountPaid);
    final todaysCollections =
        LedgerRepository.sumToday(entries, LedgerEntryType.paymentReceived) +
            paidInvoiceCollectionsToday;
    final todaysCreditGiven = LedgerRepository.sumToday(entries, LedgerEntryType.creditGiven);
    final totalReceivable = LedgerRepository.totalReceivable(entries);
    final lowStock = ProductRepository.lowStock(products);

    // Recent customers = customers behind the most recent ledger activity.
    final recentCustomerIds = <String>[];
    for (final e in entries) {
      if (!recentCustomerIds.contains(e.customerId)) recentCustomerIds.add(e.customerId);
      if (recentCustomerIds.length >= 5) break;
    }
    final recentCustomers = recentCustomerIds
        .map((id) {
          try {
            return customers.firstWhere((c) => c.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<Customer>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(businessName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            tooltip: 'Backup',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allLedgerEntriesProvider);
          ref.invalidate(customersProvider);
          ref.invalidate(productsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SectionHeader('Today - ${AppFormatters.date(DateTime.now())}'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                DashboardStatCard(
                  label: "Today's Collections",
                  value: AppFormatters.moneyWhole(todaysCollections),
                  icon: Icons.savings_rounded,
                  color: Colors.green.shade700,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TodaysCollectionsScreen())),
                ),
                DashboardStatCard(
                  label: 'Money to Receive',
                  value: AppFormatters.moneyWhole(totalReceivable),
                  icon: Icons.call_received_rounded,
                  color: Colors.orange.shade800,
                ),
                DashboardStatCard(
                  label: "Today's Credit Given",
                  value: AppFormatters.moneyWhole(todaysCreditGiven),
                  icon: Icons.call_made_rounded,
                  color: Colors.red.shade600,
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const TodaysCreditGivenScreen())),
                ),
                DashboardStatCard(
                  label: 'Low Stock Items',
                  value: '${lowStock.length}',
                  icon: Icons.inventory_2_rounded,
                  color: Colors.purple.shade600,
                ),
              ],
            ),
            SectionHeader('Quick actions'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add Customer',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddEditCustomerScreen())),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.receipt_long_rounded,
                    label: 'New Invoice',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.add_card_rounded,
                    label: 'New Entry',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddLedgerEntryScreen())),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Backup',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const BackupRestoreScreen())),
                  ),
                ],
              ),
            ),
            if (lowStock.isNotEmpty) ...[
              SectionHeader('Low stock alerts'),
              ...lowStock.take(5).map((p) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: Text(p.name),
                      subtitle: Text('${p.stockQty.toStringAsFixed(0)} ${p.unit} left'),
                    ),
                  )),
            ],
            SectionHeader('Recent customers'),
            if (recentCustomers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No activity yet. Add a customer to get started.'),
                ),
              )
            else
              ...recentCustomers.map((c) {
                final customerEntries = entries.where((e) => e.customerId == c.id);
                final balance = LedgerRepository.balanceOf(customerEntries);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?'),
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.phone.isEmpty ? 'No phone number' : c.phone),
                    trailing: Text(
                      AppFormatters.money(balance.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: balance > 0
                            ? Colors.orange.shade800
                            : (balance < 0 ? Colors.green.shade700 : null),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
