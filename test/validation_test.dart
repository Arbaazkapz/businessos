import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:businessos/core/validation.dart';

void main() {
  test(
    'prices reject letters, exponent notation, nonfinite and invalid precision',
    () {
      for (final value in [
        'abc',
        '12abc34',
        'NaN',
        'Infinity',
        '1e3',
        '-5',
        '1.234',
        '1000000000001',
      ]) {
        expect(AppValidation.number(value), isNotNull, reason: value);
      }
      expect(AppValidation.number('0'), isNull);
      expect(AppValidation.number('12.50'), isNull);
      expect(AppValidation.number(''), isNotNull);
      expect(AppValidation.number('', optional: true), isNull);
      expect(AppValidation.number('0', positive: true), isNotNull);
      expect(AppValidation.number('101', max: 100), isNotNull);
    },
  );
  test(
    'India has ten digits, international numbers use an explicit prefix',
    () {
      for (final value in [
        '9876543210',
        '+91 98765 43210',
        '+44 7700 900123',
        '',
      ]) {
        expect(AppValidation.phone(value), isNull, reason: value);
      }
      for (final value in [
        '987654321',
        '98765432101',
        '98765abc3210',
        '0000000000',
        '++919876543210',
      ]) {
        expect(AppValidation.phone(value), isNotNull, reason: value);
      }
      expect(AppValidation.phone('9876543210', dialCode: '+91'), isNull);
      expect(AppValidation.phone('987654321', dialCode: '+91'), isNotNull);
      expect(AppValidation.phone('abc9876543210', dialCode: '+91'), isNotNull);
    },
  );
  test('formatter rejects invalid paste intact, preserving original price', () {
    final formatter = DecimalInputFormatter();
    const old = TextEditingValue(text: '12.50');
    expect(
      formatter.formatEditUpdate(old, const TextEditingValue(text: '12abc34')),
      old,
    );
    expect(
      formatter.formatEditUpdate(old, const TextEditingValue(text: '12.501')),
      old,
    );
    expect(
      formatter.formatEditUpdate(old, const TextEditingValue(text: '')).text,
      '',
    );
    expect(
      formatter.formatEditUpdate(old, const TextEditingValue(text: '25.')).text,
      '25.',
    );
  });
  test('person names reject digits; country phone lengths are enforced', () {
    expect(AppValidation.personName('Asha Patel'), isNull);
    expect(AppValidation.personName("D'Souza-Rao"), isNull);
    expect(AppValidation.personName('Asha123'), isNotNull);
    expect(AppValidation.personName('12345'), isNotNull);
    expect(AppValidation.personName(''), isNotNull);
    expect(AppValidation.phone('5876543210', dialCode: '+91'), isNotNull);
    expect(AppValidation.phone('501234567', dialCode: '+971'), isNull);
    expect(AppValidation.phone('5012345678', dialCode: '+971'), isNotNull);
    expect(AppValidation.phone('+971 50 123 4567'), isNull);
    expect(AppValidation.title('Rice 5kg'), isNull);
    expect(AppValidation.title('12345'), isNotNull);
  });
}
