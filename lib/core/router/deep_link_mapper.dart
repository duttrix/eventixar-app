/// Maps external invite URLs / custom schemes into in-app GoRouter paths.
///
/// Ticket QR payloads are **not** deep links: buyers get an image, and
/// validators scan the QR inside the app.
class DeepLinkMapper {
  DeepLinkMapper._();

  static const customScheme = 'eventixar';

  /// Invite hosts. Share links use `eventixar.web.app`; others are aliases.
  static const httpsHosts = {
    'eventixar.web.app',
    'eventixar.firebaseapp.com',
    'app.eventixar.com',
  };

  /// Returns a GoRouter location (`/join/...`) or null.
  static String? locationFromUri(Uri uri) {
    if (uri.scheme == customScheme) {
      // eventixar://join/{token}
      final segments = [
        if (uri.host.isNotEmpty) uri.host,
        ...uri.pathSegments.where((s) => s.isNotEmpty),
      ];
      return _fromSegments(segments);
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        httpsHosts.contains(uri.host)) {
      return _fromSegments(uri.pathSegments.where((s) => s.isNotEmpty).toList());
    }

    return null;
  }

  static String? _fromSegments(List<String> segments) {
    if (segments.length >= 2 && segments[0] == 'join') {
      return '/join/${segments[1]}';
    }
    return null;
  }
}
