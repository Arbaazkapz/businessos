import 'package:flutter/material.dart';

enum _Op { add, subtract, multiply, divide }

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
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

  void _onDigit(String digit) {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _display = digit == '.' ? '0.' : digit;
        _shouldResetDisplay = false;
        _hasError = false;
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

  void _applyPendingOp() {
    if (_pendingOp == null || _operand1 == null) return;
    final operand2 = double.tryParse(_display) ?? 0;

    if (_pendingOp == _Op.divide && operand2 == 0) {
      _hasError = true;
      _display = 'Error';
      _operand1 = null;
      _pendingOp = null;
      return;
    }

    final result = switch (_pendingOp!) {
      _Op.add => _operand1! + operand2,
      _Op.subtract => _operand1! - operand2,
      _Op.multiply => _operand1! * operand2,
      _Op.divide => _operand1! / operand2,
    };

    _display = _formatNumber(result);
    _operand1 = result;
  }

  void _onOperator(_Op op) {
    setState(() {
      if (_hasError) {
        _hasError = false;
        _display = '0';
      }
      if (_pendingOp != null && !_shouldResetDisplay) {
        _applyPendingOp();
      } else {
        _operand1 = double.tryParse(_display) ?? 0;
      }
      _pendingOp = op;
      _shouldResetDisplay = true;
    });
  }

  void _onEquals() {
    setState(() {
      if (_hasError) return;
      _applyPendingOp();
      _pendingOp = null;
      _shouldResetDisplay = true;
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _operand1 = null;
      _pendingOp = null;
      _shouldResetDisplay = false;
      _hasError = false;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _onClear();
        return;
      }
      if (_display.length <= 1) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _onPercent() {
    setState(() {
      final value = double.tryParse(_display) ?? 0;
      _display = _formatNumber(value / 100);
    });
  }

  void _onSign() {
    setState(() {
      final value = double.tryParse(_display) ?? 0;
      _display = _formatNumber(value * -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _display,
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  Row(children: [
                    _CalcButton(label: 'C', kind: _ButtonKind.secondary, onTap: _onClear),
                    _CalcButton(label: '+/-', kind: _ButtonKind.secondary, onTap: _onSign),
                    _CalcButton(label: '%', kind: _ButtonKind.secondary, onTap: _onPercent),
                    _CalcButton(
                        label: '÷',
                        kind: _ButtonKind.operator,
                        onTap: () => _onOperator(_Op.divide)),
                  ]),
                  Row(children: [
                    _CalcButton(label: '7', onTap: () => _onDigit('7')),
                    _CalcButton(label: '8', onTap: () => _onDigit('8')),
                    _CalcButton(label: '9', onTap: () => _onDigit('9')),
                    _CalcButton(
                        label: '×',
                        kind: _ButtonKind.operator,
                        onTap: () => _onOperator(_Op.multiply)),
                  ]),
                  Row(children: [
                    _CalcButton(label: '4', onTap: () => _onDigit('4')),
                    _CalcButton(label: '5', onTap: () => _onDigit('5')),
                    _CalcButton(label: '6', onTap: () => _onDigit('6')),
                    _CalcButton(
                        label: '−',
                        kind: _ButtonKind.operator,
                        onTap: () => _onOperator(_Op.subtract)),
                  ]),
                  Row(children: [
                    _CalcButton(label: '1', onTap: () => _onDigit('1')),
                    _CalcButton(label: '2', onTap: () => _onDigit('2')),
                    _CalcButton(label: '3', onTap: () => _onDigit('3')),
                    _CalcButton(
                        label: '+', kind: _ButtonKind.operator, onTap: () => _onOperator(_Op.add)),
                  ]),
                  Row(children: [
                    _CalcButton(label: '0', flex: 2, onTap: () => _onDigit('0')),
                    _CalcButton(label: '.', onTap: () => _onDigit('.')),
                    _CalcButton(
                        icon: Icons.backspace_outlined,
                        kind: _ButtonKind.secondary,
                        onTap: _onBackspace),
                  ]),
                  Row(children: [
                    _CalcButton(
                      label: '=',
                      flex: 4,
                      kind: _ButtonKind.equals,
                      onTap: _onEquals,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

enum _ButtonKind { digit, operator, secondary, equals }

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    this.label,
    this.icon,
    this.kind = _ButtonKind.digit,
    this.flex = 1,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final _ButtonKind kind;
  final int flex;
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

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: kind == _ButtonKind.equals ? 4 : 1,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: fg)
                    : Text(
                        label ?? '',
                        style:
                            TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: fg),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
