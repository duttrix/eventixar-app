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
    final data = snap.data();

    final map = profile.toFirestoreMap(isNew: isNew, serverNow: now);
    // Missing field only: never overwrite a stored quota (0, 3, …).
    if (!isNew && data != null && data['freeEvents'] == null) {
      map['freeEvents'] = AppUser.defaultFreeEvents;
    }

    await ref.set(map, SetOptions(merge: true));

    // Re-read so createdAt/lastLoginAt come back as concrete timestamps when available.
    final saved = await ref.get();
    final savedData = saved.data();
    if (savedData == null) return profile;
    return AppUser.fromFirestore(profile.uid, savedData);
  }

  Future<AppUser?> getByUid(String uid) async {
    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return AppUser.fromFirestore(uid, data);
  }

  Stream<AppUser?> watchByUid(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return AppUser.fromFirestore(uid, data);
    });
  }

  /// Coupon sellers live in `sellers/{uid}` and must not use the organizer app.
  Future<bool> isSellerAccount({required String uid, String? email}) async {
    final mail = email?.trim().toLowerCase() ?? '';
    if (mail.endsWith('@duttrix.app')) return true;
    final snap = await _firestore.collection('sellers').doc(uid).get();
    return snap.exists;
  }
}
