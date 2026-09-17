import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  /// Deletes every Firestore doc owned by this organizer (events, tickets,
  /// collaborators, invite tokens, access, user profile).
  Future<void> deleteOwnedData(String uid) async {
    final events = await _firestore
        .collection('events')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (final eventDoc in events.docs) {
      try {
        await _deleteEventTree(eventDoc.id);
      } catch (e) {
        debugPrint('deleteEventTree ${eventDoc.id} failed: $e');
      }
    }
    try {
      await _users.doc(uid).delete();
    } catch (e) {
      debugPrint('delete user $uid failed: $e');
    }
  }

  Future<void> _deleteEventTree(String eventId) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    final tickets = eventRef.collection('tickets');
    final collaborators = eventRef.collection('collaborators');
    final access = eventRef.collection('access');
    final tokens = _firestore.collection('tokens');

    final tokenIds = <String>{};
    final accessSnap = await access.get();
    for (final doc in accessSnap.docs) {
      final token = doc.data()['token'];
      if (token is String && token.isNotEmpty) tokenIds.add(token);
    }
    final collabSnap = await collaborators.get();
    for (final doc in collabSnap.docs) {
      final token = doc.data()['token'];
      if (token is String && token.isNotEmpty) tokenIds.add(token);
    }

    await _deleteRefs(tokenIds.map(tokens.doc));
    await _deleteQuery(tickets);
    await _deleteQuery(access);
    await _deleteQuery(collaborators);
    await eventRef.delete().timeout(const Duration(seconds: 15));
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      try {
        await batch.commit().timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('delete batch failed: $e');
        return;
      }
      if (snap.docs.length < 400) return;
    }
  }

  Future<void> _deleteRefs(Iterable<DocumentReference<Map<String, dynamic>>> refs) async {
    final list = refs.toList(growable: false);
    const chunk = 400;
    for (var i = 0; i < list.length; i += chunk) {
      final batch = _firestore.batch();
      final end = (i + chunk < list.length) ? i + chunk : list.length;
      for (var j = i; j < end; j++) {
        batch.delete(list[j]);
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    }
  }
}
