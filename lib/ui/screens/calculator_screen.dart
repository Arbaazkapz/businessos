import 'package:flutter/material.dart';

import '../../core/formatters.dart';

enum _Op { add, subtract, multiply, divide }

String _opSymbol(_Op op) => switch (op) {
      _Op.add => '+',
      _Op.subtract => '−',
      _Op.multiply => '×',
      _Op.divide => '÷',
    };

/// A genuine working calculator with standard sequential (left-to-right)
/// evaluation - like a real phone calculator. Shows the full running
/// expression (e.g. "6 × 6 =") above the result, not just raw numbers.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  double? _operand1;
  _Op? _pendingOp;
  bool _shouldResetDisplay = false;
  bool _hasError = false;

  String _formatNumber(double n) {
    if (n.isNaN || n.isInfinite) return 'Error';
    if (n == n.roundToDouble() && n.abs() < 1e15) {
      return n.toStringAsFixed(0);
    }
    var s = n.toStringAsFixed(6);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  double _computeResult(double operand2) {
    return switch (_pendingOp!) {
      _Op.add => _operand1! + operand2,
      _Op.subtract => _operand1! - operand2,
      _Op.multiply => _operand1! * operand2,
      _Op.divide => _operand1! / operand2,
    };
  }

  void _onDigit(String digit) {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _display = digit == '.' ? '0.' : digit;
        _shouldResetDisplay = false;
        _hasError = false;
        if (_pendingOp == null) _expression = '';
        return;
      }
      if (digit == '.' && _display.contains('.')) return;
      if (_display == '0' && digit != '.') {
        _display = digit;
      } else {
        if (_display.length >= 15) return;
        _display += digit;
      }
    });
  }

  void _onOperator(_Op op) {
    setState(() {
      if (_hasError) {
        _hasError = false;
        _display = '0';
      }
      if (_pendingOp != null && !_shouldResetDisplay) {
        final operand2 = double.tryParse(_display) ?? 0;
        if (_pendingOp == _Op.divide && operand2 == 0) {
          _hasError = true;
          _display = 'Error';
          _expression = '';
          _operand1 = null;
          _pendingOp = null;
          return;
        }
        final result = _computeResult(operand2);
        _display = _formatNumber(result);
        _operand1 = result;
      } else {
        _operand1 = double.tryParse(_display) ?? 0;
      }
      _pendingOp = op;
      _expression = '${_formatNumber(_operand1!)} ${_opSymbol(op)}';
      _shouldResetDisplay = true;
    });
  }

  void _onEquals() {
    setState(() {
      if (_hasError || _pendingOp == null) return;
      final operand2 = double.tryParse(_display) ?? 0;
      if (_pendingOp == _Op.divide && operand2 == 0) {
        _hasError = true;
        _display = 'Error';
        _expression = '';
        _operand1 = null;
        _pendingOp = null;
        return;
      }
      final result = _computeResult(operand2);
      _expression = '$_expression ${_formatNumber(operand2)} =';
      _display = _formatNumber(result);
      _operand1 = null;
      _pendingOp = null;
      _shouldResetDisplay = true;
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _expression = '';
      _operand1 = null;
      _pendingOp = null;
      _shouldResetDisplay = false;
      _hasError = false;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _display = '0';
        _hasError = false;
        return;
      }
      if (_display.length <= 1) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _onSign() {
    setState(() {
      final value = double.tryParse(_display) ?? 0;
      _display = _formatNumber(value * -1);
    });
  }

  Future<void> _openGstCalculator() async {
    final seed = double.tryParse(_display) ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GstCalculatorSheet(initialAmount: seed > 0 ? seed : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          TextButton.icon(
            onPressed: _openGstCalculator,
            icon: const Icon(Icons.percent_rounded, size: 18),
            label: const Text('GST'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Display area - given a definite flex-bounded height so the
            // FittedBoxes inside have something concrete to scale down to.
            // (Previously these were unconstrained, so long results rendered
            // at full size and spilled over the button grid below.)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700),
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
                      _CalcButton(label: 'C', kind: _ButtonKind.secondary, onTap: _onClear),
                      _CalcButton(
                          icon: Icons.backspace_outlined,
                          kind: _ButtonKind.secondary,
                          onTap: _onBackspace),
                      _CalcButton(
                          label: '%',
                          kind: _ButtonKind.secondary,
                          onTap: () {
                            setState(() {
                              final value = double.tryParse(_display) ?? 0;
                              _display = _formatNumber(value / 100);
                            });
                          }),
                      _CalcButton(
                          label: '÷',
                          kind: _ButtonKind.operator,
                          onTap: () => _onOperator(_Op.divide)),
                    ]),
                    _CalcRow([
                      _CalcButton(label: '7', onTap: () => _onDigit('7')),
                      _CalcButton(label: '8', onTap: () => _onDigit('8')),
                      _CalcButton(label: '9', onTap: () => _onDigit('9')),
                      _CalcButton(
                          label: '×',
                          kind: _ButtonKind.operator,
                          onTap: () => _onOperator(_Op.multiply)),
                    ]),
                    _CalcRow([
                      _CalcButton(label: '4', onTap: () => _onDigit('4')),
                      _CalcButton(label: '5', onTap: () => _onDigit('5')),
                      _CalcButton(label: '6', onTap: () => _onDigit('6')),
                      _CalcButton(
                          label: '−',
                          kind: _ButtonKind.operator,
                          onTap: () => _onOperator(_Op.subtract)),
                    ]),
                    _CalcRow([
                      _CalcButton(label: '1', onTap: () => _onDigit('1')),
                      _CalcButton(label: '2', onTap: () => _onDigit('2')),
                      _CalcButton(label: '3', onTap: () => _onDigit('3')),
                      _CalcButton(
                          label: '+',
                          kind: _ButtonKind.operator,
                          onTap: () => _onOperator(_Op.add)),
                    ]),
                    _CalcRow([
                      _CalcButton(label: '+/-', kind: _ButtonKind.secondary, onTap: _onSign),
                      _CalcButton(label: '0', onTap: () => _onDigit('0')),
                      _CalcButton(label: '.', onTap: () => _onDigit('.')),
                      _CalcButton(label: '=', kind: _ButtonKind.equals, onTap: _onEquals),
                    ]),
                  ],
                ),
              ),
            ),
          ],
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
      _ButtonKind.operator => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ButtonKind.secondary => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
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
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg),
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
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final double base;
    final double gstAmount;
    final double total;
    if (_isExclusive) {
      base = amount;
      gstAmount = amount * _rate / 100;
      total = base + gstAmount;
    } else {
      total = amount;
      base = amount / (1 + _rate / 100);
      gstAmount = total - base;
    }
    final halfGst = gstAmount / 2;

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
          Text('GST Calculator', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            autofocus: widget.initialAmount == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._gstRates.map((r) => ChoiceChip(
                    label: Text('${r.toStringAsFixed(0)}%'),
                    selected: !_customRate && _rate == r,
                    onSelected: (_) => setState(() {
                      _rate = r;
                      _customRate = false;
                    }),
                  )),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _customRate,
                onSelected: (_) => setState(() => _customRate = true),
              ),
            ],
          ),
          if (_customRate) ...[
            const SizedBox(height: 12),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Custom GST %', suffixText: '%'),
              onChanged: (v) => setState(() => _rate = double.tryParse(v.trim()) ?? _rate),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Amount excl. GST')),
              ButtonSegment(value: false, label: Text('Amount incl. GST')),
            ],
            selected: {_isExclusive},
            onSelectionChanged: (s) => setState(() => _isExclusive = s.first),
          ),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _GstRow('Base amount', base),
                  _GstRow('GST (${_rate.toStringAsFixed(_rate == _rate.roundToDouble() ? 0 : 1)}%)',
                      gstAmount),
                  _GstRow('  - CGST', halfGst, muted: true),
                  _GstRow('  - SGST', halfGst, muted: true),
                  const Divider(),
                  _GstRow('Total', total, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'CGST/SGST split assumes an intrastate sale. For interstate sales this would be IGST instead - check with your accountant for what applies to you.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _GstRow extends StatelessWidget {
  const _GstRow(this.label, this.value, {this.bold = false, this.muted = false});
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
          Text(label, style: style),
          Text(AppFormatters.money(value), style: style),
        ],
      ),
    );
  }
}
