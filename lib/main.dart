import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: EventixarApp()));
}

/// Root widget for Eventixar (internal system name: "Sistema de Cupones").
///
/// This build is a fully mocked UI scaffold: navigation, screens and sample
/// data are all wired up, but there is no real backend/auth yet — see
/// lib/data/mock/mock_repository.dart for the in-memory data source.
class EventixarApp extends ConsumerWidget {
  const EventixarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Eventixar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
