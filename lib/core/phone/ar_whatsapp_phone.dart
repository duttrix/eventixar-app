/// Argentine mobile numbers for `https://wa.me/{digits}`.
class ArWhatsAppPhone {
  ArWhatsAppPhone._();

  static const prefix = '549';

  /// Accepts whatever the user typed (`11 2345-6789`, `01115…`, `+54 9 11…`).
  /// Returns `549…` digits or `null` if it cannot be a mobile number.
  static String? toWaMeDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith(prefix)) {
      digits = digits.substring(prefix.length);
    } else if (digits.startsWith('54')) {
      digits = digits.substring(2);
      if (digits.startsWith('9')) digits = digits.substring(1);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    // Old national form: area + 15 + local (e.g. 11 15 2345-6789).
    if (digits.length >= 12) {
      for (var areaLen = 2; areaLen <= 4; areaLen++) {
        if (areaLen + 2 < digits.length &&
            digits.substring(areaLen, areaLen + 2) == '15') {
          digits =
              digits.substring(0, areaLen) + digits.substring(areaLen + 2);
          break;
        }
      }
    }
    if (digits.length < 8 || digits.length > 10) return null;
    return '$prefix$digits';
  }

  static String display(String waMeDigits) =>
      waMeDigits.startsWith('+') ? waMeDigits : '+$waMeDigits';
}
