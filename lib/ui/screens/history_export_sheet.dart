import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/history_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/history_export_service.dart';

/// Opens the "Download statement" modal (PDF / Excel for a chosen period).
Future<void> showHistoryExportSheet(
  BuildContext context, {
  required DateTime initialFirst,
  required DateTime initialLast,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ExportSheet(first: initialFirst, last: initialLast),
  );
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({required this.first, required this.last});
  final DateTime first, last;
  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  late DateTime _first;
  late DateTime _last;
  String _format = 'pdf';
  List<ExportRow>? _rows;
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;
  int _token = 0;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _today() => _day(DateTime.now());

  @override
  void initState() {
    super.initState();
    final today = _today();
    _first = _day(widget.first);
    _last = _day(widget.last);
    if (_last.isAfter(today)) _last = today;
    if (_first.isAfter(_last)) _first = _last;
    _load();
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final rows = await HistoryRepository(ref.read(databaseProvider))
          .fetchExportRows(
        _first,
        DateTime(_last.year, _last.month, _last.day + 1),
      );
      if (!mounted || token != _token) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _rows = null;
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _setRange(DateTime first, DateTime last) {
    final today = _today();
    var f = _day(first);
    var l = _day(last);
    if (l.isAfter(today)) l = today;
    if (f.isAfter(l)) f = l;
    setState(() {
      _first = f;
      _last = l;
    });
    _load();
  }

  Future<void> _pick() async {
    final today = _today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(start: _first, end: _last),
      helpText: 'Statement period',
      saveText: 'Apply',
    );
    if (picked != null && mounted) _setRange(picked.start, picked.end);
  }

  // Indian financial year: 1 April - 31 March.
  DateTime _fyStart(DateTime d) =>
      d.month >= 4 ? DateTime(d.year, 4, 1) : DateTime(d.year - 1, 4, 1);

  Future<void> _generate() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      // Let the spinner paint before the heavy work starts.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final business = await ref.read(businessProfileProvider.future);
      if (_format == 'pdf') {
        final bytes = await HistoryExportService.buildPdf(
          business: business,
          rows: rows,
          first: _first,
          last: _last,
        );
        await HistoryExportService.saveAndShare(
          bytes: bytes,
          name: HistoryExportService.fileName(_first, _last, 'pdf'),
          mimeType: 'application/pdf',
        );
      } else {
        final bytes = HistoryExportService.buildXlsx(
          business: business,
          rows: rows,
          first: _first,
          last: _last,
        );
        await HistoryExportService.saveAndShare(
          bytes: bytes,
          name: HistoryExportService.fileName(_first, _last, 'xlsx'),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not create the file. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _today();
    final fy = _fyStart(today);
    final rows = _rows;
    final tooMany =
        rows != null && rows.length > HistoryExportService.maxRows;
    final canGenerate = !_busy &&
        !_loading &&
        rows != null &&
        rows.isNotEmpty &&
        !tooMany;

    String status;
    Color statusColor = scheme.onSurfaceVariant;
    if (_loading) {
      status = 'Counting records…';
    } else if (_loadFailed) {
      status = 'Could not read records. Change the period to retry.';
      statusColor = scheme.error;
    } else if (tooMany) {
      status =
          'Too many records (${rows.length}). Choose a shorter period (max ${HistoryExportService.maxRows}).';
      statusColor = scheme.error;
    } else if (rows == null || rows.isEmpty) {
      status = 'No transactions in this period.';
    } else {
      status =
          '${rows.length} ${rows.length == 1 ? 'record' : 'records'} will be included.';
      statusColor = const Color(0xFF0E7A55);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Download statement',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the period and format. Share it with your CA or keep a copy for yourself.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _busy ? null : _pick,
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Period',
                              style: TextStyle(fontSize: 12)),
                          Text(
                            _first == _last
                                ? AppFormatters.date(_first)
                                : '${AppFormatters.date(_first)} – ${AppFormatters.date(_last)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: const Text('This month'),
                  onPressed: _busy
                      ? null
                      : () => _setRange(
                            DateTime(today.year, today.month, 1),
                            today,
                          ),
                ),
                ActionChip(
                  label: const Text('Last month'),
                  onPressed: _busy
                      ? null
                      : () => _setRange(
                            DateTime(today.year, today.month - 1, 1),
                            DateTime(today.year, today.month, 0),
                          ),
                ),
                ActionChip(
                  label: const Text('This financial year'),
                  onPressed: _busy ? null : () => _setRange(fy, today),
                ),
                ActionChip(
                  label: const Text('Last financial year'),
                  onPressed: _busy
                      ? null
                      : () => _setRange(
                            DateTime(fy.year - 1, 4, 1),
                            DateTime(fy.year, 3, 31),
                          ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'pdf',
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: Text('PDF'),
                ),
                ButtonSegment(
                  value: 'xlsx',
                  icon: Icon(Icons.table_chart_outlined),
                  label: Text('Excel'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: canGenerate ? _generate : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _busy
                    ? 'Preparing…'
                    : 'Create ${_format == 'pdf' ? 'PDF' : 'Excel'} & share',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'In the share menu choose "Save to device", Drive, WhatsApp or e-mail.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
