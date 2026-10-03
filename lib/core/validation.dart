import 'package:flutter/services.dart';

import 'country_codes.dart';

class AppValidation {
  static String? name(String? value, {String label = 'Name'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length > 120) return '$label must be 120 characters or fewer.';
    return null;
  }

  /// A person's name: letters (any language), spaces and . ' - only.
  /// Digits and symbols are rejected.
  static String? personName(String? value, {String label = 'Name'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length < 2) return '$label must be at least 2 characters.';
    if (text.length > 80) return '$label must be 80 characters or fewer.';
    if (!RegExp(r"^[\p{L}\p{M}][\p{L}\p{M} .'\u2019\-]*$", unicode: true)
        .hasMatch(text)) {
      return '$label can contain letters only (no numbers or symbols).';
    }
    return null;
  }

  /// A business / product / item name: must contain at least one letter,
  /// may also contain digits and common punctuation.
  static String? title(String? value, {String label = 'Name'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length > 120) return '$label must be 120 characters or fewer.';
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(text)) {
      return '$label must contain at least one letter.';
    }
    return null;
  }

  static String? number(
    String? value, {
    String label = 'Amount',
    bool optional = false,
    bool positive = false,
    int decimals = 2,
    double max = 1000000000000,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return optional ? null : '$label is required.';
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text))
      return 'Enter $label using numbers only.';
    final n = double.tryParse(text);
    if (n == null || !n.isFinite || n > max || n < 0)
      return '$label must be between 0 and $max.';
    if (positive && n <= 0) return '$label must be greater than zero.';
    if (text.contains('.') && text.split('.').last.length > decimals)
      return '$label allows up to $decimals decimal places.';
    return null;
  }

  /// Allowed national-number lengths (digits after the country code).
  static const Map<String, List<int>> _nationalLengths = {
    '+91': [10, 10],
    '+1': [10, 10],
    '+44': [9, 10],
    '+971': [9, 9],
    '+966': [9, 9],
    '+974': [8, 8],
    '+965': [8, 8],
    '+973': [8, 8],
    '+968': [8, 8],
    '+65': [8, 8],
    '+60': [9, 10],
    '+61': [9, 9],
    '+977': [10, 10],
    '+880': [10, 10],
    '+92': [10, 10],
    '+94': [9, 9],
    '+86': [11, 11],
    '+81': [10, 10],
    '+82': [9, 10],
    '+62': [9, 12],
    '+66': [9, 9],
    '+84': [9, 10],
    '+63': [10, 10],
    '+852': [8, 8],
  };

  static String? _nationalCheck(String dial, String national) {
    final range = _nationalLengths[dial];
    if (RegExp(r'^0+$').hasMatch(national)) return 'Enter a valid phone number.';
    if (range == null) {
      if (national.length < 6 || national.length > 14) {
        return 'Phone number must be 6–14 digits after $dial.';
      }
      return null;
    }
    if (national.length < range[0] || national.length > range[1]) {
      final need = range[0] == range[1]
          ? '${range[0]} digits'
          : '${range[0]}–${range[1]} digits';
      return 'Phone numbers for $dial must have $need.';
    }
    if (dial == '+91' && !RegExp(r'^[6-9]').hasMatch(national)) {
      return 'Indian mobile numbers start with 6, 7, 8 or 9.';
    }
    return null;
  }

  static String? phone(String? value, {String? dialCode}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text)) {
      return 'Phone number can contain digits only.';
    }
    final clean = text.replaceAll(RegExp(r'[ ()-]'), '');
    if (dialCode != null) {
      if (clean.startsWith('+')) {
        return 'Enter the local number without a country code.';
      }
      return _nationalCheck(dialCode, clean);
    }
    // No country selected: bare numbers are Indian, +xx numbers are matched
    // against the known country codes (longest code first).
    if (!clean.startsWith('+')) return _nationalCheck('+91', clean);
    final codes = countryCodes.map((c) => c.dialCode).toSet().toList()
      ..sort((x, y) => y.length.compareTo(x.length));
    for (final code in codes) {
      if (clean.startsWith(code)) {
        return _nationalCheck(code, clean.substring(code.length));
      }
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(clean)) {
      return 'Use +country code and 8–15 digits in total.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 120 ||
        !RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
            .hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Optional free-text (address, notes, category, barcode).
  static String? optionalText(String? value,
      {String label = 'This field', int max = 250}) {
    final text = value?.trim() ?? '';
    if (text.length > max) return '$label must be $max characters or fewer.';
    return null;
  }

  static String? barcode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9\-]{4,32}$').hasMatch(text)) {
      return 'Barcode: 4–32 letters, digits or dashes.';
    }
    return null;
  }

  static String? taxId(String? value, {bool india = true}) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 40) return 'Tax ID must be 40 characters or fewer.';
    if (india &&
        !RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
            .hasMatch(text)) {
      return 'Enter a 15-character GSTIN, or leave it empty.';
    }
    return null;
  }

  static void requireValid(String? error) {
    if (error != null) throw ArgumentError(error);
  }
}

/// Reject the entire invalid edit (including pasted letters), rather than
/// silently changing a pasted price such as “12abc34” into a different amount.
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.decimals = 2});
  final int decimals;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pattern = RegExp('^\\d{0,13}(?:\\.\\d{0,$decimals})?\$');
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// Allows only phone characters while typing (digits, +, spaces, brackets, dash).
class PhoneInputFormatter extends TextInputFormatter {
  static final _ok = RegExp(r'^\+?[0-9 ()-]{0,20}$');
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      _ok.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Stops digits and symbols being typed into a person's name.
final TextInputFormatter personNameFormatter =
    FilteringTextInputFormatter.allow(
  RegExp(r"[\p{L}\p{M} .'\u2019\-]", unicode: true),
);
