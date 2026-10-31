import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_providers.dart';
import 'app_snackbar.dart';

/// Opens `config/app.redirect` when it is set.
///
/// Returns `true` when the remote value exists (the caller should stop the
/// normal flow). A missing, empty, or unloadable value returns `false`.
Future<bool> followAppRedirectIfSet(
  BuildContext context,
  WidgetRef ref,
) async {
  final redirect = await _redirectUrl(ref);
  if (redirect == null) return false;

  final uri = _httpUri(redirect);
  if (uri == null) {
    if (context.mounted) {
      AppSnackBar.error(context, 'El enlace de redirección no es válido.');
    }
    return true;
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackBar.error(context, 'No se pudo abrir el enlace.');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.error(context, 'No se pudo abrir el enlace.', cause: e);
    }
  }
  return true;
}

Future<String?> _redirectUrl(WidgetRef ref) async {
  try {
    final config = await ref.read(appConfigProvider.future);
    final redirect = config.redirect;
    if (redirect == null || redirect.isEmpty) return null;
    return redirect;
  } catch (e) {
    debugPrint('App config load failed: $e');
    return null;
  }
}

Uri? _httpUri(String url) {
  final withScheme = url.contains('://') ? url : 'https://$url';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}
