import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collaborator.dart';

/// Where an invite token points to.
class CollaboratorLocation {
  const CollaboratorLocation({
    required this.eventId,
    required this.collaboratorId,
  });

  final String eventId;
  final String collaboratorId;
}

/// Firestore access for event collaborators + invite tokens.
class CollaboratorRepository {
  CollaboratorRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection('tokens');

  CollectionReference<Map<String, dynamic>> _collaborators(String eventId) =>
      _events.doc(eventId).collection('collaborators');

  /// Invite tokens, readable only by the event owner.
  CollectionReference<Map<String, dynamic>> _access(String eventId) =>
      _events.doc(eventId).collection('access');

  /// collaboratorId → invite token, for the organizer's share links.
  Stream<Map<String, String>> watchAccessTokens(String eventId) {
    return _access(eventId).snapshots().map((snap) {
      return {
        for (final doc in snap.docs)
          if (doc.data()['token'] is String)
            doc.id: doc.data()['token'] as String,
      };
    });
  }

  Future<String?> getAccessToken({
    required String eventId,
    required String collaboratorId,
  }) async {
    final snap = await _access(eventId).doc(collaboratorId).get();
    final token = snap.data()?['token'];
    return token is String ? token : null;
  }

  Future<List<Collaborator>> listForEvent(String eventId) async {
    final snap = await _collaborators(eventId).get();
    final list = snap.docs
        .map(
          (doc) => Collaborator.fromFirestore(
            id: doc.id,
            eventId: eventId,
            data: doc.data(),
          ),
        )
        .toList();
    list.sort((a, b) {
      final aAt = a.createdAt;
      final bAt = b.createdAt;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return aAt.compareTo(bAt);
    });
    return list;
  }

  Stream<List<Collaborator>> watchForEvent(String eventId) {
    return _collaborators(eventId).snapshots().map((snap) {
      final list = snap.docs
          .map(
            (doc) => Collaborator.fromFirestore(
              id: doc.id,
              eventId: eventId,
              data: doc.data(),
            ),
          )
          .toList();
      list.sort((a, b) {
        final aAt = a.createdAt;
        final bAt = b.createdAt;
        if (aAt == null && bAt == null) return 0;
        if (aAt == null) return 1;
        if (bAt == null) return -1;
        return aAt.compareTo(bAt);
      });
      return list;
    });
  }

  Future<Collaborator> create({
    required String eventId,
    required CollaboratorRole role,
    required String name,
    required String phone,
    String notes = '',
    String? createdByCoordinatorId,
  }) async {
    final token = _generateToken();
    final ref = _collaborators(eventId).doc();
    final now = FieldValue.serverTimestamp();
    final collaborator = Collaborator(
      id: ref.id,
      eventId: eventId,
      role: role,
      name: name.trim(),
      phone: phone.trim(),
      notes: notes.trim(),
      token: token,
      createdByCoordinatorId: createdByCoordinatorId,
    );

    // Write the collaborator first so portal rules that check
    // `exists(collaborators/{id})` (tokens / access) can succeed without Auth.
    await ref.set(
      collaborator.toFirestoreMap(createdAtValue: now, updatedAtValue: now),
    );

    final batch = _firestore.batch();
    batch.set(_tokens.doc(token), {
      'eventId': eventId,
      'collaboratorId': ref.id,
      'role': role.firestoreValue,
      'createdAt': now,
    });
    batch.set(_access(eventId).doc(ref.id), {'token': token, 'createdAt': now});
    await batch.commit();
    return collaborator;
  }

  Future<Collaborator> update({
    required String eventId,
    required String collaboratorId,
    required String name,
    required String phone,
    String notes = '',
  }) async {
    final ref = _collaborators(eventId).doc(collaboratorId);
    await ref.update({
      'name': name.trim(),
      'phone': phone.trim(),
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Colaborador $collaboratorId no encontrado.');
    }
    return Collaborator.fromFirestore(
      id: snap.id,
      eventId: eventId,
      data: data,
    );
  }

  /// Links a seller to a coordinator, or clears the link when [coordinatorId] is null.
  Future<Collaborator> setSellerCoordinator({
    required String eventId,
    required String sellerId,
    required String? coordinatorId,
  }) async {
    final ref = _collaborators(eventId).doc(sellerId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Vendedor $sellerId no encontrado.');
    }
    final seller = Collaborator.fromFirestore(
      id: snap.id,
      eventId: eventId,
      data: data,
    );
    if (seller.role != CollaboratorRole.seller) {
      throw StateError('Solo se puede asignar un vendedor a un coordinador.');
    }

    if (coordinatorId != null) {
      final coordSnap = await _collaborators(eventId).doc(coordinatorId).get();
      final coordData = coordSnap.data();
      if (!coordSnap.exists || coordData == null) {
        throw StateError('Coordinador no encontrado.');
      }
      final coordinator = Collaborator.fromFirestore(
        id: coordSnap.id,
        eventId: eventId,
        data: coordData,
      );
      if (coordinator.role != CollaboratorRole.coordinator) {
        throw StateError('El colaborador elegido no es un coordinador.');
      }
    }

    await ref.update({
      'createdByCoordinatorId': coordinatorId ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final refreshed = await ref.get();
    final refreshedData = refreshed.data();
    if (!refreshed.exists || refreshedData == null) {
      throw StateError('Vendedor $sellerId no encontrado.');
    }
    return Collaborator.fromFirestore(
      id: refreshed.id,
      eventId: eventId,
      data: refreshedData,
    );
  }

  /// Resolves a deeplink token to its event + collaborator ids.
  Future<CollaboratorLocation?> resolveToken(String token) async {
    final tokenSnap = await _tokens.doc(token).get();
    final tokenData = tokenSnap.data();
    if (!tokenSnap.exists || tokenData == null) return null;

    final eventId = tokenData['eventId'] as String?;
    final collaboratorId = tokenData['collaboratorId'] as String?;
    if (eventId == null || collaboratorId == null) return null;

    return CollaboratorLocation(
      eventId: eventId,
      collaboratorId: collaboratorId,
    );
  }

  Stream<Collaborator?> watchOne({
    required String eventId,
    required String collaboratorId,
  }) {
    return _collaborators(eventId).doc(collaboratorId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return Collaborator.fromFirestore(
        id: snap.id,
        eventId: eventId,
        data: data,
      );
    });
  }

  /// Resolves a deeplink token → collaborator (via `tokens/{token}` mirror).
  Future<Collaborator?> findByToken(String token) async {
    final location = await resolveToken(token);
    if (location == null) return null;

    final eventId = location.eventId;
    final snap = await _collaborators(
      eventId,
    ).doc(location.collaboratorId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;

    return Collaborator.fromFirestore(
      id: snap.id,
      eventId: eventId,
      data: data,
    );
  }

  /// Invalidates the old link and issues a new token.
  Future<Collaborator> regenerateToken({
    required String eventId,
    required String collaboratorId,
  }) async {
    final ref = _collaborators(eventId).doc(collaboratorId);
    final accessRef = _access(eventId).doc(collaboratorId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Colaborador $collaboratorId no encontrado.');
    }

    // Collaborators created before tokens moved to /access still carry the
    // legacy inline field; drop it so the old link really stops working.
    final oldToken =
        (await accessRef.get()).data()?['token'] as String? ??
        data['token'] as String?;
    final newToken = _generateToken();
    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.update(ref, {'updatedAt': now, 'token': FieldValue.delete()});
    if (oldToken != null && oldToken.isNotEmpty) {
      batch.delete(_tokens.doc(oldToken));
    }
    batch.set(_tokens.doc(newToken), {
      'eventId': eventId,
      'collaboratorId': collaboratorId,
      'role': data['role'],
      'createdAt': now,
    });
    batch.set(accessRef, {'token': newToken, 'createdAt': now});
    await batch.commit();

    return Collaborator.fromFirestore(id: snap.id, eventId: eventId, data: data)
      ..token = newToken;
  }

  /// Removes the collaborator, their invite token and access mirror.
  Future<void> delete({
    required String eventId,
    required String collaboratorId,
  }) async {
    final ref = _collaborators(eventId).doc(collaboratorId);
    final accessRef = _access(eventId).doc(collaboratorId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Colaborador $collaboratorId no encontrado.');
    }

    final accessToken = (await accessRef.get()).data()?['token'] as String?;
    final legacyToken = data['token'] as String?;

    final batch = _firestore.batch();
    batch.delete(ref);
    batch.delete(accessRef);
    if (accessToken != null && accessToken.isNotEmpty) {
      batch.delete(_tokens.doc(accessToken));
    }
    if (legacyToken != null &&
        legacyToken.isNotEmpty &&
        legacyToken != accessToken) {
      batch.delete(_tokens.doc(legacyToken));
    }
    await batch.commit();
  }

  String _generateToken() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
