import 'package:flutter_test/flutter_test.dart';
import 'package:businessos/core/calculator_engine.dart';

void main() {
  CalculatorEngine input(String digits) {
    final c = CalculatorEngine();
    for (final d in digits.split('')) {
      c.digit(d);
    }
    return c;
  }

  test('contextual plus/minus percentages', () {
    final c = input('200');
    c.operator('+');
    c.digit('1');
    c.digit('0');
    c.percent();
    c.equals();
    expect(c.display, '220');
    c.clear();
    c.digit('2');
    c.digit('0');
    c.digit('0');
    c.operator('−');
    c.digit('1');
    c.digit('0');
    c.percent();
    c.equals();
    expect(c.display, '180');
  });
  test('multiplication percentage and repeated equals', () {
    final c = input('200');
    c.operator('×');
    c.digit('1');
    c.digit('0');
    c.percent();
    c.equals();
    expect(c.display, '20');
    c.equals();
    expect(c.display, '2');
  });
  test('sign starts a negative second operand', () {
    final c = input('5');
    c.operator('+');
    c.sign();
    c.digit('3');
    c.equals();
    expect(c.display, '2');
  });
  test('zero division can recover without stale operation', () {
    final c = input('8');
    c.operator('÷');
    c.digit('0');
    c.equals();
    expect(c.hasError, true);
    c.digit('7');
    c.operator('+');
    c.digit('1');
    c.equals();
    expect(c.display, '8');
  });
  test('decimal precision and sign backspace', () {
    final c = input('0.1');
    c.operator('+');
    c.digit('0');
    c.digit('.');
    c.digit('2');
    c.equals();
    expect(c.display, '0.3');
    c.clear();
    c.sign();
    c.digit('2');
    c.backspace();
    expect(c.display, '0');
  });
  test('sequential operations and operator replacement', () {
    final c = input('2');
    c.operator('+');
    c.operator('×');
    c.digit('3');
    c.operator('+');
    c.digit('4');
    c.equals();
    expect(c.display, '10');
  });
  test('history is bounded', () {
    final c = input('1');
    c.operator('+');
    c.digit('1');
    for (var i = 0; i < 50; i++) {
      c.equals();
    }
    expect(c.history.length, 30);
  });
}
