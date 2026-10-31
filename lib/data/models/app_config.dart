/// Remote app settings: Firestore `config/app`.
///
/// Add fields here as the document grows. Empty or missing values stay null
/// so the app keeps its normal flow.
class AppConfig {
  const AppConfig({this.redirect});

  /// External URL for “Crear evento” and “Finalizar evento”.
  final String? redirect;

  bool get hasRedirect => redirect != null && redirect!.isNotEmpty;

  factory AppConfig.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const AppConfig();
    return AppConfig(redirect: _text(data['redirect']));
  }

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    return text;
  }
}
