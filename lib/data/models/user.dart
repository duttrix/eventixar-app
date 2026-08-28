import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Organizer profile. Aligns with Firestore `users/{uid}`.
class AppUser {
  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastLoginAt,
    this.freeEvents = defaultFreeEvents,
  });

  /// How many events a new organizer can create without paying.
  static const int defaultFreeEvents = 2;

  /// Firebase Auth uid (doc id in Firestore). Mock users use a synthetic id.
  final String uid;
  final String email;
  String displayName;
  String? photoUrl;
  final DateTime? createdAt;
  DateTime? lastLoginAt;

  /// Remaining events this organizer can create for free.
  int freeEvents;

  bool get canCreateFreeEvent => freeEvents > 0;

  String get freeEventsLabel {
    if (freeEvents == 1) {
      return 'Te queda 1 evento gratis';
    }
    return 'Te quedan $freeEvents eventos gratis';
  }

  /// Convenience for UI that still says "name".
  String get name => displayName;

  set name(String value) => displayName = value;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool clearPhotoUrl = false,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int? freeEvents,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      freeEvents: freeEvents ?? this.freeEvents,
    );
  }

  factory AppUser.fromAuth(fb.User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Usuario'),
      photoUrl: user.photoURL,
    );
  }

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ??
          (data['name'] as String?) ??
          'Usuario',
      photoUrl: data['photoUrl'] as String?,
      createdAt: _readTimestamp(data['createdAt']),
      lastLoginAt: _readTimestamp(data['lastLoginAt']),
      freeEvents: _readInt(data['freeEvents'], 0),
    );
  }

  /// Fields written to Firestore (timestamps via [FieldValue] are applied by the repo).
  Map<String, dynamic> toFirestoreMap({
    required bool isNew,
    required FieldValue serverNow,
  }) {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'lastLoginAt': serverNow,
      if (isNew) 'createdAt': serverNow,
      if (isNew) 'freeEvents': defaultFreeEvents,
    };
  }

  static int _readInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
