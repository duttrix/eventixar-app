import 'package:flutter/material.dart';

import '../models/collaborator.dart';
import '../models/coupon.dart';
import '../models/event.dart';
import '../models/user.dart';

/// In-memory mock source of truth for the simplified Eventixar circuit.
///
/// No institutions / memberships: a registered user owns events; sellers and
/// deliverers enter via deeplink tokens without needing an account first.
class MockRepository extends ChangeNotifier {
  MockRepository() {
    _seed();
  }

  final List<AppUser> users = [];
  final List<Event> events = [];
  final List<Collaborator> collaborators = [];
  final List<Coupon> coupons = [];
  final Map<String, Map<CouponStatus, int>> couponAggregate = {};

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

  List<Collaborator> deliverersForEvent(String eventId) => collaborators
      .where((c) => c.eventId == eventId && c.role == CollaboratorRole.deliverer)
      .toList();

  Collaborator collaboratorById(String id) =>
      collaborators.firstWhere((c) => c.id == id);

  Collaborator? collaboratorByToken(String token) {
    for (final c in collaborators) {
      if (c.token == token) return c;
    }
    return null;
  }

  List<Coupon> couponsForSeller(String sellerId) =>
      coupons.where((c) => c.sellerId == sellerId).toList();

  Map<CouponStatus, int> aggregateForEvent(String eventId) =>
      couponAggregate[eventId] ??
      {for (final s in CouponStatus.values) s: 0};

  int totalCouponsForEvent(String eventId) =>
      aggregateForEvent(eventId).values.fold(0, (a, b) => a + b);

  int nextAvailableCouponNumber(String eventId) {
    final numbers = coupons.where((c) => c.eventId == eventId).map((c) => c.number).toList();
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
    required double couponPrice,
    required int couponCount,
    required DateTime eventDate,
    required TimeOfDay pickupFrom,
    required TimeOfDay pickupTo,
    required String pickupPlace,
    required int sellersCount,
    required int deliverersCount,
    String notes = '',
  }) {
    final event = Event(
      id: _nextId('ev_'),
      ownerEmail: ownerEmail,
      name: name,
      product: product,
      couponPrice: couponPrice,
      couponCount: couponCount,
      eventDate: eventDate,
      pickupFrom: pickupFrom,
      pickupTo: pickupTo,
      pickupPlace: pickupPlace,
      sellersCount: sellersCount,
      deliverersCount: deliverersCount,
      notes: notes,
      status: EventStatus.awaitingPayment,
      paid: false,
    );
    events.add(event);
    couponAggregate[event.id] = {
      for (final s in CouponStatus.values) s: 0,
    }..[CouponStatus.unassigned] = couponCount;
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
    required double couponPrice,
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
      ..couponPrice = couponPrice
      ..eventDate = eventDate
      ..pickupFrom = pickupFrom
      ..pickupTo = pickupTo
      ..pickupPlace = pickupPlace
      ..notes = notes;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Collaborators (sellers / deliverers) + deeplinks
  // ---------------------------------------------------------------------

  Collaborator addCollaborator({
    required String eventId,
    required CollaboratorRole role,
    required String name,
    required String phone,
    String notes = '',
  }) {
    final event = eventById(eventId);
    final current = role == CollaboratorRole.seller
        ? sellersForEvent(eventId).length
        : deliverersForEvent(eventId).length;
    final max = role == CollaboratorRole.seller ? event.sellersCount : event.deliverersCount;
    if (current >= max) {
      throw StateError('No quedan cupos de ${role.label.toLowerCase()} para este evento.');
    }

    final collaborator = Collaborator(
      id: _nextId(role == CollaboratorRole.seller ? 'sel_' : 'del_'),
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

  void assignCouponRange({
    required String sellerId,
    required int from,
    required int to,
  }) {
    final seller = collaboratorById(sellerId);
    if (seller.role != CollaboratorRole.seller) {
      throw StateError('Solo se pueden asignar cupones a vendedores.');
    }
    seller.ranges.add(
      CouponRange(id: _nextId('rng_'), from: from, to: to, date: DateTime.now()),
    );
    final range = to - from + 1;
    for (var n = from; n <= to; n++) {
      coupons.add(
        Coupon(
          id: _nextId('cup_'),
          eventId: seller.eventId,
          number: n,
          status: CouponStatus.withSeller,
          sellerId: sellerId,
        ),
      );
    }
    _shiftAggregate(seller.eventId, CouponStatus.unassigned, -range);
    _shiftAggregate(seller.eventId, CouponStatus.withSeller, range);
    notifyListeners();
  }

  void updateCouponStatus(String couponId, CouponStatus newStatus) {
    final coupon = coupons.firstWhere((c) => c.id == couponId);
    if (coupon.status == newStatus) return;
    _shiftAggregate(coupon.eventId, coupon.status, -1);
    _shiftAggregate(coupon.eventId, newStatus, 1);
    coupon.status = newStatus;
    notifyListeners();
  }

  void markAllCollectedForSeller(String sellerId) {
    for (final coupon in coupons.where((c) => c.sellerId == sellerId)) {
      if (coupon.status != CouponStatus.collected) {
        _shiftAggregate(coupon.eventId, coupon.status, -1);
        _shiftAggregate(coupon.eventId, CouponStatus.collected, 1);
        coupon.status = CouponStatus.collected;
      }
    }
    notifyListeners();
  }

  void markDelivered(String couponId) {
    updateCouponStatus(couponId, CouponStatus.delivered);
  }

  /// Mock QR lookup: finds a coupon by number within an event.
  Coupon? findCouponByNumber(String eventId, int number) {
    for (final c in coupons) {
      if (c.eventId == eventId && c.number == number) return c;
    }
    return null;
  }

  void _shiftAggregate(String eventId, CouponStatus status, int delta) {
    final map = couponAggregate.putIfAbsent(
      eventId,
      () => {for (final s in CouponStatus.values) s: 0},
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
      couponPrice: 2000,
      couponCount: 200,
      eventDate: now.add(const Duration(days: 21)),
      pickupFrom: const TimeOfDay(hour: 12, minute: 0),
      pickupTo: const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: 'Sede del club, Av. San Martín 450',
      sellersCount: 3,
      deliverersCount: 2,
      notes: 'Retirar por la puerta lateral.',
      status: EventStatus.active,
      paid: true,
    );

    final awaiting = Event(
      id: 'ev2',
      ownerEmail: 'organizador@demo.com',
      name: 'Rifa Anual',
      product: 'Locro',
      couponPrice: 1500,
      couponCount: 80,
      eventDate: now.add(const Duration(days: 60)),
      pickupFrom: const TimeOfDay(hour: 12, minute: 0),
      pickupTo: const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: 'Sede del club',
      sellersCount: 2,
      deliverersCount: 1,
      status: EventStatus.awaitingPayment,
      paid: false,
    );

    final past = Event(
      id: 'ev3',
      ownerEmail: 'organizador@demo.com',
      name: 'Kermesse 2025',
      product: 'Empanadas',
      couponPrice: 1800,
      couponCount: 120,
      eventDate: now.subtract(const Duration(days: 45)),
      pickupFrom: const TimeOfDay(hour: 12, minute: 0),
      pickupTo: const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: 'Patio escolar',
      sellersCount: 2,
      deliverersCount: 1,
      status: EventStatus.finished,
      paid: true,
    );

    events.addAll([active, awaiting, past]);

    couponAggregate['ev1'] = {
      CouponStatus.unassigned: 80,
      CouponStatus.withSeller: 40,
      CouponStatus.collected: 60,
      CouponStatus.returned: 10,
      CouponStatus.delivered: 10,
    };
    couponAggregate['ev2'] = {
      for (final s in CouponStatus.values) s: 0,
    }..[CouponStatus.unassigned] = 80;
    couponAggregate['ev3'] = {
      CouponStatus.unassigned: 0,
      CouponStatus.withSeller: 0,
      CouponStatus.collected: 20,
      CouponStatus.returned: 5,
      CouponStatus.delivered: 95,
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
        CouponRange(
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
        CouponRange(
          id: 'rng2',
          from: 31,
          to: 70,
          date: now.subtract(const Duration(days: 6)),
        ),
      ],
    );
    final carlos = Collaborator(
      id: 'del1',
      eventId: 'ev1',
      role: CollaboratorRole.deliverer,
      name: 'Carlos Ruiz',
      phone: '351-5556666',
      token: 'deliverer-carlos-demo',
    );

    collaborators.addAll([ana, diego, carlos]);

    for (var n = 1; n <= 30; n++) {
      final status = n <= 18
          ? CouponStatus.collected
          : n <= 26
              ? CouponStatus.withSeller
              : CouponStatus.returned;
      coupons.add(
        Coupon(id: 'cup_s1_$n', eventId: 'ev1', number: n, status: status, sellerId: 'sel1'),
      );
    }
    for (var n = 31; n <= 70; n++) {
      coupons.add(
        Coupon(
          id: 'cup_s2_$n',
          eventId: 'ev1',
          number: n,
          status: CouponStatus.withSeller,
          sellerId: 'sel2',
        ),
      );
    }
  }
}
