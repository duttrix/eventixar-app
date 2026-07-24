import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/collaborator.dart';
import '../models/role.dart';
import 'mock_repository.dart';

final repositoryProvider = ChangeNotifierProvider<MockRepository>((ref) {
  return MockRepository();
});

/// Mock session: organizer login, or temporary deeplink collaborator access.
class SessionState {
  const SessionState({
    this.userEmail,
    this.currentEventId,
    this.collaboratorToken,
    this.roleOverride,
  });

  final String? userEmail;
  final String? currentEventId;

  /// When set, the user entered via a seller/validator deeplink.
  final String? collaboratorToken;

  /// Dev-only role preview for the organizer workspace.
  final Role? roleOverride;

  bool get isLoggedIn => userEmail != null || collaboratorToken != null;

  SessionState copyWith({
    String? userEmail,
    bool clearUserEmail = false,
    String? currentEventId,
    bool clearCurrentEventId = false,
    String? collaboratorToken,
    bool clearCollaboratorToken = false,
    Role? roleOverride,
    bool clearRoleOverride = false,
  }) {
    return SessionState(
      userEmail: clearUserEmail ? null : (userEmail ?? this.userEmail),
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
  SessionController() : super(const SessionState());

  void login(String email) {
    state = SessionState(userEmail: email);
  }

  void enterAsCollaborator(String token) {
    state = SessionState(collaboratorToken: token);
  }

  void logout() {
    state = const SessionState();
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
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController();
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
