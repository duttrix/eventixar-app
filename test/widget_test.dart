// Smoke test: the app boots to the login screen with no session installed.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eventixar/core/auth/google_auth_service.dart';
import 'package:eventixar/core/session/collaborator_session_storage.dart';
import 'package:eventixar/data/app_providers.dart';
import 'package:eventixar/data/models/collaborator.dart';
import 'package:eventixar/main.dart';

class _NoAuthService extends GoogleAuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}
}

class _EmptySessionStorage extends CollaboratorSessionStorage {
  @override
  Future<CollaboratorSession?> read() async => null;

  @override
  Future<void> save(String token, CollaboratorRole? role) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(_NoAuthService()),
          collaboratorSessionStorageProvider
              .overrideWithValue(_EmptySessionStorage()),
        ],
        child: const EventixarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eventixar'), findsWidgets);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple (próximamente)'), findsOneWidget);
  });
}
