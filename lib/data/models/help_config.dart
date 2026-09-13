/// Remote help/support settings: Firestore `config/help`.
///
/// Add fields here as we grow support (hours, etc.).
class HelpConfig {
  const HelpConfig({this.phoneNumber});

  /// Digits only for `https://wa.me/{phoneNumber}` (e.g. `5491123456789`).
  final String? phoneNumber;

  factory HelpConfig.fromFirestore(Map<String, dynamic> data) {
    return HelpConfig(phoneNumber: _digitsFrom(data['phoneNumber']));
  }

  static String? _digitsFrom(Object? raw) {
    final text = switch (raw) {
      String s => s,
      int n => '$n',
      num n => '${n.round()}',
      _ => null,
    };
    if (text == null) return null;
    var digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length < 8) return null;
    return digits;
  }
}
