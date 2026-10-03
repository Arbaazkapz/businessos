import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/calculator_engine.dart';
import '../../core/formatters.dart';
import '../../core/validation.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _calculator = CalculatorEngine();
  String get _display => _calculator.display;
  String get _expression => _calculator.expression;
  void _act(void Function() action) {
    HapticFeedback.selectionClick();
    setState(action);
  }

  void _onDigit(String value) => _act(() => _calculator.digit(value));
  void _onOperator(String value) => _act(() => _calculator.operator(value));
  void _onEquals() => _act(_calculator.equals);
  void _onClear() => _act(_calculator.clear);
  void _onBackspace() => _act(_calculator.backspace);
  void _onSign() => _act(_calculator.sign);

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Recent calculations'),
              subtitle: Text('This session · tap to copy'),
            ),
            if (_calculator.history.isEmpty)
              const ListTile(
                title: Text('Your calculations will appear here.'),
              ),
            ..._calculator.history.map(
              (entry) => ListTile(
                title: Text(entry),
                trailing: const Icon(Icons.copy_outlined),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: entry));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calculation copied')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGstCalculator() async {
    final seed = double.tryParse(_display) ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SingleChildScrollView(
        child: _GstCalculatorSheet(initialAmount: seed > 0 ? seed : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick calculator'),
        actions: [
          IconButton(
            tooltip: 'Recent calculations',
            onPressed: _showHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          TextButton.icon(
            onPressed: _openGstCalculator,
            icon: const Icon(Icons.percent_rounded, size: 18),
            label: const Text('Tax'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: SizedBox(
              height: math.max(
                constraints.maxHeight,
                520 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'OFFLINE · STEP-BY-STEP',
                            style: TextStyle(fontSize: 11, letterSpacing: 1.3),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy result',
                          onPressed: _calculator.hasError
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(text: _display),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Result copied'),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy_outlined, size: 19),
                        ),
                      ],
                    ),
                  ),
                  // Display area - given a definite flex-bounded height so the
                  // FittedBoxes inside have something concrete to scale down to.
                  // (Previously these were unconstrained, so long results rendered
                  // at full size and spilled over the button grid below.)
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primaryContainer.withValues(alpha: 0.65),
                            scheme.surfaceContainerLow,
                          ],
                        ),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 1,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomRight,
                              child: Text(
                                _expression,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomRight,
                              child: Text(
                                _display,
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Uniform 4x5 button grid - every button is the same size, no
                  // odd double-width cells, so nothing looks mismatched.
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          _CalcRow([
                            _CalcButton(
                              label: 'C',
                              kind: _ButtonKind.secondary,
                              onTap: _onClear,
                            ),
                            _CalcButton(
                              icon: Icons.backspace_outlined,
                              kind: _ButtonKind.secondary,
                              onTap: _onBackspace,
                            ),
                            _CalcButton(
                              label: '%',
                              kind: _ButtonKind.secondary,
                              onTap: () => _act(_calculator.percent),
                            ),
                            _CalcButton(
                              label: '÷',
                              kind: _ButtonKind.operator,
                              onTap: () => _onOperator('÷'),
                            ),
                          ]),
                          _CalcRow([
                            _CalcButton(label: '7', onTap: () => _onDigit('7')),
                            _CalcButton(label: '8', onTap: () => _onDigit('8')),
                            _CalcButton(label: '9', onTap: () => _onDigit('9')),
                            _CalcButton(
                              label: '×',
                              kind: _ButtonKind.operator,
                              onTap: () => _onOperator('×'),
                            ),
                          ]),
                          _CalcRow([
                            _CalcButton(label: '4', onTap: () => _onDigit('4')),
                            _CalcButton(label: '5', onTap: () => _onDigit('5')),
                            _CalcButton(label: '6', onTap: () => _onDigit('6')),
                            _CalcButton(
                              label: '−',
                              kind: _ButtonKind.operator,
                              onTap: () => _onOperator('−'),
                            ),
                          ]),
                          _CalcRow([
                            _CalcButton(label: '1', onTap: () => _onDigit('1')),
                            _CalcButton(label: '2', onTap: () => _onDigit('2')),
                            _CalcButton(label: '3', onTap: () => _onDigit('3')),
                            _CalcButton(
                              label: '+',
                              kind: _ButtonKind.operator,
                              onTap: () => _onOperator('+'),
                            ),
                          ]),
                          _CalcRow([
                            _CalcButton(
                              label: '±',
                              kind: _ButtonKind.secondary,
                              onTap: _onSign,
                            ),
                            _CalcButton(label: '0', onTap: () => _onDigit('0')),
                            _CalcButton(label: '.', onTap: () => _onDigit('.')),
                            _CalcButton(
                              label: '=',
                              kind: _ButtonKind.equals,
                              onTap: _onEquals,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow(this.buttons);
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(children: buttons.map((b) => Expanded(child: b)).toList()),
    );
  }
}

enum _ButtonKind { digit, operator, secondary, equals }

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    this.label,
    this.icon,
    this.kind = _ButtonKind.digit,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final _ButtonKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (kind) {
      _ButtonKind.operator => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      _ButtonKind.secondary => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _ButtonKind.equals => (scheme.primary, scheme.onPrimary),
      _ButtonKind.digit => (scheme.surfaceContainerHigh, scheme.onSurface),
    };

    return Padding(
      padding: const EdgeInsets.all(5),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: bg,
          elevation: kind == _ButtonKind.equals ? 1 : 0,
          shadowColor: scheme.shadow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: fg)
                  : FittedBox(
                      child: Text(
                        label ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GST QUICK CALCULATOR
// ---------------------------------------------------------------------------

const _gstRates = [5.0, 12.0, 18.0, 28.0];

class _GstCalculatorSheet extends StatefulWidget {
  const _GstCalculatorSheet({this.initialAmount});
  final double? initialAmount;

  @override
  State<_GstCalculatorSheet> createState() => _GstCalculatorSheetState();
}

class _GstCalculatorSheetState extends State<_GstCalculatorSheet> {
  late final TextEditingController _amountCtrl;
  double _rate = 18.0;
  bool _customRate = false;
  bool _rateValid = true;
  bool _showIndiaSplit = AppFormatters.currencyCode == 'INR';
  bool _isExclusive = true; // true = amount entered is BEFORE tax

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.initialAmount != null ? _trim(widget.initialAmount!) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _trim(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(_amountCtrl.text.trim());
    final amountValid =
        parsed != null &&
        parsed.isFinite &&
        parsed >= 0 &&
        parsed <= 1000000000000;
    final amount = amountValid ? parsed : 0.0;
    double money(double value) => (value * 100).round() / 100;
    final double base;
    final double gstAmount;
    final double total;
    if (_isExclusive) {
      base = money(amount);
      gstAmount = money(base * _rate / 100);
      total = money(base + gstAmount);
    } else {
      total = money(amount);
      base = money(total / (1 + _rate / 100));
      gstAmount = money(total - base);
    }
    final cgst = money(gstAmount / 2);
    final sgst = money(gstAmount - cgst);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tax calculator', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            autofocus: widget.initialAmount == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Amount (${AppFormatters.currencyCode})',
              errorText: _amountCtrl.text.isNotEmpty && !amountValid
                  ? 'Enter an amount from 0 to 1 trillion.'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._gstRates.map(
                (r) => ChoiceChip(
                  label: Text('${r.toStringAsFixed(0)}%'),
                  selected: !_customRate && _rate == r,
                  onSelected: (_) => setState(() {
                    _rate = r;
                    _customRate = false;
                    _rateValid = true;
                  }),
                ),
              ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _customRate,
                onSelected: (_) => setState(() => _customRate = true),
              ),
            ],
          ),
          if (_customRate) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _rate.toString(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Custom tax % (0–100)',
                suffixText: '%',
                errorText: _rateValid
                    ? null
                    : 'Enter a percentage from 0 to 100.',
              ),
              onChanged: (v) => setState(() {
                final rate = double.tryParse(v.trim());
                _rateValid =
                    rate != null && rate.isFinite && rate >= 0 && rate <= 100;
                _rate = _rateValid ? rate! : 0;
              }),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Add tax')),
              ButtonSegment(value: false, label: Text('Remove tax')),
            ],
            selected: {_isExclusive},
            onSelectionChanged: (s) => setState(() => _isExclusive = s.first),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show India GST split'),
            value: _showIndiaSplit,
            onChanged: (value) => setState(() => _showIndiaSplit = value),
          ),
          const SizedBox(height: 20),
          if (amountValid && _rateValid)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _GstRow('Base amount', base),
                    _GstRow(
                      'Tax (${_rate.toStringAsFixed(_rate == _rate.roundToDouble() ? 0 : 1)}%)',
                      gstAmount,
                    ),
                    if (_showIndiaSplit) ...[
                      _GstRow('CGST', cgst, muted: true),
                      _GstRow('SGST', sgst, muted: true),
                    ],
                    const Divider(),
                    _GstRow('Total', total, bold: true),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_showIndiaSplit)
            Text(
              'CGST/SGST split assumes an intrastate sale. For interstate sales this would be IGST instead - check with your accountant for what applies to you.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _GstRow extends StatelessWidget {
  const _GstRow(
    this.label,
    this.value, {
    this.bold = false,
    this.muted = false,
  });
  final String label;
  final double value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : (muted ? 13 : 14),
      color: muted ? Theme.of(context).colorScheme.onSurfaceVariant : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(AppFormatters.money(value), style: style),
            ),
          ),
        ],
      ),
    );
  }
}
