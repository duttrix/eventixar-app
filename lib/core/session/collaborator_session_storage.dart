import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/collaborator.dart';

/// The collaborator credential installed on this device.
class CollaboratorSession {
  const CollaboratorSession({required this.token, required this.role});

  final String token;

  /// Cached so the app can reopen the right portal before Firestore answers.
  final CollaboratorRole? role;
}

/// Persists the single collaborator credential installed on this device.
class CollaboratorSessionStorage {
  static const _tokenKey = 'active_collaborator_token';
  static const _roleKey = 'active_collaborator_role';

  // Built on first use so subclasses can replace the storage without needing
  // the shared_preferences platform plugin.
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<CollaboratorSession?> read() async {
    final token = await _preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    final role = await _preferences.getString(_roleKey);
    return CollaboratorSession(
      token: token,
      role: role == null
          ? null
          : CollaboratorRole.values
              .where((r) => r.name == role)
              .firstOrNull,
    );
  }

  Future<void> save(String token, CollaboratorRole? role) async {
    await _preferences.setString(_tokenKey, token);
    if (role == null) {
      await _preferences.remove(_roleKey);
    } else {
      await _preferences.setString(_roleKey, role.name);
    }
  }

  Future<void> clear() async {
    await _preferences.remove(_tokenKey);
    await _preferences.remove(_roleKey);
  }
}
