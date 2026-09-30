import '../lib/core/calculator_engine.dart';

void main() {
  var checks = 0;
  void check(String expected, CalculatorEngine c) {
    if (c.display != expected)
      throw StateError('Expected $expected, got ${c.display}');
    checks++;
  }

  final c = CalculatorEngine();
  void digits(String value) {
    for (final d in value.split('')) {
      c.digit(d);
    }
  }

  digits('200');
  c.operator('+');
  digits('10');
  c.percent();
  c.equals();
  check('220', c);
  c.clear();
  digits('200');
  c.operator('−');
  digits('10');
  c.percent();
  c.equals();
  check('180', c);
  c.clear();
  digits('200');
  c.operator('×');
  digits('10');
  c.percent();
  c.equals();
  check('20', c);
  c.equals();
  check('2', c);
  c.clear();
  digits('5');
  c.operator('+');
  c.sign();
  digits('3');
  c.equals();
  check('2', c);
  c.clear();
  digits('8');
  c.operator('÷');
  digits('0');
  c.equals();
  check('Error', c);
  digits('7');
  c.operator('+');
  digits('1');
  c.equals();
  check('8', c);
  c.clear();
  digits('0.1');
  c.operator('+');
  digits('0.2');
  c.equals();
  check('0.3', c);
  c.clear();
  c.sign();
  digits('2');
  c.backspace();
  check('0', c);
  c.clear();
  digits('2');
  c.operator('+');
  c.operator('×');
  digits('3');
  c.operator('+');
  digits('4');
  c.equals();
  check('10', c);
  print('$checks calculator smoke checks passed.');
}
