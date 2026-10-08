import 'package:businessos/data/history_repository.dart';
import 'package:businessos/services/history_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows = [
    ExportRow(
      time: DateTime(2026, 10, 3, 10, 30),
      kind: 'invoice',
      reference: 'INV-0001',
      details: 'Asha · current status: paid',
      amount: 1200,
      sales: 1200,
      credit: 0,
      received: 1200,
    ),
    ExportRow(
      time: DateTime(2026, 10, 7, 16, 5),
      kind: 'credit',
      reference: 'Ravi',
      details: 'Groceries',
      amount: 500,
      sales: 0,
      credit: 500,
      received: 0,
    ),
  ];

  test('Excel export produces a valid xlsx (zip) file', () {
    final bytes = HistoryExportService.buildXlsx(
      business: null,
      rows: rows,
      first: DateTime(2026, 10, 1),
      last: DateTime(2026, 10, 31),
    );
    expect(bytes.length, greaterThan(1000));
    // xlsx files are zip archives: they start with "PK".
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });

  test('Export file names carry the period and extension', () {
    expect(
      HistoryExportService.fileName(
        DateTime(2026, 4, 1),
        DateTime(2027, 3, 31),
        'pdf',
      ),
      'ShopHisab_Statement_20260401_to_20270331.pdf',
    );
  });
}
