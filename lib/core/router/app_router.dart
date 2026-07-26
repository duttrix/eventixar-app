import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/collaborator.dart';
import '../../data/app_providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/event_workspace/collector_detail_screen.dart';
import '../../features/event_workspace/event_workspace_screen.dart';
import '../../features/event_workspace/seller_detail_screen.dart';
import '../../features/event_workspace/ticket_design_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/join/join_screens.dart';
import '../../features/onboarding/create_event_screen.dart';
import '../../features/onboarding/pay_event_screen.dart';
import 'deep_link_mapper.dart';
import 'go_router_refresh_stream.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(
    ref.watch(googleAuthServiceProvider).authStateChanges(),
  );
  ref.onDispose(refresh.dispose);

  // Rebuild redirects when session (incl. collaborator) changes.
  ref.listen(sessionProvider, (_, _) => refresh.refresh());

  return GoRouter(
    // Platform intents arrive as `eventixar://…` / https hosts. Those strings
    // are not GoRouter paths — map them below (and via AppLinks in main.dart).
    overridePlatformDefaultLocation: true,
    initialLocation: '/login',
    refreshListenable: refresh,
    onException: (context, state, router) {
      final mapped = DeepLinkMapper.locationFromUri(state.uri);
      router.go(mapped ?? '/login');
    },
    redirect: (context, state) {
      // Cold/warm start from Android/iOS may feed the full deep link URI into
      // GoRouter. Convert it before route matching fails.
      final deepLinkLocation = DeepLinkMapper.locationFromUri(state.uri);
      if (deepLinkLocation != null &&
          state.uri.toString() != deepLinkLocation) {
        return deepLinkLocation;
      }

      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isLogin = location == '/login';
      final isJoin =
          location.startsWith('/join/') ||
          location.startsWith('/seller/') ||
          location.startsWith('/validator/') ||
          location.startsWith('/collector/');

      // Keep the initial screen stable until local collaborator restoration ends.
      if (session.isRestoring) return null;

      final collaboratorToken = session.collaboratorToken;
      if (collaboratorToken != null) {
        // Opening a new invite is the only way to replace the installed access.
        if (location.startsWith('/join/')) return null;

        // The role is unknown while the token is still being resolved; the
        // portal screens handle that transient state themselves.
        final portal = switch (session.collaboratorRole) {
          CollaboratorRole.seller => '/seller/$collaboratorToken',
          CollaboratorRole.validator => '/validator/$collaboratorToken',
          CollaboratorRole.collector => '/collector/$collaboratorToken',
          null => null,
        };
        if (portal == null) return null;
        return location == portal ? null : portal;
      }

      if (!session.isLoggedIn && !isLogin && !isJoin) {
        return '/login';
      }
      if (session.isLoggedIn && isLogin && session.userUid != null) {
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
        builder: (context, state) =>
            JoinScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/seller/:token',
        builder: (context, state) =>
            SellerPortalScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/validator/:token',
        builder: (context, state) =>
            ValidatorPortalScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/collector/:token',
        builder: (context, state) =>
            CollectorPortalScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/event/:eventId',
        builder: (context, state) =>
            EventWorkspaceScreen(eventId: state.pathParameters['eventId']!),
        routes: [
          GoRoute(
            path: 'ticket-design',
            builder: (context, state) =>
                TicketDesignScreen(eventId: state.pathParameters['eventId']!),
          ),
          GoRoute(
            path: 'sellers/:sellerId',
            builder: (context, state) => SellerDetailScreen(
              eventId: state.pathParameters['eventId']!,
              sellerId: state.pathParameters['sellerId']!,
            ),
          ),
          GoRoute(
            path: 'collectors/:collectorId',
            builder: (context, state) => CollectorDetailScreen(
              eventId: state.pathParameters['eventId']!,
              collectorId: state.pathParameters['collectorId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
