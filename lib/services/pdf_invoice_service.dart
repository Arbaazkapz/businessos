import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../data/app_database.dart';

/// Builds a clean, professional invoice PDF entirely on-device - no server,
/// no template download, works with zero internet connectivity.
///
/// IMPORTANT: the `pdf` package's built-in base-14 fonts (Helvetica etc.)
/// do NOT contain a glyph for the Indian Rupee sign (₹, U+20B9) - it
/// renders as a broken box. We embed Noto Sans (which does contain it) and
/// make it the document's default font so every ₹ amount renders correctly.
class PdfInvoiceService {
  static Future<Uint8List> build({
    required BusinessProfile business,
    required Invoice invoice,
    required List<InvoiceItem> items,
  }) async {
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regularFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    final balanceDue = invoice.total - invoice.amountPaid;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(business.businessName,
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      if (business.address.isNotEmpty) pw.Text(business.address),
                      if (business.phone.isNotEmpty) pw.Text('Phone: ${business.phone}'),
                      if (business.gstNumber != null) pw.Text('GSTIN: ${business.gstNumber}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoice.invoiceNumber),
                      pw.Text(AppFormatters.date(invoice.invoiceDate)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text('Bill to:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice.customerNameSnapshot),
              if (invoice.dueDate != null)
                pw.Text('Due date: ${AppFormatters.date(invoice.dueDate!)}'),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(4),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.6),
                  3: pw.FlexColumnWidth(1.6),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Description', bold: true),
                      _cell('Qty', bold: true),
                      _cell('Rate', bold: true),
                      _cell('Amount', bold: true),
                    ],
                  ),
                  ...items.map((item) => pw.TableRow(children: [
                        _cell(item.description),
                        _cell(item.qty % 1 == 0 ? item.qty.toStringAsFixed(0) : item.qty.toString()),
                        _cell(AppFormatters.money(item.unitPrice)),
                        _cell(AppFormatters.money(item.lineTotal)),
                      ])),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 240,
                  child: pw.Column(
                    children: [
                      _totalsRow('Subtotal', invoice.subtotal),
                      _totalsRow('Discount', -invoice.discount),
                      _totalsRow('Tax (${invoice.taxPercent.toStringAsFixed(1)}%)',
                          invoice.total - (invoice.subtotal - invoice.discount)),
                      pw.Divider(),
                      _totalsRow('Total', invoice.total, bold: true),
                      if (invoice.status != InvoiceStatus.paid) ...[
                        pw.SizedBox(height: 4),
                        _totalsRow('Amount Paid', invoice.amountPaid),
                        _totalsRow('Balance Due', balanceDue,
                            bold: true, color: PdfColors.red700),
                      ],
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              _statusBadge(invoice.status),
              if (invoice.notes.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('Notes: ${invoice.notes}'),
              ],
              pw.SizedBox(height: 28),
              pw.Center(
                child: pw.Text(
                  'Generated by BusinessOS - Your Shop. Your Data. Always Available.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _statusBadge(InvoiceStatus status) {
    final (label, color) = switch (status) {
      InvoiceStatus.paid => ('PAID', PdfColors.green700),
      InvoiceStatus.partial => ('PARTIALLY PAID', PdfColors.orange700),
      InvoiceStatus.unpaid => ('UNPAID', PdfColors.red700),
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color, fontSize: 12),
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _totalsRow(String label, double value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
          pw.Text(AppFormatters.money(value),
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
