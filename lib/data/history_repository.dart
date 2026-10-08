import 'package:drift/drift.dart';

import 'app_database.dart';

class HistoryDay {
  const HistoryDay(
    this.date,
    this.sales,
    this.credit,
    this.received,
    this.invoiceCount,
    this.records,
  );
  final DateTime date;
  final double sales, credit, received;
  final int invoiceCount, records;
}

class HistoryRecord {
  const HistoryRecord(
    this.kind,
    this.title,
    this.note,
    this.amount,
    this.time,
    this.id,
  );
  final String kind, title, note, id;
  final double amount;
  final DateTime time;
}

/// One flat transaction line used by the PDF / Excel export.
class ExportRow {
  const ExportRow({
    required this.time,
    required this.kind,
    required this.reference,
    required this.details,
    required this.amount,
    required this.sales,
    required this.credit,
    required this.received,
  });
  final DateTime time;
  final String kind, reference, details;
  final double amount, sales, credit, received;
}

class HistoryRepository {
  HistoryRepository(this.db);
  final AppDatabase db;
  static const events = '''
    SELECT i.invoice_date AS occurred, 'invoice' AS kind, i.invoice_number AS title,
      i.customer_name_snapshot || ' · current status: ' || i.status AS note,
      i.total AS amount, i.total AS sales, 0.0 AS credit,
      CASE WHEN NOT EXISTS (SELECT 1 FROM ledger_entries l WHERE l.linked_invoice_id = i.id)
        THEN i.amount_paid ELSE 0.0 END AS received, i.id AS id
    FROM invoices i WHERE i.invoice_date >= ? AND i.invoice_date < ?
    UNION ALL
    SELECT l.entry_date, CASE WHEN l.type = 'creditGiven' THEN 'credit' ELSE 'payment' END,
      COALESCE(c.name, 'Customer'), l.note, l.amount, 0.0,
      CASE WHEN l.type = 'creditGiven' THEN l.amount ELSE 0.0 END,
      CASE WHEN l.type = 'paymentReceived' THEN l.amount ELSE 0.0 END, l.id
    FROM ledger_entries l LEFT JOIN customers c ON c.id = l.customer_id
    WHERE l.entry_date >= ? AND l.entry_date < ?
  ''';
  List<Variable> _bounds(DateTime start, DateTime end) => [
    Variable.withInt(start.millisecondsSinceEpoch ~/ 1000),
    Variable.withInt(end.millisecondsSinceEpoch ~/ 1000),
    Variable.withInt(start.millisecondsSinceEpoch ~/ 1000),
    Variable.withInt(end.millisecondsSinceEpoch ~/ 1000),
  ];
  Stream<List<HistoryDay>> watchDays(DateTime start, DateTime end) => db
      .customSelect(
        '''
    WITH events AS ($events)
    SELECT date(occurred, 'unixepoch', 'localtime') AS day,
      SUM(sales) AS sales, SUM(credit) AS credit, SUM(received) AS received,
      SUM(CASE WHEN kind = 'invoice' THEN 1 ELSE 0 END) AS invoice_count, COUNT(*) AS records
    FROM events GROUP BY day ORDER BY day DESC
  ''',
        variables: _bounds(start, end),
        readsFrom: {db.invoices, db.ledgerEntries, db.customers},
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (r) => HistoryDay(
                DateTime.parse(r.read<String>('day')),
                r.read<double>('sales'),
                r.read<double>('credit'),
                r.read<double>('received'),
                r.read<int>('invoice_count'),
                r.read<int>('records'),
              ),
            )
            .toList(),
      );

  Stream<List<HistoryRecord>> watchRecords(DateTime day, {int limit = 50}) => db
      .customSelect(
        '''
    WITH events AS ($events) SELECT * FROM events ORDER BY occurred DESC, kind, id LIMIT ?
  ''',
        variables: [
          ..._bounds(day, DateTime(day.year, day.month, day.day + 1)),
          Variable.withInt(limit),
        ],
        readsFrom: {db.invoices, db.ledgerEntries, db.customers},
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (r) => HistoryRecord(
                r.read<String>('kind'),
                r.read<String>('title'),
                r.read<String>('note'),
                r.read<double>('amount'),
                DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('occurred') * 1000,
                ),
                r.read<String>('id'),
              ),
            )
            .toList(),
      );

  /// Every transaction between [start] (inclusive) and [endExclusive],
  /// oldest first. Used by the PDF / Excel export (no row limit).
  Future<List<ExportRow>> fetchExportRows(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final rows = await db
        .customSelect(
          '''
    WITH events AS ($events) SELECT * FROM events ORDER BY occurred ASC, kind, id
  ''',
          variables: _bounds(start, endExclusive),
          readsFrom: {db.invoices, db.ledgerEntries, db.customers},
        )
        .get();
    return rows
        .map(
          (r) => ExportRow(
            time: DateTime.fromMillisecondsSinceEpoch(
              r.read<int>('occurred') * 1000,
            ),
            kind: r.read<String>('kind'),
            reference: r.read<String>('title'),
            details: r.read<String>('note'),
            amount: r.read<double>('amount'),
            sales: r.read<double>('sales'),
            credit: r.read<double>('credit'),
            received: r.read<double>('received'),
          ),
        )
        .toList();
  }
}
