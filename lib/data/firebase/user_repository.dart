import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user.dart';

/// Persists organizer profiles in Firestore: `users/{uid}`.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates the user doc on first login, or updates profile + lastLoginAt.
  Future<AppUser> upsertFromAuthUser(User user) async {
    final profile = AppUser.fromAuth(user);
    final ref = _users.doc(profile.uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();
    final isNew = !snap.exists;

    await ref.set(
      profile.toFirestoreMap(isNew: isNew, serverNow: now),
      SetOptions(merge: true),
    );

    // Re-read so createdAt/lastLoginAt come back as concrete timestamps when available.
    final saved = await ref.get();
    final data = saved.data();
    if (data == null) return profile;
    return AppUser.fromFirestore(profile.uid, data);
  }

  Future<AppUser?> getByUid(String uid) async {
    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return AppUser.fromFirestore(uid, data);
  }
}
