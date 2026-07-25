import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collaborator.dart';

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

  Future<List<Collaborator>> listForEvent(String eventId) async {
    final snap = await _collaborators(eventId).orderBy('createdAt').get();
    return snap.docs
        .map(
          (doc) => Collaborator.fromFirestore(
            id: doc.id,
            eventId: eventId,
            data: doc.data(),
          ),
        )
        .toList();
  }

  Stream<List<Collaborator>> watchForEvent(String eventId) {
    return _collaborators(eventId).orderBy('createdAt').snapshots().map(
          (snap) => snap.docs
              .map(
                (doc) => Collaborator.fromFirestore(
                  id: doc.id,
                  eventId: eventId,
                  data: doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<Collaborator> create({
    required String eventId,
    required CollaboratorRole role,
    required String name,
    required String phone,
    String notes = '',
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
    );

    final batch = _firestore.batch();
    batch.set(
      ref,
      collaborator.toFirestoreMap(createdAtValue: now, updatedAtValue: now),
    );
    batch.set(_tokens.doc(token), {
      'eventId': eventId,
      'collaboratorId': ref.id,
      'role': role.firestoreValue,
      'createdAt': now,
    });
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

  /// Resolves a deeplink token → collaborator (via `tokens/{token}` mirror).
  Future<Collaborator?> findByToken(String token) async {
    final tokenSnap = await _tokens.doc(token).get();
    final tokenData = tokenSnap.data();
    if (!tokenSnap.exists || tokenData == null) return null;

    final eventId = tokenData['eventId'] as String?;
    final collaboratorId = tokenData['collaboratorId'] as String?;
    if (eventId == null || collaboratorId == null) return null;

    final snap = await _collaborators(eventId).doc(collaboratorId).get();
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
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Colaborador $collaboratorId no encontrado.');
    }

    final oldToken = data['token'] as String?;
    final newToken = _generateToken();
    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.update(ref, {
      'token': newToken,
      'updatedAt': now,
    });
    if (oldToken != null && oldToken.isNotEmpty) {
      batch.delete(_tokens.doc(oldToken));
    }
    batch.set(_tokens.doc(newToken), {
      'eventId': eventId,
      'collaboratorId': collaboratorId,
      'role': data['role'],
      'createdAt': now,
    });
    await batch.commit();

    final updated = await ref.get();
    return Collaborator.fromFirestore(
      id: updated.id,
      eventId: eventId,
      data: updated.data()!,
    );
  }

  String _generateToken() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
