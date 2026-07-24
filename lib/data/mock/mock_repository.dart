import 'package:flutter/material.dart';

import '../models/collaborator.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../models/user.dart';

/// In-memory mock source of truth for the simplified Eventixar circuit.
///
/// No institutions / memberships: a registered user owns events; sellers and
/// validators enter via deeplink tokens without needing an account first.
class MockRepository extends ChangeNotifier {
  MockRepository() {
    _seed();
  }

  final List<AppUser> users = [];
  final List<Event> events = [];
  final List<Collaborator> collaborators = [];
  final List<Ticket> tickets = [];
  final Map<String, Map<TicketStatus, int>> ticketAggregate = {};

  int _idCounter = 1000;
  String _nextId(String prefix) => '$prefix${_idCounter++}';

  // ---------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------

  AppUser? userByEmail(String email) {
    for (final u in users) {
      if (u.email == email) return u;
    }
    return null;
  }

  Event eventById(String id) => events.firstWhere((e) => e.id == id);

  List<Event> eventsForOwner(String email) =>
      events.where((e) => e.ownerEmail == email).toList()
        ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

  List<Collaborator> collaboratorsForEvent(String eventId) =>
      collaborators.where((c) => c.eventId == eventId).toList();

  List<Collaborator> sellersForEvent(String eventId) => collaborators
      .where((c) => c.eventId == eventId && c.role == CollaboratorRole.seller)
      .toList();

  List<Collaborator> validatorsForEvent(String eventId) => collaborators
      .where((c) => c.eventId == eventId && c.role == CollaboratorRole.validator)
      .toList();

  Collaborator collaboratorById(String id) =>
      collaborators.firstWhere((c) => c.id == id);

  Collaborator? collaboratorByToken(String token) {
    for (final c in collaborators) {
      if (c.token == token) return c;
    }
    return null;
  }

  List<Ticket> ticketsForSeller(String sellerId) =>
      tickets.where((t) => t.sellerId == sellerId).toList();

  Ticket? ticketById(String id) {
    for (final t in tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  Map<TicketStatus, int> aggregateForEvent(String eventId) =>
      ticketAggregate[eventId] ??
      {for (final s in TicketStatus.values) s: 0};

  int totalTicketsForEvent(String eventId) =>
      aggregateForEvent(eventId).values.fold(0, (a, b) => a + b);

  int nextAvailableTicketNumber(String eventId) {
    final numbers = tickets.where((t) => t.eventId == eventId).map((t) => t.number).toList();
    if (numbers.isEmpty) return 1;
    numbers.sort();
    return numbers.last + 1;
  }

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------

  AppUser ensureUser(String email, {String? name}) {
    final existing = userByEmail(email);
    if (existing != null) return existing;
    final user = AppUser(
      email: email,
      name: name ?? email.split('@').first,
    );
    users.add(user);
    notifyListeners();
    return user;
  }

  // ---------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------

  Event createEvent({
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
    String notes = '',
  }) {
    final event = Event(
      id: _nextId('ev_'),
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
      notes: notes,
      status: EventStatus.awaitingPayment,
      paid: false,
    );
    events.add(event);
    ticketAggregate[event.id] = {
      for (final s in TicketStatus.values) s: 0,
    }..[TicketStatus.unassigned] = ticketCount;
    notifyListeners();
    return event;
  }

  /// Simulates accepting payment → event becomes active.
  void confirmPayment(String eventId) {
    final event = eventById(eventId);
    event
      ..paid = true
      ..status = EventStatus.active;
    notifyListeners();
  }

  void updateEvent(
    String eventId, {
    required String name,
    required String product,
    required double ticketPrice,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required String notes,
  }) {
    final event = eventById(eventId);
    event
      ..name = name
      ..product = product
      ..ticketPrice = ticketPrice
      ..eventDate = eventDate
      ..pickupFrom = pickupFrom
      ..pickupTo = pickupTo
      ..pickupPlace = pickupPlace
      ..notes = notes;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Collaborators (sellers / validators) + deeplinks
  // ---------------------------------------------------------------------

  Collaborator addCollaborator({
    required String eventId,
    required CollaboratorRole role,
    required String name,
    required String phone,
    String notes = '',
  }) {
    final collaborator = Collaborator(
      id: _nextId(role == CollaboratorRole.seller ? 'sel_' : 'val_'),
      eventId: eventId,
      role: role,
      name: name,
      phone: phone,
      notes: notes,
      token: _nextId('tok_'),
    );
    collaborators.add(collaborator);
    notifyListeners();
    return collaborator;
  }

  void updateCollaborator(
    String collaboratorId, {
    required String name,
    required String phone,
    String? notes,
  }) {
    final collaborator = collaboratorById(collaboratorId);
    collaborator
      ..name = name
      ..phone = phone;
    if (notes != null) collaborator.notes = notes;
    notifyListeners();
  }

  void assignTicketRange({
    required String sellerId,
    required int from,
    required int to,
  }) {
    final seller = collaboratorById(sellerId);
    if (seller.role != CollaboratorRole.seller) {
      throw StateError('Solo se pueden asignar tickets a vendedores.');
    }
    seller.ranges.add(
      TicketRange(id: _nextId('rng_'), from: from, to: to, date: DateTime.now()),
    );
    final range = to - from + 1;
    for (var n = from; n <= to; n++) {
      tickets.add(
        Ticket(
          id: _nextId('tkt_'),
          eventId: seller.eventId,
          number: n,
          status: TicketStatus.withSeller,
          sellerId: sellerId,
        ),
      );
    }
    _shiftAggregate(seller.eventId, TicketStatus.unassigned, -range);
    _shiftAggregate(seller.eventId, TicketStatus.withSeller, range);
    notifyListeners();
  }

  void updateTicketStatus(String ticketId, TicketStatus newStatus) {
    final ticket = tickets.firstWhere((t) => t.id == ticketId);
    if (ticket.status == newStatus) return;
    _shiftAggregate(ticket.eventId, ticket.status, -1);
    _shiftAggregate(ticket.eventId, newStatus, 1);
    ticket.status = newStatus;
    notifyListeners();
  }

  void markAllCollectedForSeller(String sellerId) {
    for (final ticket in tickets.where((t) => t.sellerId == sellerId)) {
      if (ticket.status != TicketStatus.collected) {
        _shiftAggregate(ticket.eventId, ticket.status, -1);
        _shiftAggregate(ticket.eventId, TicketStatus.collected, 1);
        ticket.status = TicketStatus.collected;
      }
    }
    notifyListeners();
  }

  void markDelivered(String ticketId) {
    updateTicketStatus(ticketId, TicketStatus.delivered);
  }

  /// Mock QR lookup: finds a ticket by number within an event.
  Ticket? findTicketByNumber(String eventId, int number) {
    for (final t in tickets) {
      if (t.eventId == eventId && t.number == number) return t;
    }
    return null;
  }

  void _shiftAggregate(String eventId, TicketStatus status, int delta) {
    final map = ticketAggregate.putIfAbsent(
      eventId,
      () => {for (final s in TicketStatus.values) s: 0},
    );
    map[status] = (map[status] ?? 0) + delta;
  }

  // ---------------------------------------------------------------------
  // Seed
  // ---------------------------------------------------------------------

  void _seed() {
    users.add(AppUser(email: 'organizador@demo.com', name: 'María Organizadora'));

    final now = DateTime.now();

    final active = Event(
      id: 'ev1',
      ownerEmail: 'organizador@demo.com',
      name: 'Pollo a beneficio',
      product: 'Pollo asado',
      ticketPrice: 2000,
      ticketCount: 200,
      eventDate: now.add(const Duration(days: 21)),
      pickupFrom: const TimeOfDay(hour: 12, minute: 0),
      pickupTo: const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: 'Sede del club, Av. San Martín 450',
      sellersCount: 3,
      validatorsCount: 2,
      notes: 'Retirar por la puerta lateral.',
      status: EventStatus.active,
      paid: true,
    );

    final awaiting = Event(
      id: 'ev2',
      ownerEmail: 'organizador@demo.com',
      name: 'Rifa Anual',
      product: 'Locro',
      ticketPrice: 1500,
      ticketCount: 80,
      eventDate: now.add(const Duration(days: 60)),
      pickupFrom: const TimeOfDay(hour: 12, minute: 0),
      pickupTo: const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: 'Sede del club',
      sellersCount: 2,
      validatorsCount: 1,
      status: EventStatus.awaitingPayment,
      paid: false,
    );

    final past = Event(
      id: 'ev3',
      ownerEmail: 'organizador@demo.com',
      name: 'Kermesse 2025',
      product: 'Empanadas',
      ticketPrice: 1800,
      ticketCount: 120,
      eventDate: now.subtract(const Duration(days: 45)),
      pickupFrom: const TimeOfDay(hour: 12, minute: 0),
      pickupTo: const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: 'Patio escolar',
      sellersCount: 2,
      validatorsCount: 1,
      status: EventStatus.finished,
      paid: true,
    );

    events.addAll([active, awaiting, past]);

    ticketAggregate['ev1'] = {
      TicketStatus.unassigned: 80,
      TicketStatus.withSeller: 40,
      TicketStatus.collected: 60,
      TicketStatus.returned: 10,
      TicketStatus.delivered: 10,
    };
    ticketAggregate['ev2'] = {
      for (final s in TicketStatus.values) s: 0,
    }..[TicketStatus.unassigned] = 80;
    ticketAggregate['ev3'] = {
      TicketStatus.unassigned: 0,
      TicketStatus.withSeller: 0,
      TicketStatus.collected: 20,
      TicketStatus.returned: 5,
      TicketStatus.delivered: 95,
    };

    final ana = Collaborator(
      id: 'sel1',
      eventId: 'ev1',
      role: CollaboratorRole.seller,
      name: 'Ana Gómez',
      phone: '351-1112222',
      token: 'seller-ana-demo',
      notes: 'Vende en el barrio Alberdi.',
      ranges: [
        TicketRange(
          id: 'rng1',
          from: 1,
          to: 30,
          date: now.subtract(const Duration(days: 10)),
        ),
      ],
    );
    final diego = Collaborator(
      id: 'sel2',
      eventId: 'ev1',
      role: CollaboratorRole.seller,
      name: 'Diego Torres',
      phone: '351-3334444',
      token: 'seller-diego-demo',
      ranges: [
        TicketRange(
          id: 'rng2',
          from: 31,
          to: 70,
          date: now.subtract(const Duration(days: 6)),
        ),
      ],
    );
    final carlos = Collaborator(
      id: 'val1',
      eventId: 'ev1',
      role: CollaboratorRole.validator,
      name: 'Carlos Ruiz',
      phone: '351-5556666',
      token: 'validator-carlos-demo',
    );

    collaborators.addAll([ana, diego, carlos]);

    for (var n = 1; n <= 30; n++) {
      final status = n <= 18
          ? TicketStatus.collected
          : n <= 26
              ? TicketStatus.withSeller
              : TicketStatus.returned;
      tickets.add(
        Ticket(id: 'tkt_s1_$n', eventId: 'ev1', number: n, status: status, sellerId: 'sel1'),
      );
    }
    for (var n = 31; n <= 70; n++) {
      tickets.add(
        Ticket(
          id: 'tkt_s2_$n',
          eventId: 'ev1',
          number: n,
          status: TicketStatus.withSeller,
          sellerId: 'sel2',
        ),
      );
    }
  }
}
