import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/formatters.dart';
import '../../data/app_database.dart';
import '../../data/repositories.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'calculator_screen.dart';
import 'customers/add_edit_customer_screen.dart';
import 'customers/customer_detail_screen.dart';
import 'invoices/create_invoice_screen.dart';
import 'ledger/add_ledger_entry_screen.dart';
import 'notepad_screen.dart';
import 'notifications_screen.dart';
import 'settings/settings_screens.dart';
import 'todays_collections_screen.dart';
import 'todays_credit_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'greeting_morning';
    if (hour < 17) return 'greeting_afternoon';
    return 'greeting_evening';
  }

  Future<void> _showQuickTools(BuildContext context, AppStrings strings) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.t('quick_add_title'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              _ToolTile(
                icon: Icons.sticky_note_2_outlined,
                label: strings.t('notepad_title'),
                color: Colors.amber.shade700,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotepadScreen()));
                },
              ),
              const SizedBox(height: 10),
              _ToolTile(
                icon: Icons.calculate_outlined,
                label: strings.t('calculator_title'),
                color: Colors.blue.shade600,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CalculatorScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final ledgerAsync = ref.watch(allLedgerEntriesProvider);
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    final invoicesAsync = ref.watch(invoicesProvider);
    final strings = ref.watch(appStringsProvider);
    final locale = ref.watch(localeProvider);
    final attention = ref.watch(attentionCountsProvider);

    final profile = profileAsync.valueOrNull;
    final businessName = profile?.businessName ?? 'Your Shop';
    final ownerName = profile?.ownerName ?? '';
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
        automaticallyImplyLeading: false,
        title: Text(businessName, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => ref.read(localeProvider.notifier).toggle(),
            child: Text(
              locale == AppLocale.hi ? 'हिं' : 'EN',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: strings.t('notifications_title'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              if (attention.total > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickTools(context, strings),
        tooltip: strings.t('quick_add_title'),
        child: const Icon(Icons.add),
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
            Text(
              '${strings.t(_greetingKey())}${ownerName.isNotEmpty ? ', $ownerName' : ''} 👋',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${strings.t('dashboard_welcome')} $businessName',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SectionHeader('${strings.t('dashboard_today')} - ${AppFormatters.date(DateTime.now())}'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                DashboardStatCard(
                  label: strings.t('dashboard_collections'),
                  value: AppFormatters.moneyWhole(todaysCollections),
                  icon: Icons.savings_rounded,
                  color: Colors.green.shade700,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TodaysCollectionsScreen())),
                ),
                DashboardStatCard(
                  label: strings.t('dashboard_money_to_receive'),
                  value: AppFormatters.moneyWhole(totalReceivable),
                  icon: Icons.call_received_rounded,
                  color: Colors.orange.shade800,
                ),
                DashboardStatCard(
                  label: strings.t('dashboard_credit_given'),
                  value: AppFormatters.moneyWhole(todaysCreditGiven),
                  icon: Icons.call_made_rounded,
                  color: Colors.red.shade600,
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const TodaysCreditGivenScreen())),
                ),
                DashboardStatCard(
                  label: strings.t('dashboard_low_stock'),
                  value: '${lowStock.length}',
                  icon: Icons.inventory_2_rounded,
                  color: Colors.purple.shade600,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ],
            ),
            SectionHeader(strings.t('dashboard_quick_actions')),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: strings.t('dashboard_add_customer'),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddEditCustomerScreen())),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.receipt_long_rounded,
                    label: strings.t('dashboard_new_invoice'),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.add_card_rounded,
                    label: strings.t('dashboard_new_entry'),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddLedgerEntryScreen())),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.cloud_upload_outlined,
                    label: strings.t('dashboard_backup'),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const BackupRestoreScreen())),
                  ),
                ],
              ),
            ),
            if (lowStock.isNotEmpty) ...[
              SectionHeader(strings.t('dashboard_low_stock_alerts')),
              ...lowStock.take(5).map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: Text(p.name),
                      subtitle: Text('${p.stockQty.toStringAsFixed(0)} ${p.unit} left'),
                    ),
                  )),
            ],
            SectionHeader(strings.t('dashboard_recent_customers')),
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
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text(label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed-size quick action button. Previously this sized itself to its
/// content, so "Add Customer" (which wraps to two lines) rendered visibly
/// taller than the single-line buttons next to it. Every button now gets
/// the same fixed footprint regardless of label length.
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
        child: SizedBox(
          width: 100,
          height: 100,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
