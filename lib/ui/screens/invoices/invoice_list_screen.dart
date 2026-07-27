import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../data/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import 'create_invoice_screen.dart';
import 'invoice_preview_screen.dart';

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid:
        return Colors.green.shade700;
      case InvoiceStatus.unpaid:
        return Colors.red.shade600;
      case InvoiceStatus.partial:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No invoices yet',
              message: 'Create your first invoice - GST or non-GST, with a PDF you can share.',
              actionLabel: 'New Invoice',
              onAction: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            itemCount: invoices.length,
            itemBuilder: (context, i) {
              final inv = invoices[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(inv.status).withValues(alpha: 0.15),
                  child: Icon(Icons.receipt_outlined, color: _statusColor(inv.status)),
                ),
                title: Text(inv.invoiceNumber),
                subtitle: Text('${inv.customerNameSnapshot} · ${AppFormatters.date(inv.invoiceDate)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(AppFormatters.money(inv.total),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      inv.status.name.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(inv.status)),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: inv.id))),
              );
            },
          );
        },
      ),
    );
  }
}
