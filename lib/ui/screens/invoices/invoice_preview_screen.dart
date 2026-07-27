import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../data/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../services/pdf_invoice_service.dart';

class InvoicePreviewScreen extends ConsumerWidget {
  const InvoicePreviewScreen({super.key, required this.invoiceId});
  final String invoiceId;

  Future<(BusinessProfile, Invoice, List<InvoiceItem>)> _load(WidgetRef ref) async {
    final business = await ref.read(businessRepositoryProvider).getProfile();
    final invoice = await ref.read(invoiceRepositoryProvider).getById(invoiceId);
    final items = await ref.read(invoiceRepositoryProvider).itemsFor(invoiceId);
    if (business == null || invoice == null) {
      throw StateError('Invoice not found');
    }
    return (business, invoice, items);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: FutureBuilder(
        future: _load(ref),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (business, invoice, items) = snapshot.data!;
          return PdfPreview(
            build: (format) => PdfInvoiceService.build(
              business: business,
              invoice: invoice,
              items: items,
            ),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: true,
            allowPrinting: true,
            pdfFileName: '${invoice.invoiceNumber}.pdf',
          );
        },
      ),
    );
  }
}
