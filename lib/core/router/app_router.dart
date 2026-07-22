import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/event_workspace/event_workspace_screen.dart';
import '../../features/event_workspace/rendicion_detalle_screen.dart';
import '../../features/event_workspace/vendedor_detalle_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/join/join_screens.dart';
import '../../features/onboarding/create_event_screen.dart';
import '../../features/onboarding/pay_event_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isLogin = location == '/login';
      final isJoin = location.startsWith('/join/') ||
          location.startsWith('/seller/') ||
          location.startsWith('/deliverer/');

      if (!session.isLoggedIn && !isLogin && !isJoin) {
        return '/login';
      }
      if (session.isLoggedIn && isLogin && session.userEmail != null) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/create-event',
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/create-event/pay/:eventId',
        builder: (context, state) =>
            PayEventScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/join/:token',
        builder: (context, state) => JoinScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/seller/:token',
        builder: (context, state) =>
            SellerPortalScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/deliverer/:token',
        builder: (context, state) =>
            DelivererPortalScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/event/:eventId',
        builder: (context, state) =>
            EventWorkspaceScreen(eventId: state.pathParameters['eventId']!),
        routes: [
          GoRoute(
            path: 'vendedores/:vendedorId',
            builder: (context, state) => VendedorDetalleScreen(
              eventId: state.pathParameters['eventId']!,
              sellerId: state.pathParameters['vendedorId']!,
            ),
          ),
          GoRoute(
            path: 'rendiciones/:vendedorId',
            builder: (context, state) => RendicionDetalleScreen(
              eventId: state.pathParameters['eventId']!,
              sellerId: state.pathParameters['vendedorId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
