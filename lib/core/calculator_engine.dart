/// A shop-style sequential calculator: 2 + 3 × 4 = 20.
/// Percent is contextual: 200 + 10% = 220; 200 × 10% = 20.
class CalculatorEngine {
  String display = '0';
  String expression = '';
  final List<String> history = [];
  double? _left;
  String? _operator;
  String? _repeatOperator;
  double? _repeatRight;
  bool _fresh = false;
  bool get hasError => display == 'Error';

  static String format(double value) {
    if (!value.isFinite) return 'Error';
    if (value == 0) return '0';
    final rounded = double.parse(value.toStringAsPrecision(12));
    if (rounded.abs() >= 1e12 || rounded.abs() < 1e-8) {
      return rounded
          .toStringAsExponential(8)
          .replaceFirst(RegExp(r'\.?0+e'), 'e');
    }
    return rounded.toStringAsFixed(10).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void clear() {
    display = '0';
    expression = '';
    _left = null;
    _operator = null;
    _repeatOperator = null;
    _repeatRight = null;
    _fresh = false;
  }

  void digit(String digit) {
    if (hasError) clear();
    if (_fresh) {
      display = '0';
      _fresh = false;
      if (_operator == null) {
        expression = '';
        _repeatOperator = null;
      }
    }
    if (digit == '.' && display.contains('.')) return;
    if (display.replaceAll(RegExp(r'[^0-9]'), '').length >= 12) return;
    if (digit == '.') {
      display += '.';
    } else if (display == '0') {
      display = digit;
    } else if (display == '-0') {
      display = '-$digit';
    } else {
      display += digit;
    }
  }

  double _calculate(double a, String op, double b) => switch (op) {
    '+' => a + b,
    '−' => a - b,
    '×' => a * b,
    '÷' => a / b,
    _ => throw ArgumentError('Unknown operator'),
  };

  void operator(String op) {
    if (hasError) return;
    if (_operator != null && !_fresh) {
      display = format(_calculate(_left!, _operator!, double.parse(display)));
      if (hasError) {
        _operator = null;
        return;
      }
    }
    _left = double.parse(display);
    _operator = op;
    _repeatOperator = null;
    expression = '$display $op';
    _fresh = true;
  }

  void equals() {
    if (hasError) return;
    final op = _operator ?? _repeatOperator;
    if (op == null) return;
    final a = _operator != null ? _left! : double.parse(display);
    final b = _operator != null ? double.parse(display) : _repeatRight!;
    expression = '${format(a)} $op ${format(b)} =';
    display = format(_calculate(a, op, b));
    if (!hasError) {
      history.insert(0, '$expression $display');
      if (history.length > 30) history.removeLast();
    }
    _repeatOperator = op;
    _repeatRight = b;
    _operator = null;
    _fresh = true;
  }

  void sign() {
    if (hasError) return;
    if (_fresh && _operator != null) display = '0';
    display = display.startsWith('-') ? display.substring(1) : '-$display';
    _fresh = false;
  }

  void percent() {
    if (hasError) return;
    final value = double.parse(display);
    display = format(
      (_operator == '+' || _operator == '−')
          ? _left! * value / 100
          : value / 100,
    );
    _fresh = false;
  }

  void backspace() {
    if (hasError) {
      clear();
      return;
    }
    if (_fresh || display.contains('e')) {
      display = '0';
      _fresh = false;
      return;
    }
    display = display.length > 1
        ? display.substring(0, display.length - 1)
        : '0';
    if (display == '-') display = '0';
  }
}
