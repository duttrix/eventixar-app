import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/collaborator.dart';
import '../models/event.dart';
import '../models/event_product.dart';
import '../models/ticket.dart';
import '../models/ticket_design.dart';
import '../models/user.dart';

/// Firestore access for organizer events + ticket bootstrap.
class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

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

  Future<void> _ensureWritable(String eventId) async {
    final event = await getById(eventId);
    if (event == null) {
      throw StateError('Evento $eventId no encontrado.');
    }
    if (event.isReadOnly) {
      throw StateError('El evento ya finalizó. Solo consulta.');
    }
  }

  /// Creates the full event (tickets included).
  /// Uses a free slot when `users.freeEvents` > 0 (`active`); otherwise `awaitingPayment`.
  Future<({Event event, bool usedFreeSlot})> createEvent({
    required String ownerId,
    required String ownerEmail,
    required String name,
    required List<EventProduct> products,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required int sellersCount,
    required int validatorsCount,
    int collectorsCount = 0,
    int coordinatorsCount = 0,
    String notes = '',
    TicketVisualStyle? ticketDesign,
  }) async {
    if (products.isEmpty) {
      throw ArgumentError('El evento necesita al menos un producto.');
    }
    final ref = _events.doc();
    final now = FieldValue.serverTimestamp();
    final event = Event(
      id: ref.id,
      ownerId: ownerId,
      ownerEmail: ownerEmail,
      name: name,
      product: '',
      ticketPrice: 0,
      ticketProfit: 0,
      ticketCount: 0,
      eventDate: eventDate,
      pickupFrom: pickupFrom,
      pickupTo: pickupTo,
      pickupPlace: pickupPlace,
      sellersCount: sellersCount,
      validatorsCount: validatorsCount,
      collectorsCount: collectorsCount,
      coordinatorsCount: coordinatorsCount,
      notes: notes,
      definedProducts: products,
      status: EventStatus.active,
      ticketsGenerated: false,
      ticketDesign: ticketDesign ?? TicketVisualStyle.classic,
    );
    event.applyProductSummary();

    final userRef = _users.doc(ownerId);
    final usedFreeSlot = await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final raw = userSnap.data()?['freeEvents'];
      final remaining =
          raw is num ? raw.toInt() : AppUser.defaultFreeEvents;
      final useFree = remaining > 0;
      event.status =
          useFree ? EventStatus.active : EventStatus.awaitingPayment;
      tx.set(
        ref,
        event.toFirestoreMap(createdAtValue: now, updatedAtValue: now),
      );
      if (!useFree) return false;
      tx.update(userRef, {'freeEvents': remaining - 1});
      return true;
    });

    await _generateTickets(event);
    await ref.update({
      'ticketsGenerated': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    event.ticketsGenerated = true;
    return (event: event, usedFreeSlot: usedFreeSlot);
  }

  /// Organizer told us they transferred. Event stays in awaitingPayment.
  Future<void> recordTransferNotice(String eventId) async {
    await _events.doc(eventId).update({
      'transferNotifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Legacy: if an old event was flipped to active without tickets, create them.
  Future<Event> ensureActiveEventReady(String eventId) async {
    final ref = _events.doc(eventId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Evento $eventId no encontrado.');
    }

    var event = Event.fromFirestore(snap.id, data);
    if (event.ticketsGenerated) return event;
    if (event.status != EventStatus.active) return event;

    await _generateTickets(event);
    await ref.update({
      'status': EventStatus.active.firestoreValue,
      'ticketsGenerated': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    event
      ..status = EventStatus.active
      ..ticketsGenerated = true;
    return event;
  }

  Future<void> _generateTickets(Event event) async {
    if (!event.hasDefinedProducts) {
      await _writeTicketChunk(
        eventId: event.id,
        from: 1,
        to: event.ticketCount,
        docIdFor: (n) => 't_$n',
      );
      return;
    }
    var nextNumber = 1;
    for (final product in event.definedProducts) {
      final seeds = <({int number, String? variantId})>[];
      if (product.variants.isEmpty) {
        for (var i = 0; i < product.ticketCount; i++) {
          seeds.add((number: nextNumber, variantId: null));
          nextNumber++;
        }
      } else {
        for (final variant in product.variants) {
          for (var i = 0; i < variant.quota; i++) {
            seeds.add((number: nextNumber, variantId: variant.id));
            nextNumber++;
          }
        }
      }
      await _writeTicketSeeds(
        eventId: event.id,
        productId: product.id,
        seeds: seeds,
      );
    }
  }

  Future<void> _writeTicketSeeds({
    required String eventId,
    required String productId,
    required List<({int number, String? variantId})> seeds,
  }) async {
    const chunk = 400;
    for (var i = 0; i < seeds.length; i += chunk) {
      final slice = seeds.skip(i).take(chunk);
      final batch = _firestore.batch();
      for (final seed in slice) {
        final ticketRef = _tickets(eventId).doc('t_${productId}_${seed.number}');
        batch.set(ticketRef, {
          'number': seed.number,
          'status': TicketStatus.unassigned.firestoreValue,
          'sellerId': null,
          'validatorId': null,
          'collectorId': null,
          'assignedByCollaboratorId': null,
          'buyerName': '',
          'productId': productId,
          'variantId': ?seed.variantId,
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

  Future<void> _writeTicketChunk({
    required String eventId,
    required int from,
    required int to,
    required String Function(int number) docIdFor,
    String? productId,
  }) async {
    if (to < from) return;
    const chunk = 400;
    for (var start = from; start <= to; start += chunk) {
      final end = (start + chunk - 1).clamp(from, to);
      final batch = _firestore.batch();
      for (var n = start; n <= end; n++) {
        final ticketRef = _tickets(eventId).doc(docIdFor(n));
        batch.set(ticketRef, {
          'number': n,
          'status': TicketStatus.unassigned.firestoreValue,
          'sellerId': null,
          'validatorId': null,
          'collectorId': null,
          'assignedByCollaboratorId': null,
          'buyerName': '',
          'productId': ?productId,
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
    String? productId,
  }) async {
    await _ensureWritable(eventId);
    if (to < from) {
      throw ArgumentError('El rango es inválido (hasta < desde).');
    }

    final Query<Map<String, dynamic>> query;
    if (productId != null && productId.isNotEmpty) {
      query = _tickets(eventId).where('productId', isEqualTo: productId);
    } else {
      query = _tickets(eventId)
          .where('number', isGreaterThanOrEqualTo: from)
          .where('number', isLessThanOrEqualTo: to);
    }
    final snap = await query.get();
    final docs = (productId != null && productId.isNotEmpty)
        ? snap.docs.where((doc) {
            final number = (doc.data()['number'] as num?)?.toInt() ?? 0;
            return number >= from && number <= to;
          }).toList(growable: false)
        : snap.docs;

    final expected = to - from + 1;
    if (docs.length != expected) {
      throw StateError(
        'Algunos tickets del rango no existen. Revisá la cantidad del evento.',
      );
    }

    for (final doc in docs) {
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
      productId: productId,
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
    for (var i = 0; i < docs.length; i += chunk) {
      final batch = _firestore.batch();
      final slice = docs.skip(i).take(chunk);
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

  /// Assigns tickets to [sellerId]. Pool tickets become `withSeller`.
  /// Reserved tickets stay reserved and keep [Ticket.buyerName].
  Future<void> claimTicketsForSeller({
    required String eventId,
    required Iterable<String> ticketIds,
    required String sellerId,
    String actorRole = 'organizer',
    String? actorId,
  }) async {
    await _ensureWritable(eventId);
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
        if (!status.canAssignToSeller) {
          throw StateError(
            'Ticket #${data['number']} no se puede asignar a un vendedor.',
          );
        }
        final nextStatus = status == TicketStatus.reserved
            ? TicketStatus.reserved
            : TicketStatus.withSeller;
        batch.update(snap.reference, {
          'status': nextStatus.firestoreValue,
          'sellerId': sellerId,
          'assignedByCollaboratorId': actorRole == 'coordinator' ? actorId : null,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.assigned,
              fromStatus: status,
              toStatus: nextStatus,
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
    await _ensureWritable(eventId);
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
    await _ensureWritable(eventId);
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
    await _ensureWritable(eventId);
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
        'variantId': null,
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
        'variantId': null,
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
    await _ensureWritable(eventId);
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
    await _ensureWritable(eventId);
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
    if (event.isReadOnly) {
      throw StateError('El evento ya finalizó. Solo consulta.');
    }
    final ids = ticketIds.toList(growable: false);
    if (ids.isEmpty) return;

    final actorDisplayName = await _collaboratorName(eventId, collectorId);
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
        final ticket = Ticket.fromFirestore(
          id: snap.id,
          eventId: eventId,
          data: data,
        );
        final status = ticket.status;
        if (status != TicketStatus.withSeller &&
            status != TicketStatus.reserved &&
            status != TicketStatus.collected) {
          throw StateError(
            'Ticket #${ticket.number} no está en el estado esperado.',
          );
        }
        final amount = event.settleAmountFor(ticket, settleMode);
        if (amount == null) {
          throw StateError(
            'El ticket #${ticket.number} no tiene precio. Elegí la opción.',
          );
        }
        final note = settleMode == TicketSettleMode.full
            ? 'Rendido ticket completo (\$${amount.toStringAsFixed(0)})'
            : 'Rendida solo ganancia (\$${amount.toStringAsFixed(0)})';
        batch.update(snap.reference, {
          'status': TicketStatus.settled.firestoreValue,
          'collectorId': collectorId,
          'settleMode': settleMode.firestoreValue,
          'settledAmount': amount,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.settled,
              fromStatus: status,
              toStatus: TicketStatus.settled,
              actorId: collectorId,
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

  /// Sets the flavor or priced option on tickets that do not have one yet.
  Future<void> setTicketsVariant({
    required String eventId,
    required Iterable<String> ticketIds,
    required String variantId,
    String? actorId,
    String actorRole = 'seller',
  }) async {
    final event = await getById(eventId);
    if (event == null) {
      throw StateError('Evento $eventId no encontrado.');
    }
    if (event.isReadOnly) {
      throw StateError('El evento ya finalizó. Solo consulta.');
    }
    EventProduct? owner;
    EventProductVariant? variant;
    for (final product in event.products) {
      final found = product.variantById(variantId);
      if (found != null) {
        owner = product;
        variant = found;
        break;
      }
    }
    if (owner == null || variant == null) {
      throw StateError('Esa opción no existe en el evento.');
    }

    final ids = ticketIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;
    final snaps = await Future.wait(
      ids.map((id) => _tickets(eventId).doc(id).get()),
    );
    final tickets = <Ticket>[];
    for (final snap in snaps) {
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw StateError('Ticket ${snap.id} no encontrado.');
      }
      final ticket = Ticket.fromFirestore(
        id: snap.id,
        eventId: eventId,
        data: data,
      );
      if (event.productFor(ticket).id != owner.id) {
        throw StateError(
          'La opción no corresponde al producto del ticket #${ticket.number}.',
        );
      }
      tickets.add(ticket);
    }

    if (variant.quota > 0) {
      final existing = await _tickets(eventId)
          .where('variantId', isEqualTo: variantId)
          .get();
      final updating = ids.toSet();
      var used = 0;
      for (final doc in existing.docs) {
        if (updating.contains(doc.id)) continue;
        used++;
      }
      var adding = 0;
      for (final ticket in tickets) {
        if (ticket.variantId == variantId) continue;
        adding++;
      }
      if (used + adding > variant.quota) {
        final left = variant.quota - used;
        throw StateError(
          left > 0
              ? 'No hay cupo de ${variant.name}. Quedan $left.'
              : 'No hay cupo de ${variant.name}.',
        );
      }
    }

    final actorName = await _collaboratorName(eventId, actorId);
    const chunk = 400;
    for (var i = 0; i < tickets.length; i += chunk) {
      final slice = tickets.skip(i).take(chunk).toList(growable: false);
      final pending = slice
          .where((ticket) => ticket.variantId != variantId)
          .toList(growable: false);
      if (pending.isEmpty) continue;
      final batch = _firestore.batch();
      for (final ticket in pending) {
        batch.update(_tickets(eventId).doc(ticket.id), {
          'variantId': variantId,
          'history': FieldValue.arrayUnion([
            TicketHistoryEntry(
              at: DateTime.now(),
              action: TicketHistoryAction.variantSet,
              fromStatus: ticket.status,
              toStatus: ticket.status,
              actorId: actorId,
              actorRole: actorRole,
              actorName: actorName,
              note: 'Opción: ${variant.name}',
            ).toFirestoreMap(),
          ]),
        });
      }
      await batch.commit();
    }
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

    await _ensureWritable(eventId);

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
    required List<EventProduct> products,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required String notes,
  }) async {
    await _ensureWritable(eventId);
    if (products.isEmpty) {
      throw ArgumentError('El evento necesita al menos un producto.');
    }
    final current = await getById(eventId);
    if (current == null) throw StateError('Evento $eventId no encontrado.');
    if (current.ticketsGenerated &&
        products.length != current.products.length) {
      throw StateError('No se pueden agregar ni quitar productos.');
    }
    for (var i = 0; i < products.length; i++) {
      final next = products[i];
      final previous = current.products[i];
      if (next.id != previous.id || next.ticketCount != previous.ticketCount) {
        throw StateError(
          'La cantidad de tickets de ${previous.name} no se puede cambiar.',
        );
      }
      if (!current.ticketsGenerated) continue;
      if (next.variants.length != previous.variants.length) {
        throw StateError(
          'No se pueden cambiar las opciones de ${previous.name}.',
        );
      }
      for (var j = 0; j < next.variants.length; j++) {
        final nextVariant = next.variants[j];
        final previousVariant = previous.variants[j];
        if (nextVariant.id != previousVariant.id ||
            nextVariant.quota != previousVariant.quota) {
          throw StateError(
            'La cantidad de ${previousVariant.name} no se puede cambiar.',
          );
        }
      }
    }
    final draft = Event(
      id: current.id,
      ownerId: current.ownerId,
      ownerEmail: current.ownerEmail,
      name: name,
      product: current.product,
      ticketPrice: current.ticketPrice,
      ticketProfit: current.ticketProfit,
      ticketCount: current.ticketCount,
      eventDate: eventDate,
      pickupFrom: pickupFrom,
      pickupTo: pickupTo,
      pickupPlace: pickupPlace,
      sellersCount: current.sellersCount,
      validatorsCount: current.validatorsCount,
      collectorsCount: current.collectorsCount,
      coordinatorsCount: current.coordinatorsCount,
      notes: notes,
      definedProducts: products,
      status: current.status,
    );
    draft.applyProductSummary();
    final ref = _events.doc(eventId);
    await ref.update({
      'name': name,
      'product': draft.product,
      'ticketPrice': draft.ticketPrice,
      'ticketProfit': draft.ticketProfit,
      'ticketCount': draft.ticketCount,
      'products': products.map((item) => item.toMap()).toList(),
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
    await _ensureWritable(eventId);
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
