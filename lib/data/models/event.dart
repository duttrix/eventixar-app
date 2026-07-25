import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ticket_design.dart';

/// Lifecycle of an event owned by a registered organizer.
enum EventStatus {
  /// Created but payment not completed yet.
  awaitingPayment,

  /// Paid and ready to use.
  active,

  /// Closed by the organizer (solo consulta).
  finished,
}

extension EventStatusX on EventStatus {
  String get firestoreValue => name;

  static EventStatus fromFirestore(String? value) {
    return EventStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => EventStatus.awaitingPayment,
    );
  }
}

/// Suggested price quote computed from ticket volume only.
class EventQuote {
  const EventQuote({
    required this.amount,
    required this.label,
    required this.breakdown,
  });

  final int amount;
  final String label;
  final List<String> breakdown;

  String get priceLabel => amount == 0 ? r'$0' : '\$${_format(amount)}';

  static String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Mock pricing by ticket volume. Team size does not affect price.
  static EventQuote calculate({required int ticketCount}) {
    final int base;
    final String plan;

    if (ticketCount <= 50) {
      base = 0;
      plan = 'Free (hasta 50 tickets)';
    } else if (ticketCount <= 100) {
      base = 15000;
      plan = 'Hasta 100 tickets';
    } else if (ticketCount <= 200) {
      base = 20000;
      plan = 'Hasta 200 tickets';
    } else if (ticketCount <= 300) {
      base = 35000;
      plan = 'Hasta 300 tickets';
    } else {
      base = 35000 + ((ticketCount - 300) * 80);
      plan = 'A medida ($ticketCount tickets)';
    }

    return EventQuote(
      amount: base,
      label: base == 0 ? 'Gratis' : 'Cotización del evento',
      breakdown: [
        '$plan → \$${_format(base)}',
        'El precio se calcula solo por cantidad de tickets. Vendedores y validadores no suman al costo.',
      ],
    );
  }
}

const List<String> kEventProducts = [
  'Locro',
  'Empanadas',
  'Pollo asado',
  'Paella',
  'Otro',
];

class Event {
  Event({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.name,
    required this.product,
    required this.ticketPrice,
    required this.ticketCount,
    required this.eventDate,
    required this.pickupFrom,
    required this.pickupTo,
    required this.pickupPlace,
    required this.sellersCount,
    required this.validatorsCount,
    this.collectorsCount = 0,
    this.notes = '',
    this.status = EventStatus.awaitingPayment,
    this.paid = false,
    this.createdAt,
    this.updatedAt,
    this.ticketsGenerated = false,
    this.ticketDesign = TicketVisualStyle.classic,
  });

  final String id;

  /// Firebase Auth uid of the organizer.
  final String ownerId;

  /// Denormalized for display / legacy mock.
  final String ownerEmail;

  String name;
  String product;
  double ticketPrice;
  int ticketCount;
  DateTime eventDate;
  TimeOfDay pickupFrom;
  TimeOfDay pickupTo;
  String pickupPlace;
  String notes;

  /// Suggested max sellers when creating the event (not a hard limit).
  int sellersCount;

  /// Suggested max validators for this event.
  int validatorsCount;

  /// Suggested max collectors for this event.
  int collectorsCount;

  EventStatus status;
  bool paid;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// True after ticket docs 1..ticketCount were created in Firestore.
  bool ticketsGenerated;

  /// Visual style applied to shared ticket images for this event.
  TicketVisualStyle ticketDesign;

  EventQuote get quote => EventQuote.calculate(ticketCount: ticketCount);

  bool get isPast {
    final today = DateTime.now();
    final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return day.isBefore(now) || status == EventStatus.finished;
  }

  factory Event.fromFirestore(String id, Map<String, dynamic> data) {
    return Event(
      id: id,
      ownerId: (data['ownerId'] as String?) ?? '',
      ownerEmail: (data['ownerEmail'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      product: (data['product'] as String?) ?? '',
      ticketPrice: (data['ticketPrice'] as num?)?.toDouble() ?? 0,
      ticketCount: (data['ticketCount'] as num?)?.toInt() ?? 0,
      eventDate: _readDate(data['eventDate']) ?? DateTime.now(),
      pickupFrom:
          _readTime(data['pickupFrom']) ?? const TimeOfDay(hour: 12, minute: 0),
      pickupTo:
          _readTime(data['pickupTo']) ?? const TimeOfDay(hour: 15, minute: 0),
      pickupPlace: (data['pickupPlace'] as String?) ?? '',
      sellersCount: (data['sellersCount'] as num?)?.toInt() ?? 0,
      validatorsCount: (data['validatorsCount'] as num?)?.toInt() ?? 0,
      collectorsCount: (data['collectorsCount'] as num?)?.toInt() ?? 0,
      notes: (data['notes'] as String?) ?? '',
      status: EventStatusX.fromFirestore(data['status'] as String?),
      paid: data['paid'] == true,
      createdAt: _readTimestamp(data['createdAt']),
      updatedAt: _readTimestamp(data['updatedAt']),
      ticketsGenerated: data['ticketsGenerated'] == true,
      ticketDesign: TicketVisualStyle.fromFirestore(data['ticketDesign']),
    );
  }

  Map<String, dynamic> toFirestoreMap({
    FieldValue? createdAtValue,
    FieldValue? updatedAtValue,
  }) {
    return {
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'name': name,
      'product': product,
      'ticketPrice': ticketPrice,
      'ticketCount': ticketCount,
      'eventDate': Timestamp.fromDate(
        DateTime(eventDate.year, eventDate.month, eventDate.day),
      ),
      'pickupFrom': _timeToMap(pickupFrom),
      'pickupTo': _timeToMap(pickupTo),
      'pickupPlace': pickupPlace,
      'sellersCount': sellersCount,
      'validatorsCount': validatorsCount,
      'collectorsCount': collectorsCount,
      'notes': notes,
      'status': status.firestoreValue,
      'paid': paid,
      'ticketsGenerated': ticketsGenerated,
      'ticketDesign': ticketDesign.toFirestoreMap(),
      'createdAt': ?createdAtValue,
      'updatedAt': ?updatedAtValue,
    };
  }

  static Map<String, int> _timeToMap(TimeOfDay time) => {
    'hour': time.hour,
    'minute': time.minute,
  };

  static TimeOfDay? _readTime(Object? value) {
    if (value is Map) {
      final hour = value['hour'];
      final minute = value['minute'];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    }
    return null;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
