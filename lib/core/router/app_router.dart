import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/event_workspace/collector_detail_screen.dart';
import '../../features/event_workspace/event_workspace_screen.dart';
import '../../features/event_workspace/seller_detail_screen.dart';
import '../../features/event_workspace/ticket_design_screen.dart';
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
          location.startsWith('/validator/') ||
          location.startsWith('/collector/') ||
          location.startsWith('/ticket/');

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
        path: '/ticket/:ticketId',
        builder: (context, state) =>
            PublicTicketScreen(ticketId: state.pathParameters['ticketId']!),
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
