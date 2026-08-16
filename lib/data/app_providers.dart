import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/google_auth_service.dart';
import '../core/session/collaborator_session_storage.dart';
import 'firebase/catalog_repository.dart';
import 'firebase/collaborator_repository.dart';
import 'firebase/event_repository.dart';
import 'firebase/user_repository.dart';
import 'models/collaborator.dart';
import 'models/event.dart';
import 'models/ticket.dart';
import 'models/user.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final collaboratorSessionStorageProvider = Provider<CollaboratorSessionStorage>(
  (ref) {
    return CollaboratorSessionStorage();
  },
);

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

final collaboratorRepositoryProvider = Provider<CollaboratorRepository>((ref) {
  return CollaboratorRepository();
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

/// “Qué se vende” options from Firestore `config/eventProducts`.
final eventProductsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchEventProducts();
});

/// Pricing tiers from Firestore `config/eventPricing`.
final eventPricingProvider = StreamProvider<EventPricingConfig?>((ref) {
  return ref.watch(catalogRepositoryProvider).watchEventPricing();
});

/// Live events owned by the signed-in organizer.
final organizerEventsProvider = StreamProvider<List<Event>>((ref) {
  final uid = ref.watch(sessionProvider).userUid;
  if (uid == null) return Stream.value(const <Event>[]);
  return ref.watch(eventRepositoryProvider).watchForOwner(uid);
});

final eventProvider = StreamProvider.family<Event, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).watchById(eventId).map((event) {
    if (event == null) throw StateError('Evento $eventId no encontrado.');
    return event;
  });
});

final eventTicketsProvider = StreamProvider.family<List<Ticket>, String>((
  ref,
  eventId,
) {
  return ref.watch(eventRepositoryProvider).watchTickets(eventId);
});

final eventCollaboratorsProvider =
    StreamProvider.family<List<Collaborator>, String>((ref, eventId) {
      return ref.watch(collaboratorRepositoryProvider).watchForEvent(eventId);
    });

AsyncValue<List<Collaborator>> _collaboratorsWithRole(
  Ref ref,
  String eventId,
  CollaboratorRole role,
) {
  return ref
      .watch(eventCollaboratorsProvider(eventId))
      .whenData((list) => list.where((c) => c.role == role).toList());
}

final eventSellersProvider =
    Provider.family<AsyncValue<List<Collaborator>>, String>((ref, eventId) {
      return _collaboratorsWithRole(ref, eventId, CollaboratorRole.seller);
    });

final eventValidatorsProvider =
    Provider.family<AsyncValue<List<Collaborator>>, String>((ref, eventId) {
      return _collaboratorsWithRole(ref, eventId, CollaboratorRole.validator);
    });

final eventCollectorsProvider =
    Provider.family<AsyncValue<List<Collaborator>>, String>((ref, eventId) {
      return _collaboratorsWithRole(ref, eventId, CollaboratorRole.collector);
    });

final eventCoordinatorsProvider =
    Provider.family<AsyncValue<List<Collaborator>>, String>((ref, eventId) {
      return _collaboratorsWithRole(ref, eventId, CollaboratorRole.coordinator);
    });

final eventTicketAggregateProvider =
    Provider.family<AsyncValue<Map<TicketStatus, int>>, String>((ref, eventId) {
      return ref.watch(eventTicketsProvider(eventId)).whenData((tickets) {
        final counts = {for (final s in TicketStatus.values) s: 0};
        for (final ticket in tickets) {
          counts[ticket.status] = (counts[ticket.status] ?? 0) + 1;
        }
        return counts;
      });
    });

/// Invite token for one collaborator (works for organizer and portals).
final collaboratorAccessTokenProvider =
    FutureProvider.family<String, ({String eventId, String collaboratorId})>((
      ref,
      args,
    ) async {
      return await ref
              .read(collaboratorRepositoryProvider)
              .getAccessToken(
                eventId: args.eventId,
                collaboratorId: args.collaboratorId,
              ) ??
          '';
    });

/// collaboratorId → invite token. Owner lists the access subcollection.
final eventAccessTokensProvider =
    StreamProvider.family<Map<String, String>, String>((ref, eventId) {
      return ref
          .watch(collaboratorRepositoryProvider)
          .watchAccessTokens(eventId);
    });

/// Event + collaborator ids behind an invite token.
final collaboratorLocationProvider =
    FutureProvider.family<CollaboratorLocation?, String>((ref, token) {
      return ref.watch(collaboratorRepositoryProvider).resolveToken(token);
    });

/// Live collaborator behind an invite token. Emits `null` when the token was
/// revoked or the collaborator no longer exists.
final collaboratorByTokenProvider =
    StreamProvider.family<Collaborator?, String>((ref, token) async* {
      final location = await ref.watch(
        collaboratorLocationProvider(token).future,
      );
      if (location == null) {
        yield null;
        return;
      }
      yield* ref
          .watch(collaboratorRepositoryProvider)
          .watchOne(
            eventId: location.eventId,
            collaboratorId: location.collaboratorId,
          );
    });

Future<Collaborator> inviteCollaborator(
  WidgetRef ref, {
  required String eventId,
  required CollaboratorRole role,
  required String name,
  required String phone,
  String notes = '',
  String? createdByCoordinatorId,
}) {
  return ref
      .read(collaboratorRepositoryProvider)
      .create(
        eventId: eventId,
        role: role,
        name: name,
        phone: phone,
        notes: notes,
        createdByCoordinatorId: createdByCoordinatorId,
      );
}

Future<Collaborator> saveCollaborator(
  WidgetRef ref, {
  required String eventId,
  required String collaboratorId,
  required String name,
  required String phone,
  String notes = '',
}) {
  return ref
      .read(collaboratorRepositoryProvider)
      .update(
        eventId: eventId,
        collaboratorId: collaboratorId,
        name: name,
        phone: phone,
        notes: notes,
      );
}

/// Assigns a seller to a coordinator, or clears the link when [coordinatorId] is null.
Future<Collaborator> setSellerCoordinatorAction(
  WidgetRef ref, {
  required String eventId,
  required String sellerId,
  required String? coordinatorId,
}) {
  return ref.read(collaboratorRepositoryProvider).setSellerCoordinator(
        eventId: eventId,
        sellerId: sellerId,
        coordinatorId: coordinatorId,
      );
}

/// Invalidates the current invite link and issues a new one.
Future<Collaborator> regenerateCollaboratorToken(
  WidgetRef ref, {
  required String eventId,
  required String collaboratorId,
}) {
  return ref
      .read(collaboratorRepositoryProvider)
      .regenerateToken(eventId: eventId, collaboratorId: collaboratorId);
}

/// Deletes a collaborator. Seller tickets still unsold go back to the pool;
/// sold ones keep their status and drop the seller link.
Future<void> deleteCollaboratorAction(
  WidgetRef ref, {
  required String eventId,
  required Collaborator collaborator,
}) async {
  if (collaborator.role == CollaboratorRole.seller) {
    await ref
        .read(eventRepositoryProvider)
        .releaseTicketsFromSeller(eventId: eventId, sellerId: collaborator.id);
  }

  await ref
      .read(collaboratorRepositoryProvider)
      .delete(eventId: eventId, collaboratorId: collaborator.id);
}

Future<void> assignTicketRangeAction(
  WidgetRef ref, {
  required String eventId,
  required String sellerId,
  required int from,
  required int to,
  String? assignedByCollaboratorId,
}) async {
  await ref
      .read(eventRepositoryProvider)
      .assignTicketRange(
        eventId: eventId,
        sellerId: sellerId,
        from: from,
        to: to,
        assignedByCollaboratorId: assignedByCollaboratorId,
      );
}

Future<void> claimTicketsForSellerAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  required String sellerId,
  String actorRole = 'organizer',
  String? actorId,
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .claimTicketsForSeller(
        eventId: eventId,
        ticketIds: ids,
        sellerId: sellerId,
        actorRole: actorRole,
        actorId: actorId,
      );
}

Future<void> setTicketsBuyerAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  required String buyerName,
  String? actorId,
  String? actorRole,
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .updateTicketsBuyer(
        eventId: eventId,
        ticketIds: ids,
        buyerName: buyerName,
        actorId: actorId,
        actorRole: actorRole,
      );
}

Future<void> reserveTicketsAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  required String buyerName,
  required String sellerId,
  String? actorId,
  String actorRole = 'seller',
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .reserveTickets(
        eventId: eventId,
        ticketIds: ids,
        buyerName: buyerName,
        sellerId: sellerId,
        actorId: actorId,
        actorRole: actorRole,
      );
}

Future<void> clearTicketReservationsAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  String? actorId,
  String actorRole = 'seller',
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .clearTicketReservations(
        eventId: eventId,
        ticketIds: ids,
        actorId: actorId,
        actorRole: actorRole,
      );
}

Future<void> collectTicketsAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  String? actorId,
  String actorRole = 'seller',
  String? buyerName,
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .markTicketsCollected(
        eventId: eventId,
        ticketIds: ids,
        actorId: actorId,
        actorRole: actorRole,
        buyerName: buyerName,
      );
}

/// Organizer/coordinator frees unsold tickets so they can be reassigned.
Future<void> returnTicketsToPoolAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  String? actorId,
  String actorRole = 'organizer',
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .returnTicketsToPool(
        eventId: eventId,
        ticketIds: ids,
        actorId: actorId,
        actorRole: actorRole,
      );
}

/// Collector returns tickets (`withSeller`/`collected` → `returned` pool).
Future<void> markTicketsReturnedAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  String? actorId,
  String actorRole = 'collector',
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .markTicketsReturned(
        eventId: eventId,
        ticketIds: ids,
        actorId: actorId,
        actorRole: actorRole,
      );
}

Future<void> deliverTicketAction(
  WidgetRef ref, {
  required String eventId,
  required String ticketId,
  required String validatorId,
  String actorRole = 'validator',
}) async {
  await ref
      .read(eventRepositoryProvider)
      .markTicketDelivered(
        eventId: eventId,
        ticketId: ticketId,
        validatorId: validatorId,
        actorRole: actorRole,
      );
}

Future<void> settleTicketsAction(
  WidgetRef ref, {
  required String eventId,
  required Iterable<String> ticketIds,
  required String collectorId,
  required TicketSettleMode settleMode,
  String actorRole = 'collector',
}) async {
  final ids = ticketIds.toList(growable: false);
  if (ids.isEmpty) return;
  await ref
      .read(eventRepositoryProvider)
      .markTicketsSettled(
        eventId: eventId,
        ticketIds: ids,
        collectorId: collectorId,
        settleMode: settleMode,
        actorRole: actorRole,
      );
}

/// Organizer Firebase session, or deeplink collaborator access.
class SessionState {
  const SessionState({
    this.userEmail,
    this.userUid,
    this.displayName,
    this.photoUrl,
    this.currentEventId,
    this.collaboratorToken,
    this.collaboratorRole,
    this.isRestoring = false,
  });

  final String? userEmail;
  final String? userUid;
  final String? displayName;
  final String? photoUrl;
  final String? currentEventId;

  /// When set, the user entered via a seller/validator/collector deeplink.
  final String? collaboratorToken;

  /// Known once the token has been resolved against Firestore.
  final CollaboratorRole? collaboratorRole;

  /// True while a persisted collaborator token is being validated.
  final bool isRestoring;

  bool get isLoggedIn => userUid != null || collaboratorToken != null;
  bool get isOrganizer => userUid != null && collaboratorToken == null;

  SessionState copyWith({
    String? currentEventId,
    bool clearCurrentEventId = false,
    CollaboratorRole? collaboratorRole,
  }) {
    return SessionState(
      userEmail: userEmail,
      userUid: userUid,
      displayName: displayName,
      photoUrl: photoUrl,
      currentEventId: clearCurrentEventId
          ? null
          : (currentEventId ?? this.currentEventId),
      collaboratorToken: collaboratorToken,
      collaboratorRole: collaboratorRole ?? this.collaboratorRole,
      isRestoring: isRestoring,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState(isRestoring: true)) {
    unawaited(_initialize());
  }

  final Ref _ref;
  StreamSubscription<User?>? _authSub;

  Future<void> _initialize() async {
    final storage = _ref.read(collaboratorSessionStorageProvider);
    final installed = await storage.read();

    if (installed != null) {
      try {
        final collaborator = await _ref
            .read(collaboratorRepositoryProvider)
            .findByToken(installed.token);
        if (collaborator != null) {
          final event = await _ref
              .read(eventRepositoryProvider)
              .getById(collaborator.eventId);
          if (event != null && event.status != EventStatus.finished) {
            await storage.save(installed.token, collaborator.role);
            await _activateCollaborator(installed.token, collaborator.role);
            return;
          }
        }
      } catch (e, st) {
        // A network failure is not an invalid credential: keep the installed
        // token so a later app resume can validate it again.
        debugPrint('Collaborator session restore failed: $e\n$st');
        await _activateCollaborator(installed.token, installed.role);
        return;
      }
      await storage.clear();
    }

    state = const SessionState();
    _bindAuth();
  }

  Future<void> _activateCollaborator(
    String token,
    CollaboratorRole? role,
  ) async {
    state = SessionState(collaboratorToken: token, collaboratorRole: role);
    await _ref.read(googleAuthServiceProvider).signOut();
    _bindAuth();
  }

  /// Revalidates the installed token when the app returns to foreground.
  /// Definitively invalid/revoked tokens and finished events clear the device.
  Future<void> revalidateCollaboratorSession() async {
    final token = state.collaboratorToken;
    if (token == null) return;

    try {
      final collaborator = await _ref
          .read(collaboratorRepositoryProvider)
          .findByToken(token);
      if (collaborator == null) {
        await _clearCollaboratorSession();
        return;
      }

      final event = await _ref
          .read(eventRepositoryProvider)
          .getById(collaborator.eventId);
      if (event == null || event.status == EventStatus.finished) {
        await _clearCollaboratorSession();
        return;
      }

      if (state.collaboratorRole != collaborator.role) {
        await _ref
            .read(collaboratorSessionStorageProvider)
            .save(token, collaborator.role);
        state = state.copyWith(collaboratorRole: collaborator.role);
      }
    } catch (e, st) {
      // Connectivity errors must not destroy the installed credential.
      debugPrint('Collaborator session revalidation failed: $e\n$st');
    }
  }

  Future<void> _clearCollaboratorSession() async {
    await _ref.read(collaboratorSessionStorageProvider).clear();
    state = const SessionState();
  }

  void _bindAuth() {
    _authSub?.cancel();
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
    if (state.userUid != null) {
      state = const SessionState();
    }
  }

  Future<void> _applyFirebaseUser(User user) async {
    // A collaborator session owns this device until explicit logout —
    // unless we just cleared it during organizer Google sign-in.
    if (state.collaboratorToken != null) return;
    final profile = AppUser.fromAuth(user);
    state = SessionState(
      userEmail: profile.email,
      userUid: profile.uid,
      displayName: profile.displayName,
      photoUrl: profile.photoUrl,
      currentEventId: state.currentEventId,
    );

    try {
      await _ref.read(userRepositoryProvider).upsertFromAuthUser(user);
    } catch (e, st) {
      debugPrint('Firestore user upsert failed: $e\n$st');
    }
  }

  Future<User?> signInWithGoogle() async {
    final user = await _ref.read(googleAuthServiceProvider).signInWithGoogle();
    if (user == null) return null;

    // Organizer login owns the device: drop any installed collaborator access
    // so Google auth is not ignored by _applyFirebaseUser.
    if (state.collaboratorToken != null) {
      await _ref.read(collaboratorSessionStorageProvider).clear();
      state = const SessionState();
    }

    // Apply immediately so GoRouter redirect sees userUid before /home.
    await _applyFirebaseUser(user);
    return user;
  }

  Future<void> enterAsCollaborator(
    String token, {
    CollaboratorRole? role,
  }) async {
    await _ref.read(collaboratorSessionStorageProvider).save(token, role);
    state = SessionState(collaboratorToken: token, collaboratorRole: role);
    await _ref.read(googleAuthServiceProvider).signOut();
  }

  Future<void> logout() async {
    final hadFirebaseUser =
        state.userUid != null ||
        _ref.read(googleAuthServiceProvider).currentUser != null;
    await _ref.read(collaboratorSessionStorageProvider).clear();
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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((
  ref,
) {
  return SessionController(ref);
});
