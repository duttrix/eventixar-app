import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/google_auth_service.dart';
import '../firebase/collaborator_repository.dart';
import '../firebase/event_repository.dart';
import '../firebase/user_repository.dart';
import '../models/collaborator.dart';
import '../models/event.dart';
import '../models/role.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'mock_repository.dart';

final repositoryProvider = ChangeNotifierProvider<MockRepository>((ref) {
  return MockRepository();
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

final collaboratorRepositoryProvider = Provider<CollaboratorRepository>((ref) {
  return CollaboratorRepository();
});

/// Live events for the signed-in Firebase organizer.
final organizerEventsProvider = StreamProvider<List<Event>>((ref) {
  final session = ref.watch(sessionProvider);
  if (!session.usesFirestore || session.userUid == null) {
    return Stream.value(const <Event>[]);
  }
  return ref.watch(eventRepositoryProvider).watchForOwner(session.userUid!);
});

/// Ensures a Firestore event (+ tickets + collaborators) is mirrored into the
/// mock cache for workspace screens that still read from [MockRepository].
final ensureLocalEventProvider =
    FutureProvider.family<Event, String>((ref, eventId) async {
  final mock = ref.read(repositoryProvider);
  final session = ref.read(sessionProvider);

  // Demo / local-only events stay in the mock repo.
  final local = mock.tryEventById(eventId);
  if (local != null && !session.usesFirestore) {
    return local;
  }

  // Prefer remote when signed in with Firebase.
  if (session.usesFirestore) {
    final remote = await ref.read(eventRepositoryProvider).getById(eventId);
    if (remote != null) {
      mock.upsertEvent(remote);
      if (remote.ticketsGenerated) {
        final tickets =
            await ref.read(eventRepositoryProvider).listTickets(eventId);
        mock.replaceTicketsForEvent(eventId, tickets);
      } else {
        mock.ticketAggregate[eventId] = {
          for (final s in TicketStatus.values) s: 0,
        }..[TicketStatus.unassigned] = remote.ticketCount;
      }
      final collabs =
          await ref.read(collaboratorRepositoryProvider).listForEvent(eventId);
      mock.replaceCollaboratorsForEvent(eventId, collabs);
      return remote;
    }
  }

  if (local != null) return local;
  throw StateError('Evento $eventId no encontrado.');
});

/// Creates a collaborator in Firestore (Google session) or local mock (demo).
Future<Collaborator> inviteCollaborator(
  WidgetRef ref, {
  required String eventId,
  required CollaboratorRole role,
  required String name,
  required String phone,
  String notes = '',
}) async {
  final session = ref.read(sessionProvider);
  if (session.usesFirestore) {
    final created = await ref.read(collaboratorRepositoryProvider).create(
          eventId: eventId,
          role: role,
          name: name,
          phone: phone,
          notes: notes,
        );
    ref.read(repositoryProvider).upsertCollaborator(created);
    return created;
  }
  return ref.read(repositoryProvider).addCollaborator(
        eventId: eventId,
        role: role,
        name: name,
        phone: phone,
        notes: notes,
      );
}

/// Updates collaborator profile in Firestore or local mock.
Future<Collaborator> saveCollaborator(
  WidgetRef ref, {
  required String eventId,
  required String collaboratorId,
  required String name,
  required String phone,
  String notes = '',
}) async {
  final session = ref.read(sessionProvider);
  if (session.usesFirestore) {
    final updated = await ref.read(collaboratorRepositoryProvider).update(
          eventId: eventId,
          collaboratorId: collaboratorId,
          name: name,
          phone: phone,
          notes: notes,
        );
    ref.read(repositoryProvider).upsertCollaborator(updated);
    return updated;
  }
  ref.read(repositoryProvider).updateCollaborator(
        collaboratorId,
        name: name,
        phone: phone,
        notes: notes,
      );
  return ref.read(repositoryProvider).collaboratorById(collaboratorId);
}

/// Resolves a join token from local cache, then Firestore if needed.
Future<Collaborator?> resolveCollaboratorToken(
  WidgetRef ref,
  String token,
) async {
  final mock = ref.read(repositoryProvider);
  final local = mock.collaboratorByToken(token);
  if (local != null) return local;

  final remote =
      await ref.read(collaboratorRepositoryProvider).findByToken(token);
  if (remote == null) return null;

  mock.upsertCollaborator(remote);
  final event = await ref.read(eventRepositoryProvider).getById(remote.eventId);
  if (event != null) {
    mock.upsertEvent(event);
    if (event.ticketsGenerated) {
      final tickets =
          await ref.read(eventRepositoryProvider).listTickets(remote.eventId);
      mock.replaceTicketsForEvent(remote.eventId, tickets);
    }
  }
  return remote;
}

/// Organizer Firebase session, or temporary deeplink collaborator access.
class SessionState {
  const SessionState({
    this.userEmail,
    this.userUid,
    this.currentEventId,
    this.collaboratorToken,
    this.roleOverride,
  });

  final String? userEmail;
  final String? userUid;
  final String? currentEventId;

  /// When set, the user entered via a seller/validator/collector deeplink.
  final String? collaboratorToken;

  /// Dev-only role preview for the organizer workspace.
  final Role? roleOverride;

  bool get isLoggedIn => userEmail != null || collaboratorToken != null;
  bool get isOrganizer => userEmail != null && collaboratorToken == null;

  /// Real Google/Firebase organizer (not the local mock demo login).
  bool get usesFirestore =>
      userUid != null && userUid != 'demo-organizer' && collaboratorToken == null;

  SessionState copyWith({
    String? userEmail,
    bool clearUserEmail = false,
    String? userUid,
    bool clearUserUid = false,
    String? currentEventId,
    bool clearCurrentEventId = false,
    String? collaboratorToken,
    bool clearCollaboratorToken = false,
    Role? roleOverride,
    bool clearRoleOverride = false,
  }) {
    return SessionState(
      userEmail: clearUserEmail ? null : (userEmail ?? this.userEmail),
      userUid: clearUserUid ? null : (userUid ?? this.userUid),
      currentEventId:
          clearCurrentEventId ? null : (currentEventId ?? this.currentEventId),
      collaboratorToken: clearCollaboratorToken
          ? null
          : (collaboratorToken ?? this.collaboratorToken),
      roleOverride: clearRoleOverride ? null : (roleOverride ?? this.roleOverride),
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState()) {
    _bindAuth();
  }

  final Ref _ref;
  StreamSubscription<User?>? _authSub;

  void _bindAuth() {
    final auth = _ref.read(googleAuthServiceProvider);
    final current = auth.currentUser;
    if (current != null) {
      unawaited(_applyFirebaseUser(current));
    }
    _authSub = auth.authStateChanges().listen((user) {
      unawaited(_onAuthChanged(user));
    });
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null) {
      await _applyFirebaseUser(user);
      return;
    }
    // Don't wipe collaborator deeplink sessions when Firebase has no user.
    if (state.collaboratorToken != null) return;
    if (state.userEmail != null || state.userUid != null) {
      state = const SessionState();
    }
  }

  Future<void> _applyFirebaseUser(User user) async {
    final profile = AppUser.fromAuth(user);
    _ref.read(repositoryProvider).ensureUser(
          profile.email,
          uid: profile.uid,
          displayName: profile.displayName,
          photoUrl: profile.photoUrl,
        );
    state = SessionState(
      userEmail: profile.email,
      userUid: profile.uid,
      currentEventId: state.currentEventId,
    );

    try {
      final saved = await _ref.read(userRepositoryProvider).upsertFromAuthUser(user);
      _ref.read(repositoryProvider).ensureUser(
            saved.email,
            uid: saved.uid,
            displayName: saved.displayName,
            photoUrl: saved.photoUrl,
          );
    } catch (e, st) {
      debugPrint('Firestore user upsert failed: $e\n$st');
    }
  }

  /// Demo / mock organizer login (no Firebase). Prefer [signInWithGoogle].
  void login(String email) {
    _ref.read(repositoryProvider).ensureUser(
          email,
          uid: 'demo-organizer',
          displayName: 'María Organizadora',
        );
    state = SessionState(userEmail: email, userUid: 'demo-organizer');
  }

  Future<User?> signInWithGoogle() {
    return _ref.read(googleAuthServiceProvider).signInWithGoogle();
  }

  void enterAsCollaborator(String token) {
    state = SessionState(collaboratorToken: token);
  }

  Future<void> logout() async {
    final hadFirebaseUser = state.userUid != null ||
        _ref.read(googleAuthServiceProvider).currentUser != null;
    state = const SessionState();
    if (hadFirebaseUser) {
      await _ref.read(googleAuthServiceProvider).signOut();
    }
  }

  void setCurrentEvent(String? eventId) {
    state = state.copyWith(
      currentEventId: eventId,
      clearCurrentEventId: eventId == null,
    );
  }

  void setRoleOverride(Role role) {
    state = state.copyWith(roleOverride: role);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref);
});

final effectiveRoleProvider = Provider<Role>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.roleOverride != null) return session.roleOverride!;

  final token = session.collaboratorToken;
  if (token != null) {
    final collab = ref.watch(repositoryProvider).collaboratorByToken(token);
    if (collab != null) {
      return switch (collab.role) {
        CollaboratorRole.seller => Role.seller,
        CollaboratorRole.validator => Role.validator,
        CollaboratorRole.collector => Role.collector,
      };
    }
  }
  return Role.organizer;
});
