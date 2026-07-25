import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/collaborator.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../models/ticket_design.dart';

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

  Stream<List<Ticket>> watchTickets(String eventId) {
    return _tickets(eventId).orderBy('number').snapshots().map(
          (snap) => snap.docs
              .map(
                (doc) => Ticket.fromFirestore(
                  id: doc.id,
                  eventId: eventId,
                  data: doc.data(),
                ),
              )
              .toList(),
        );
  }

  Stream<Event?> watchById(String eventId) {
    return _events.doc(eventId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return Event.fromFirestore(snap.id, data);
    });
  }

  /// Assigns tickets [from]..[to] to [sellerId]: marks them `withSeller` and
  /// records the range on the collaborator doc. Tickets must be `unassigned`.
  Future<TicketRange> assignTicketRange({
    required String eventId,
    required String sellerId,
    required int from,
    required int to,
  }) async {
    if (to < from) {
      throw ArgumentError('El rango es inválido (hasta < desde).');
    }

    final snap = await _tickets(eventId)
        .where('number', isGreaterThanOrEqualTo: from)
        .where('number', isLessThanOrEqualTo: to)
        .get();

    final expected = to - from + 1;
    if (snap.docs.length != expected) {
      throw StateError(
        'Algunos tickets del rango no existen. Revisá la cantidad del evento.',
      );
    }

    for (final doc in snap.docs) {
      final status = doc.data()['status'];
      if (status != TicketStatus.unassigned.firestoreValue) {
        throw StateError(
          'El ticket #${doc.data()['number']} ya está asignado.',
        );
      }
    }

    final range = TicketRange(
      id: 'rng_${DateTime.now().millisecondsSinceEpoch}',
      from: from,
      to: to,
      date: DateTime.now(),
    );

    // Chunk ticket updates to stay under Firestore's batch limit.
    const chunk = 400;
    for (var i = 0; i < snap.docs.length; i += chunk) {
      final batch = _firestore.batch();
      final slice = snap.docs.skip(i).take(chunk);
      for (final doc in slice) {
        batch.update(doc.reference, {
          'status': TicketStatus.withSeller.firestoreValue,
          'sellerId': sellerId,
        });
      }
      await batch.commit();
    }

    await _events.doc(eventId).collection('collaborators').doc(sellerId).update({
      'ranges': FieldValue.arrayUnion([range.toFirestoreMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return range;
  }

  Future<void> updateTicketBuyer({
    required String eventId,
    required String ticketId,
    required String buyerName,
  }) async {
    await _tickets(eventId).doc(ticketId).update({
      'buyerName': buyerName.trim(),
    });
  }

  Future<void> updateTicketsBuyer({
    required String eventId,
    required Iterable<String> ticketIds,
    required String buyerName,
  }) async {
    final name = buyerName.trim();
    const chunk = 400;
    final ids = ticketIds.toList(growable: false);
    for (var i = 0; i < ids.length; i += chunk) {
      final batch = _firestore.batch();
      for (final id in ids.skip(i).take(chunk)) {
        batch.update(_tickets(eventId).doc(id), {'buyerName': name});
      }
      await batch.commit();
    }
  }

  /// Seller marks tickets as collected (`withSeller` → `collected`).
  Future<void> markTicketsCollected({
    required String eventId,
    required Iterable<String> ticketIds,
  }) async {
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {TicketStatus.withSeller},
      newStatus: TicketStatus.collected,
    );
  }

  /// Organizer returns unsold tickets to the free pool (`withSeller` →
  /// `unassigned`, clears seller + buyer). Reassignment uses the same rules.
  Future<void> returnTicketsToPool({
    required String eventId,
    required Iterable<String> ticketIds,
  }) async {
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {TicketStatus.withSeller},
      newStatus: TicketStatus.unassigned,
      extraFields: {
        'sellerId': null,
        'buyerName': '',
      },
    );
  }

  /// Validator marks a ticket as delivered (`collected`/`settled` → `delivered`).
  Future<void> markTicketDelivered({
    required String eventId,
    required String ticketId,
    required String validatorId,
  }) async {
    final ref = _tickets(eventId).doc(ticketId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Ticket no encontrado.');
    }
    final status = TicketStatusX.fromFirestore(data['status'] as String?);
    if (status == TicketStatus.delivered) {
      throw StateError('Este ticket ya fue validado.');
    }
    if (status != TicketStatus.collected && status != TicketStatus.settled) {
      throw StateError(
        'El ticket no figura como cobrado. Revisá con el organizador.',
      );
    }
    await ref.update({
      'status': TicketStatus.delivered.firestoreValue,
      'validatorId': validatorId,
    });
  }

  /// Collector settles tickets (`collected` → `settled`).
  Future<void> markTicketsSettled({
    required String eventId,
    required Iterable<String> ticketIds,
    required String collectorId,
  }) async {
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {TicketStatus.collected},
      newStatus: TicketStatus.settled,
      extraFields: {'collectorId': collectorId},
    );
  }

  Future<void> _updateTicketStatuses({
    required String eventId,
    required Iterable<String> ticketIds,
    required Set<TicketStatus> expectedStatuses,
    required TicketStatus newStatus,
    Map<String, Object?> extraFields = const {},
  }) async {
    final ids = ticketIds.toList(growable: false);
    if (ids.isEmpty) return;

    const chunk = 400;
    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.skip(i).take(chunk).toList(growable: false);
      final snaps = await Future.wait(
        slice.map((id) => _tickets(eventId).doc(id).get()),
      );

      final batch = _firestore.batch();
      for (var j = 0; j < slice.length; j++) {
        final snap = snaps[j];
        final data = snap.data();
        if (!snap.exists || data == null) {
          throw StateError('Ticket ${slice[j]} no encontrado.');
        }
        final status = TicketStatusX.fromFirestore(data['status'] as String?);
        if (!expectedStatuses.contains(status)) {
          throw StateError(
            'Ticket #${data['number']} no está en el estado esperado.',
          );
        }
        batch.update(snap.reference, {
          'status': newStatus.firestoreValue,
          ...extraFields,
        });
      }
      await batch.commit();
    }
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

  Future<Event> updateTicketDesign(
    String eventId,
    TicketVisualStyle design,
  ) async {
    await _events.doc(eventId).update({
      'ticketDesign': design.toFirestoreMap(),
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
