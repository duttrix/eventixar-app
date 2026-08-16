import 'package:intl/intl.dart';

/// Money label with `$` always before the amount (es_AR thousands separators).
///
/// Avoids `NumberFormat.currency(locale: 'es_AR')`, which places the symbol after.
String formatMoney(num amount, {int decimalDigits = 0}) {
  final number = NumberFormat.decimalPatternDigits(
    locale: 'es_AR',
    decimalDigits: decimalDigits,
  );
  return '\$${number.format(amount)}';
}
