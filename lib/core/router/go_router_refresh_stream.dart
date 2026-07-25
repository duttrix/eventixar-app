import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to [Listenable] so [GoRouter] can refresh on auth changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void refresh() => notifyListeners();

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
