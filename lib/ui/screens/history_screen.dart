import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/history_repository.dart';
import '../../providers/app_providers.dart';
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
      body: ListView(
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
              return Column(
                children: [
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period total',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text('Invoice sales: ${AppFormatters.money(sales)}'),
                          Text('Credit given: ${AppFormatters.money(credit)}'),
                          Text(
                              'Money received: ${AppFormatters.money(received)}'),
                        ],
                      ),
                    ),
                  ),
                  ...days.map((day) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(AppFormatters.date(day.date)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice sales: ${AppFormatters.money(day.sales)} (${day.invoiceCount})',
                              ),
                              Text(
                                'Credit given: ${AppFormatters.money(day.credit)}',
                              ),
                              Text(
                                'Money received: ${AppFormatters.money(day.received)}',
                              ),
                              Text(
                                '${day.records} ${day.records == 1 ? 'record' : 'records'}',
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryDayScreen(day: day.date),
                          ),
                        ),
                      ),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Sales, credit and collections are separate measures. Invoice-linked payments are counted once. Tap a day for all records.',
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
                ...rows.map(
                  (r) => ListTile(
                    leading: Icon(
                      r.kind == 'invoice'
                          ? Icons.receipt_long
                          : r.kind == 'payment'
                              ? Icons.south_west
                              : Icons.north_east,
                    ),
                    title:
                        Text('${r.title} · ${AppFormatters.money(r.amount)}'),
                    subtitle: Text(
                      '${r.kind.toUpperCase()} · ${AppFormatters.dateTimeStr(r.time)}\n${r.note}',
                    ),
                    isThreeLine: true,
                    onTap: r.kind == 'invoice'
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InvoicePreviewScreen(invoiceId: r.id),
                              ),
                            )
                        : null,
                  ),
                ),
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
