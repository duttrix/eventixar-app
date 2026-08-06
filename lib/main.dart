import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/router/deep_link_mapper.dart';
import 'core/theme/app_theme.dart';
import 'data/app_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: DuttrixApp()));
  FlutterNativeSplash.remove();
}

/// Root widget for Duttrix (gestión de eventos y tickets).
///
/// Organizer auth uses Firebase Google Sign-In; all event, ticket and
/// collaborator data lives in Firestore.
class DuttrixApp extends ConsumerStatefulWidget {
  const DuttrixApp({super.key});

  @override
  ConsumerState<DuttrixApp> createState() => _DuttrixAppState();
}

class _DuttrixAppState extends ConsumerState<DuttrixApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindDeepLinks());
  }

  Future<void> _bindDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (e) {
      debugPrint('Initial deep link failed: $e');
    }
    _linkSub = appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) => debugPrint('Deep link stream error: $e'),
    );
  }

  void _handleUri(Uri uri) {
    final location = DeepLinkMapper.locationFromUri(uri);
    if (location == null) return;
    ref.read(routerProvider).go(location);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).revalidateCollaboratorSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Duttrix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
