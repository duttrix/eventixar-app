import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/ticket.dart';

/// Firestore access for organizer events + ticket bootstrap.
class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  CollectionReference<Map<String, dynamic>> _tickets(String eventId) =>
      _events.doc(eventId).collection('tickets');

  Stream<List<Event>> watchForOwner(String ownerId) {
    return _events
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => Event.fromFirestore(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.eventDate.compareTo(a.eventDate));
      return list;
    });
  }

  Future<Event?> getById(String eventId) async {
    final snap = await _events.doc(eventId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return Event.fromFirestore(snap.id, data);
  }

  Future<Event> createEvent({
    required String ownerId,
    required String ownerEmail,
    required String name,
    required String product,
    required double ticketPrice,
    required int ticketCount,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required int sellersCount,
    required int validatorsCount,
    int collectorsCount = 0,
    String notes = '',
  }) async {
    final ref = _events.doc();
    final now = FieldValue.serverTimestamp();
    final event = Event(
      id: ref.id,
      ownerId: ownerId,
      ownerEmail: ownerEmail,
      name: name,
      product: product,
      ticketPrice: ticketPrice,
      ticketCount: ticketCount,
      eventDate: eventDate,
      pickupFrom: pickupFrom,
      pickupTo: pickupTo,
      pickupPlace: pickupPlace,
      sellersCount: sellersCount,
      validatorsCount: validatorsCount,
      collectorsCount: collectorsCount,
      notes: notes,
      status: EventStatus.awaitingPayment,
      paid: false,
      ticketsGenerated: false,
    );

    await ref.set(
      event.toFirestoreMap(createdAtValue: now, updatedAtValue: now),
    );
    return event;
  }

  /// Marks the event as paid/active and creates ticket docs 1..ticketCount.
  Future<Event> confirmPaymentAndGenerateTickets(String eventId) async {
    final ref = _events.doc(eventId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Evento $eventId no encontrado.');
    }

    var event = Event.fromFirestore(snap.id, data);
    if (event.paid && event.ticketsGenerated) {
      return event;
    }

    if (!event.ticketsGenerated) {
      await _generateTickets(eventId: event.id, ticketCount: event.ticketCount);
    }

    final now = FieldValue.serverTimestamp();
    await ref.update({
      'paid': true,
      'status': EventStatus.active.firestoreValue,
      'ticketsGenerated': true,
      'updatedAt': now,
    });

    event
      ..paid = true
      ..status = EventStatus.active
      ..ticketsGenerated = true;
    return event;
  }

  Future<void> _generateTickets({
    required String eventId,
    required int ticketCount,
  }) async {
    const chunk = 400;
    for (var start = 1; start <= ticketCount; start += chunk) {
      final end = (start + chunk - 1).clamp(1, ticketCount);
      final batch = _firestore.batch();
      for (var n = start; n <= end; n++) {
        final ticketRef = _tickets(eventId).doc('t_$n');
        batch.set(ticketRef, {
          'number': n,
          'status': TicketStatus.unassigned.firestoreValue,
          'sellerId': null,
          'validatorId': null,
          'collectorId': null,
          'buyerName': '',
        });
      }
      await batch.commit();
    }
  }

  Future<List<Ticket>> listTickets(String eventId) async {
    final snap = await _tickets(eventId).orderBy('number').get();
    return snap.docs
        .map(
          (doc) => Ticket.fromFirestore(
            id: doc.id,
            eventId: eventId,
            data: doc.data(),
          ),
        )
        .toList();
  }

  Future<Event> updateEvent(
    String eventId, {
    required String name,
    required String product,
    required double ticketPrice,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required String notes,
  }) async {
    final ref = _events.doc(eventId);
    await ref.update({
      'name': name,
      'product': product,
      'ticketPrice': ticketPrice,
      'eventDate': Timestamp.fromDate(
        DateTime(eventDate.year, eventDate.month, eventDate.day),
      ),
      'pickupFrom': {'hour': pickupFrom.hour, 'minute': pickupFrom.minute},
      'pickupTo': {'hour': pickupTo.hour, 'minute': pickupTo.minute},
      'pickupPlace': pickupPlace,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await getById(eventId);
    if (updated == null) throw StateError('Evento $eventId no encontrado.');
    return updated;
  }

  Future<Event> finishEvent(String eventId) async {
    await _events.doc(eventId).update({
      'status': EventStatus.finished.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await getById(eventId);
    if (updated == null) throw StateError('Evento $eventId no encontrado.');
    return updated;
  }
}
