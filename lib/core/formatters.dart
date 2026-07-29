import 'package:intl/intl.dart';

/// India-first formatting helpers. Kept as static final fields so the
/// NumberFormat/DateFormat locale data is parsed once, not per call.
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static final NumberFormat _currencyWhole =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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
