import 'package:intl/intl.dart';

/// India-first formatting helpers. Kept as static final fields so the
/// NumberFormat/DateFormat locale data is parsed once, not per call.
class AppFormatters {
  AppFormatters._();

  static const currencies = {
    'INR': 'Indian rupee',
    'USD': 'US dollar',
    'EUR': 'Euro',
    'GBP': 'British pound',
    'AED': 'UAE dirham',
    'CAD': 'Canadian dollar',
    'AUD': 'Australian dollar',
  };
  static String currencyCode = 'INR';
  static final Map<String, NumberFormat> _currencyFormats = {};
  static NumberFormat _format(int digits) => _currencyFormats.putIfAbsent(
    '$currencyCode:$digits',
    () => NumberFormat.currency(
      locale: currencyCode == 'INR' ? 'en_IN' : 'en_US',
      symbol: currencyCode == 'INR' ? '₹' : '$currencyCode ',
      decimalDigits: digits,
    ),
  );
  static NumberFormat get _currency => _format(2);
  static NumberFormat get _currencyWhole => _format(0);

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _dayMonth = DateFormat('dd MMM');
  static final DateFormat _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  static String money(num value) => _currency.format(value);

  /// Whole-rupee formatting for dashboard hero numbers (cleaner at a glance).
  static String moneyWhole(num value) => _currencyWhole.format(value);

  static String date(DateTime d) => _date.format(d);

  static String dateTimeStr(DateTime d) => _dateTime.format(d);

  static String dayMonth(DateTime d) => _dayMonth.format(d);

  static String fileTimestamp(DateTime d) => _fileStamp.format(d);

  static bool isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
