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

  CollectionReference<Map<String, dynamic>> _collaborators(String eventId) =>
      _events.doc(eventId).collection('collaborators');

  Future<String?> _collaboratorName(String eventId, String? collaboratorId) async {
    if (collaboratorId == null || collaboratorId.isEmpty) return null;
    final snap = await _collaborators(eventId).doc(collaboratorId).get();
    final name = (snap.data()?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

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
    double ticketProfit = 0,
    required int ticketCount,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required int sellersCount,
    required int validatorsCount,
    int collectorsCount = 0,
    int coordinatorsCount = 0,
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
      ticketProfit: ticketProfit,
      ticketCount: ticketCount,
      eventDate: eventDate,
      pickupFrom: pickupFrom,
      pickupTo: pickupTo,
      pickupPlace: pickupPlace,
      sellersCount: sellersCount,
      validatorsCount: validatorsCount,
      collectorsCount: collectorsCount,
      coordinatorsCount: coordinatorsCount,
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
          'assignedByCollaboratorId': null,
          'buyerName': '',
          'history': [
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.created,
              toStatus: TicketStatus.unassigned,
              actorRole: 'organizer',
            ).toFirestoreMap(),
          ],
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
  /// records the range on the collaborator doc.
  ///
  /// Tickets must be in the free pool (`unassigned` or `returned`).
  Future<TicketRange> assignTicketRange({
    required String eventId,
    required String sellerId,
    required int from,
    required int to,
    String? assignedByCollaboratorId,
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
      final status = TicketStatusX.fromFirestore(doc.data()['status'] as String?);
      if (!status.isAssignablePool) {
        throw StateError(
          'El ticket #${doc.data()['number']} no está disponible en el pool.',
        );
      }
    }

    final range = TicketRange(
      id: 'rng_${DateTime.now().millisecondsSinceEpoch}',
      from: from,
      to: to,
      date: DateTime.now(),
      assignedByCollaboratorId: assignedByCollaboratorId,
    );

    final sellerSnap =
        await _collaborators(eventId).doc(sellerId).get();
    final sellerName =
        (sellerSnap.data()?['name'] as String?)?.trim() ?? '';
    final sellerLabel = sellerName.isNotEmpty
        ? sellerName
        : (sellerSnap.exists ? 'vendedor $sellerId' : 'Organizador');
    final actorName = assignedByCollaboratorId != null
        ? await _collaboratorName(eventId, assignedByCollaboratorId)
        : null;

    // Chunk ticket updates to stay under Firestore's batch limit.
    const chunk = 400;
    for (var i = 0; i < snap.docs.length; i += chunk) {
      final batch = _firestore.batch();
      final slice = snap.docs.skip(i).take(chunk);
      for (final doc in slice) {
        final from = TicketStatusX.fromFirestore(doc.data()['status'] as String?);
        final history = TicketHistoryEntry(
          at: DateTime.now(),
          action: TicketHistoryAction.assigned,
          fromStatus: from,
          toStatus: TicketStatus.withSeller,
          actorId: assignedByCollaboratorId,
          actorRole:
              assignedByCollaboratorId != null ? 'coordinator' : 'organizer',
          actorName: actorName,
          note: 'Asignado a $sellerLabel',
        );
        batch.update(doc.reference, {
          'status': TicketStatus.withSeller.firestoreValue,
          'sellerId': sellerId,
          'assignedByCollaboratorId': assignedByCollaboratorId,
          'history': FieldValue.arrayUnion([history.toFirestoreMap()]),
        });
      }
      await batch.commit();
    }

    // Organizer can hold tickets under their uid without a collaborator doc.
    if (sellerSnap.exists) {
      await _events.doc(eventId).collection('collaborators').doc(sellerId).update({
        'ranges': FieldValue.arrayUnion([range.toFirestoreMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return range;
  }

  /// Claims free-pool tickets for [sellerId] (`unassigned`/`returned` → `withSeller`).
  ///
  /// Used when the organizer sells from the pool without a collaborator doc.
  Future<void> claimTicketsForSeller({
    required String eventId,
    required Iterable<String> ticketIds,
    required String sellerId,
    String actorRole = 'organizer',
    String? actorId,
  }) async {
    final ids = ticketIds.toList(growable: false);
    if (ids.isEmpty) return;

    final sellerSnap =
        await _collaborators(eventId).doc(sellerId).get();
    final sellerName =
        (sellerSnap.data()?['name'] as String?)?.trim() ?? '';
    final sellerLabel = sellerName.isNotEmpty
        ? sellerName
        : (sellerSnap.exists ? 'vendedor $sellerId' : 'Organizador');
    final resolvedActorId = actorId ?? sellerId;
    final actorName = await _collaboratorName(eventId, resolvedActorId);

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
        if (!status.isAssignablePool) {
          throw StateError(
            'Ticket #${data['number']} ya no está en el pool.',
          );
        }
        batch.update(snap.reference, {
          'status': TicketStatus.withSeller.firestoreValue,
          'sellerId': sellerId,
          'assignedByCollaboratorId': null,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.assigned,
              fromStatus: status,
              toStatus: TicketStatus.withSeller,
              actorId: resolvedActorId,
              actorRole: actorRole,
              actorName: actorName,
              note: 'Asignado a $sellerLabel',
            ).toFirestoreMap(),
          ]),
        });
      }
      await batch.commit();
    }
  }

  Future<void> updateTicketBuyer({
    required String eventId,
    required String ticketId,
    required String buyerName,
    String? actorId,
    String? actorRole,
  }) async {
    final name = buyerName.trim();
    final snap = await _tickets(eventId).doc(ticketId).get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Ticket no encontrado.');
    }
    final status = TicketStatusX.fromFirestore(data['status'] as String?);
    final resolvedActorId = actorId ?? data['sellerId'] as String?;
    final actorName = await _collaboratorName(eventId, resolvedActorId);
    await snap.reference.update({
      'buyerName': name,
      'history': FieldValue.arrayUnion([
        TicketHistoryEntry(
          at: DateTime.now(),
          action: TicketHistoryAction.buyerSet,
          fromStatus: status,
          toStatus: status,
          actorId: resolvedActorId,
          actorRole: actorRole ?? 'seller',
          actorName: actorName,
          note: name.isEmpty ? 'Comprador borrado' : 'Para: $name',
        ).toFirestoreMap(),
      ]),
    });
  }

  Future<void> updateTicketsBuyer({
    required String eventId,
    required Iterable<String> ticketIds,
    required String buyerName,
    String? actorId,
    String? actorRole,
  }) async {
    final name = buyerName.trim();
    const chunk = 400;
    final ids = ticketIds.toList(growable: false);
    final knownNames = <String, String?>{};
    Future<String?> nameFor(String? id) async {
      if (id == null || id.isEmpty) return null;
      if (knownNames.containsKey(id)) return knownNames[id];
      final resolved = await _collaboratorName(eventId, id);
      knownNames[id] = resolved;
      return resolved;
    }

    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.skip(i).take(chunk).toList(growable: false);
      final snaps = await Future.wait(
        slice.map((id) => _tickets(eventId).doc(id).get()),
      );
      final batch = _firestore.batch();
      for (final snap in snaps) {
        final data = snap.data();
        if (!snap.exists || data == null) continue;
        final status = TicketStatusX.fromFirestore(data['status'] as String?);
        final resolvedActorId = actorId ?? data['sellerId'] as String?;
        final actorDisplayName = await nameFor(resolvedActorId);
        batch.update(snap.reference, {
          'buyerName': name,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.buyerSet,
              fromStatus: status,
              toStatus: status,
              actorId: resolvedActorId,
              actorRole: actorRole ?? 'seller',
              actorName: actorDisplayName,
              note: name.isEmpty ? 'Comprador borrado' : 'Para: $name',
            ).toFirestoreMap(),
          ]),
        });
      }
      await batch.commit();
    }
  }

  /// Reserves tickets for a buyer (`pool`/`withSeller` → `reserved`).
  ///
  /// Pool tickets are claimed for [sellerId] in the same write.
  Future<void> reserveTickets({
    required String eventId,
    required Iterable<String> ticketIds,
    required String buyerName,
    required String sellerId,
    String? actorId,
    String actorRole = 'seller',
  }) async {
    final name = buyerName.trim();
    if (name.isEmpty) {
      throw StateError('La reserva necesita un destinatario.');
    }

    final ids = ticketIds.toList(growable: false);
    if (ids.isEmpty) return;

    final resolvedActorId = actorId ?? sellerId;
    final actorDisplayName = await _collaboratorName(eventId, resolvedActorId);

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
        if (!status.isAssignablePool && status != TicketStatus.withSeller) {
          throw StateError(
            'Ticket #${data['number']} no se puede reservar.',
          );
        }
        final fromPool = status.isAssignablePool;
        batch.update(snap.reference, {
          'status': TicketStatus.reserved.firestoreValue,
          'buyerName': name,
          if (fromPool) 'sellerId': sellerId,
          if (fromPool) 'assignedByCollaboratorId': null,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.reserved,
              fromStatus: status,
              toStatus: TicketStatus.reserved,
              actorId: resolvedActorId,
              actorRole: actorRole,
              actorName: actorDisplayName,
              note: 'Reservado para $name',
            ).toFirestoreMap(),
          ]),
        });
      }
      await batch.commit();
    }
  }

  /// Clears a reservation (`reserved` → `withSeller`, drops buyer).
  Future<void> clearTicketReservations({
    required String eventId,
    required Iterable<String> ticketIds,
    String? actorId,
    String actorRole = 'seller',
  }) async {
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {TicketStatus.reserved},
      newStatus: TicketStatus.withSeller,
      historyAction: TicketHistoryAction.reservationCleared,
      actorRole: actorRole,
      actorId: actorId,
      actorIdFromField: 'sellerId',
      note: 'Reserva liberada',
      extraFields: {
        'buyerName': '',
      },
    );
  }

  /// Seller marks tickets as collected (`withSeller`/`reserved` → `collected`).
  Future<void> markTicketsCollected({
    required String eventId,
    required Iterable<String> ticketIds,
    String? actorId,
    String actorRole = 'seller',
    String? buyerName,
  }) async {
    final name = buyerName?.trim();
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {TicketStatus.withSeller, TicketStatus.reserved},
      newStatus: TicketStatus.collected,
      historyAction: TicketHistoryAction.collected,
      actorRole: actorRole,
      actorId: actorId,
      actorIdFromField: 'sellerId',
      note: (name != null && name.isNotEmpty) ? 'Para: $name' : null,
      extraFields: {
        if (name != null && name.isNotEmpty) 'buyerName': name,
      },
    );
  }

  /// Collector marks tickets as returned to the free pool
  /// (`withSeller`/`reserved`/`collected` → `returned`) so a coordinator can reassign.
  Future<void> markTicketsReturned({
    required String eventId,
    required Iterable<String> ticketIds,
    String? actorId,
    String actorRole = 'collector',
  }) async {
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {
        TicketStatus.withSeller,
        TicketStatus.reserved,
        TicketStatus.collected,
      },
      newStatus: TicketStatus.returned,
      historyAction: TicketHistoryAction.returned,
      actorRole: actorRole,
      actorId: actorId,
      extraFields: {
        'sellerId': null,
        'buyerName': '',
        'assignedByCollaboratorId': null,
        'collectorId': null,
      },
    );
  }

  /// Organizer returns unsold tickets to the free pool
  /// (`withSeller`/`reserved` → `unassigned`, clears seller + buyer).
  Future<void> returnTicketsToPool({
    required String eventId,
    required Iterable<String> ticketIds,
    String? actorId,
    String actorRole = 'organizer',
  }) async {
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {TicketStatus.withSeller, TicketStatus.reserved},
      newStatus: TicketStatus.unassigned,
      historyAction: TicketHistoryAction.returnedToPool,
      actorRole: actorRole,
      actorId: actorId,
      extraFields: {
        'sellerId': null,
        'buyerName': '',
        'assignedByCollaboratorId': null,
      },
    );
  }

  /// When deleting a seller: unsold tickets go back to the pool; sold ones
  /// keep their status but drop the seller link.
  Future<void> releaseTicketsFromSeller({
    required String eventId,
    required String sellerId,
    String? actorId,
    String actorRole = 'organizer',
  }) async {
    final tickets = await listTickets(eventId);
    final owned =
        tickets.where((t) => t.sellerId == sellerId).toList(growable: false);
    if (owned.isEmpty) return;

    final toPool = owned
        .where(
          (t) =>
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.reserved,
        )
        .map((t) => t.id);
    await returnTicketsToPool(
      eventId: eventId,
      ticketIds: toPool,
      actorId: actorId,
      actorRole: actorRole,
    );

    final sold = owned
        .where(
          (t) =>
              t.status == TicketStatus.collected ||
              t.status == TicketStatus.settled ||
              t.status == TicketStatus.delivered,
        )
        .toList(growable: false);
    if (sold.isEmpty) return;

    final actorDisplayName = await _collaboratorName(eventId, actorId);
    const chunk = 400;
    for (var i = 0; i < sold.length; i += chunk) {
      final slice = sold.skip(i).take(chunk);
      final batch = _firestore.batch();
      for (final ticket in slice) {
        batch.update(_tickets(eventId).doc(ticket.id), {
          'sellerId': null,
          'assignedByCollaboratorId': null,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.returnedToPool,
              fromStatus: ticket.status,
              toStatus: ticket.status,
              actorId: actorId,
              actorRole: actorRole,
              actorName: actorDisplayName,
              note: 'Vendedor eliminado',
            ).toFirestoreMap(),
          ]),
        });
      }
      await batch.commit();
    }
  }

  /// Validator or organizer marks a ticket as delivered
  /// (`collected`/`settled` → `delivered`).
  Future<void> markTicketDelivered({
    required String eventId,
    required String ticketId,
    required String validatorId,
    String actorRole = 'validator',
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
    final actorDisplayName = await _collaboratorName(eventId, validatorId);
    await ref.update({
      'status': TicketStatus.delivered.firestoreValue,
      'validatorId': validatorId,
      'history': FieldValue.arrayUnion([
        TicketHistoryEntry(
          at: DateTime.now(),
          action: TicketHistoryAction.delivered,
          fromStatus: status,
          toStatus: TicketStatus.delivered,
          actorId: validatorId,
          actorRole: actorRole,
          actorName: actorDisplayName,
        ).toFirestoreMap(),
      ]),
    });
  }

  /// Collector settles tickets
  /// (`withSeller`/`reserved`/`collected` → `settled`).
  /// Rendido implica vendido aunque el vendedor no haya marcado cobrado.
  Future<void> markTicketsSettled({
    required String eventId,
    required Iterable<String> ticketIds,
    required String collectorId,
    required TicketSettleMode settleMode,
    String actorRole = 'collector',
  }) async {
    final event = await getById(eventId);
    if (event == null) {
      throw StateError('Evento $eventId no encontrado.');
    }
    final amount = event.amountForSettleMode(settleMode);
    final note = settleMode == TicketSettleMode.full
        ? 'Rendido ticket completo (\$${amount.toStringAsFixed(0)})'
        : 'Rendida solo ganancia (\$${amount.toStringAsFixed(0)})';
    await _updateTicketStatuses(
      eventId: eventId,
      ticketIds: ticketIds,
      expectedStatuses: {
        TicketStatus.withSeller,
        TicketStatus.reserved,
        TicketStatus.collected,
      },
      newStatus: TicketStatus.settled,
      historyAction: TicketHistoryAction.settled,
      actorRole: actorRole,
      actorId: collectorId,
      note: note,
      extraFields: {
        'collectorId': collectorId,
        'settleMode': settleMode.firestoreValue,
        'settledAmount': amount,
      },
    );
  }

  Future<void> _updateTicketStatuses({
    required String eventId,
    required Iterable<String> ticketIds,
    required Set<TicketStatus> expectedStatuses,
    required TicketStatus newStatus,
    required TicketHistoryAction historyAction,
    required String actorRole,
    String? actorId,
    String? actorIdFromField,
    String? note,
    Map<String, Object?> extraFields = const {},
  }) async {
    final ids = ticketIds.toList(growable: false);
    if (ids.isEmpty) return;

    final knownNames = <String, String?>{};
    if (actorId != null) {
      knownNames[actorId] = await _collaboratorName(eventId, actorId);
    }

    Future<String?> nameFor(String? id) async {
      if (id == null || id.isEmpty) return null;
      if (knownNames.containsKey(id)) return knownNames[id];
      final resolved = await _collaboratorName(eventId, id);
      knownNames[id] = resolved;
      return resolved;
    }

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
        final resolvedActorId = actorId ??
            (actorIdFromField == null
                ? null
                : data[actorIdFromField] as String?);
        final actorDisplayName = await nameFor(resolvedActorId);
        batch.update(snap.reference, {
          'status': newStatus.firestoreValue,
          ...extraFields,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: historyAction,
              fromStatus: status,
              toStatus: newStatus,
              actorId: resolvedActorId,
              actorRole: actorRole,
              actorName: actorDisplayName,
              note: note,
            ).toFirestoreMap(),
          ]),
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
    required double ticketProfit,
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
      'ticketProfit': ticketProfit,
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
