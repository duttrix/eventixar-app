/// Bank transfer details: Firestore `config/payment`.
class PaymentConfig {
  const PaymentConfig({
    this.holderName,
    this.bankName,
    this.alias,
    this.cbu,
    this.cuit,
    this.instructions,
    this.notifyPhone,
  });

  final String? holderName;
  final String? bankName;
  final String? alias;
  final String? cbu;
  final String? cuit;
  final String? instructions;

  /// Digits only for `https://wa.me/{notifyPhone}` (e.g. `5491123456789`).
  final String? notifyPhone;

  bool get hasTransferDetails =>
      (alias != null && alias!.isNotEmpty) || (cbu != null && cbu!.isNotEmpty);

  bool get isUsable => hasTransferDetails || notifyPhone != null;

  factory PaymentConfig.fromFirestore(Map<String, dynamic> data) {
    return PaymentConfig(
      holderName: _text(data['holderName']),
      bankName: _text(data['bankName']),
      alias: _text(data['alias']),
      cbu: _text(data['cbu']),
      cuit: _text(data['cuit']),
      instructions: _text(data['instructions']),
      notifyPhone: _digitsFrom(data['notifyPhone']),
    );
  }

  static String? _text(Object? raw) {
    final text = switch (raw) {
      String s => s.trim(),
      int n => '$n',
      num n => '${n.round()}',
      _ => null,
    };
    if (text == null || text.isEmpty) return null;
    return text;
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
