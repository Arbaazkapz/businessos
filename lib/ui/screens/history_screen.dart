import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../data/history_repository.dart';
import '../../providers/app_providers.dart';
import 'history_export_sheet.dart';
import 'invoices/invoice_preview_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Inclusive first and last day (date-only) of the selected period.
  late DateTime _first;
  late DateTime _last;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _today() => _day(DateTime.now());

  @override
  void initState() {
    super.initState();
    _setMonth(_today());
  }

  void _setMonth(DateTime anyDayInMonth) {
    _first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    _last = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
  }

  bool get _isFullMonth =>
      _first.day == 1 &&
      _last.year == _first.year &&
      _last.month == _first.month &&
      _last.day == DateTime(_first.year, _first.month + 1, 0).day;

  int get _spanDays => _last.difference(_first).inDays + 1;

  /// Exclusive upper bound used by the database query.
  DateTime get _endExclusive => DateTime(_last.year, _last.month, _last.day + 1);

  bool get _canGoNext => _last.isBefore(_today());

  void _shift(int direction) {
    setState(() {
      if (_isFullMonth) {
        _setMonth(DateTime(_first.year, _first.month + direction, 1));
      } else {
        final span = _spanDays;
        _first = DateTime(_first.year, _first.month, _first.day + direction * span);
        _last = DateTime(_last.year, _last.month, _last.day + direction * span);
      }
    });
  }

  void _setRange(DateTime first, DateTime last) {
    setState(() {
      _first = _day(first);
      _last = _day(last);
    });
  }

  Future<void> _pickRange() async {
    final today = _today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _first.isAfter(today) ? today : _first,
        end: _last.isAfter(today) ? today : _last,
      ),
      helpText: 'Select a period',
      saveText: 'Apply',
    );
    if (picked != null && mounted) _setRange(picked.start, picked.end);
  }

  Widget _preset(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(label: Text(label), onPressed: onTap),
      );

  @override
  Widget build(BuildContext context) {
    final repo = HistoryRepository(ref.watch(databaseProvider));
    final today = _today();
    return Scaffold(
      appBar: AppBar(
        title: const Text('History / Previous'),
        actions: [
          IconButton(
            tooltip: 'Choose a period',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pickRange,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showHistoryExportSheet(
          context,
          initialFirst: _first,
          initialLast: _last,
        ),
        icon: const Icon(Icons.download_rounded),
        label: const Text('Download PDF / Excel'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                _preset('Today', () => _setRange(today, today)),
                _preset(
                  'Last 7 days',
                  () => _setRange(
                      DateTime(today.year, today.month, today.day - 6), today),
                ),
                _preset('This month', () => setState(() => _setMonth(today))),
                _preset(
                  'Last month',
                  () => setState(
                      () => _setMonth(DateTime(today.year, today.month - 1, 1))),
                ),
                _preset(
                  'This year',
                  () => _setRange(DateTime(today.year, 1, 1), today),
                ),
                _preset('Custom…', _pickRange),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: _isFullMonth ? 'Previous month' : 'Previous period',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _first == _last
                        ? AppFormatters.date(_first)
                        : '${AppFormatters.date(_first)} – ${AppFormatters.date(_last)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: _isFullMonth ? 'Next month' : 'Next period',
                  onPressed: _canGoNext ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          StreamBuilder<List<HistoryDay>>(
            stream: repo.watchDays(_first, _endExclusive),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Could not load history. Reopen this screen to retry.',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final days = snapshot.data!;
              if (days.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No transactions in this date range.'),
                  ),
                );
              }
              final sales = days.fold<double>(0, (a, d) => a + d.sales);
              final credit = days.fold<double>(0, (a, d) => a + d.credit);
              final received = days.fold<double>(0, (a, d) => a + d.received);
              final records = days.fold<int>(0, (a, d) => a + d.records);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeriodSummary(
                    sales: sales,
                    credit: credit,
                    received: received,
                    records: records,
                    days: days.length,
                  ),
                  ...days.map(
                    (day) => _DayCard(
                      day: day,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryDayScreen(day: day.date),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Sales, credit and collections are separate measures. Invoice-linked payments are counted once. Tap a day for all records.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colours + small widgets shared by the History screens
// ---------------------------------------------------------------------------

class _HC {
  static const sales = Color(0xFF0E7A55);
  static const credit = Color(0xFFD9480F);
  static const received = Color(0xFF1C6FD1);
  static Color forKind(String kind) => kind == 'invoice'
      ? sales
      : kind == 'payment'
          ? received
          : credit;
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({
    required this.sales,
    required this.credit,
    required this.received,
    required this.records,
    required this.days,
  });
  final double sales, credit, received;
  final int records, days;

  Widget _tile(String label, double value, IconData icon) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppFormatters.money(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF0B5A40), Color(0xFF16A06F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E6E4E).withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Period total',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$records ${records == 1 ? 'record' : 'records'} · $days ${days == 1 ? 'day' : 'days'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _tile('Sales', sales, Icons.receipt_long_rounded),
                _tile('Credit', credit, Icons.north_east_rounded),
                _tile('Received', received, Icons.south_west_rounded),
              ],
            ),
          ],
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onTap});
  final HistoryDay day;
  final VoidCallback onTap;

  Widget _line(String label, String value, Color color, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 70,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0E6E4E), Color(0xFF1AA874)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(day.date).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${day.date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        DateFormat('MMM yyyy').format(day.date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line(
                          'Sales (${day.invoiceCount})',
                          AppFormatters.money(day.sales),
                          _HC.sales,
                          Icons.receipt_long_rounded,
                        ),
                        _line(
                          'Credit given',
                          AppFormatters.money(day.credit),
                          _HC.credit,
                          Icons.north_east_rounded,
                        ),
                        _line(
                          'Received',
                          AppFormatters.money(day.received),
                          _HC.received,
                          Icons.south_west_rounded,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.records} ${day.records == 1 ? 'record' : 'records'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryDayScreen extends ConsumerStatefulWidget {
  const HistoryDayScreen({super.key, required this.day});
  final DateTime day;
  @override
  ConsumerState<HistoryDayScreen> createState() => _HistoryDayScreenState();
}

class _HistoryDayScreenState extends ConsumerState<HistoryDayScreen> {
  int _limit = 50;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(AppFormatters.date(widget.day))),
        body: StreamBuilder<List<HistoryRecord>>(
          stream: HistoryRepository(ref.watch(databaseProvider))
              .watchRecords(widget.day, limit: _limit + 1),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(
                child: Text('Could not load records. Please reopen this day.'),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final all = snapshot.data!;
            final rows = all.take(_limit).toList();
            return ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Invoices and ledger movements are listed separately. Do not add invoice amounts to their linked payments. History reflects current saved records, including later edits.',
                  ),
                ),
                ...rows.map((r) {
                  final color = _HC.forKind(r.kind);
                  final label = r.kind == 'invoice'
                      ? 'Invoice sale'
                      : r.kind == 'payment'
                          ? 'Payment received'
                          : 'Credit given';
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Material(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: r.kind == 'invoice'
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InvoicePreviewScreen(invoiceId: r.id),
                                  ),
                                )
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: color, width: 5),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.18),
                                foregroundColor: color,
                                child: Icon(
                                  r.kind == 'invoice'
                                      ? Icons.receipt_long_rounded
                                      : r.kind == 'payment'
                                          ? Icons.south_west_rounded
                                          : Icons.north_east_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$label · ${DateFormat('hh:mm a').format(r.time)}',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (r.note.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          r.note,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppFormatters.money(r.amount),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (all.length > _limit)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _limit += 50),
                      child: const Text('Load 50 more records'),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}
