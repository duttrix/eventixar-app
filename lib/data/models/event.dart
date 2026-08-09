import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ticket.dart';
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

  static String formatAmount(int n) => _format(n);

  static String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Pricing by ticket volume using Firestore `config/eventPricing`.
  static EventQuote calculate({
    required int ticketCount,
    required EventPricingConfig pricing,
  }) {
    return pricing.quoteFor(ticketCount);
  }
}

/// One inclusive ticket-count band from `config/eventPricing.tiers`.
class EventPricingTier {
  const EventPricingTier({
    required this.min,
    required this.max,
    required this.price,
    required this.label,
  });

  final int min;
  final int max;
  final int price;
  final String label;

  factory EventPricingTier.fromMap(Map<String, dynamic> data) {
    return EventPricingTier(
      min: (data['min'] as num?)?.toInt() ?? 0,
      max: (data['max'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      label: (data['label'] as String?)?.trim() ?? '',
    );
  }
}

/// Extra tickets beyond the last tier (`config/eventPricing.overage`).
class EventPricingOverage {
  const EventPricingOverage({
    required this.baseMax,
    required this.basePrice,
    required this.pricePerTicket,
    required this.label,
  });

  final int baseMax;
  final int basePrice;
  final int pricePerTicket;
  final String label;

  factory EventPricingOverage.fromMap(Map<String, dynamic> data) {
    return EventPricingOverage(
      baseMax: (data['baseMax'] as num?)?.toInt() ?? 0,
      basePrice: (data['basePrice'] as num?)?.toInt() ?? 0,
      pricePerTicket: (data['pricePerTicket'] as num?)?.toInt() ?? 0,
      label: (data['label'] as String?)?.trim() ?? 'A medida',
    );
  }
}

/// Remote pricing table: Firestore `config/eventPricing`.
class EventPricingConfig {
  const EventPricingConfig({
    required this.tiers,
    this.overage,
    this.note =
        'El precio se calcula solo por cantidad de tickets. Vendedores y validadores no suman al costo.',
  });

  final List<EventPricingTier> tiers;
  final EventPricingOverage? overage;
  final String note;

  factory EventPricingConfig.fromFirestore(Map<String, dynamic> data) {
    final rawTiers = data['tiers'];
    final tiers = <EventPricingTier>[];
    if (rawTiers is List) {
      for (final item in rawTiers) {
        if (item is Map<String, dynamic>) {
          tiers.add(EventPricingTier.fromMap(item));
        } else if (item is Map) {
          tiers.add(
            EventPricingTier.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    tiers.sort((a, b) => a.max.compareTo(b.max));

    EventPricingOverage? overage;
    final rawOverage = data['overage'];
    if (rawOverage is Map<String, dynamic>) {
      overage = EventPricingOverage.fromMap(rawOverage);
    } else if (rawOverage is Map) {
      overage = EventPricingOverage.fromMap(
        Map<String, dynamic>.from(rawOverage),
      );
    }

    final note = (data['note'] as String?)?.trim();
    return EventPricingConfig(
      tiers: tiers,
      overage: overage,
      note: (note == null || note.isEmpty)
          ? 'El precio se calcula solo por cantidad de tickets. Vendedores y validadores no suman al costo.'
          : note,
    );
  }

  EventQuote quoteFor(int ticketCount) {
    final count = ticketCount < 0 ? 0 : ticketCount;

    for (final tier in tiers) {
      if (count >= tier.min && count <= tier.max) {
        final label = tier.label.isEmpty
            ? 'De ${tier.min} a ${tier.max} tickets'
            : tier.label;
        return EventQuote(
          amount: tier.price,
          label: tier.price == 0 ? 'Gratis' : 'Cotización del evento',
          breakdown: [
            '$label → \$${EventQuote.formatAmount(tier.price)}',
            note,
          ],
        );
      }
    }

    final overage = this.overage;
    if (overage != null && count > overage.baseMax) {
      final amount = overage.basePrice +
          ((count - overage.baseMax) * overage.pricePerTicket);
      final plan = overage.label.isEmpty
          ? 'A medida ($count tickets)'
          : '${overage.label} ($count tickets)';
      return EventQuote(
        amount: amount,
        label: 'Cotización del evento',
        breakdown: [
          '$plan → \$${EventQuote.formatAmount(amount)}',
          note,
        ],
      );
    }

    return EventQuote(
      amount: 0,
      label: 'Sin tarifa configurada',
      breakdown: [
        'No hay un tramo de precio para $count tickets. Revisá config/eventPricing.',
        note,
      ],
    );
  }
}

/// Catalog suggestions for “qué se vende” (Firestore `config/eventProducts`).
/// Free text is always allowed; these are references only.
List<String> normalizeEventProducts(Iterable<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in items) {
    final item = raw.trim();
    if (item.isEmpty) continue;
    if (seen.add(item)) out.add(item);
  }
  return out;
}

class Event {
  Event({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.name,
    required this.product,
    required this.ticketPrice,
    this.ticketProfit = 0,
    required this.ticketCount,
    required this.eventDate,
    required this.pickupFrom,
    required this.pickupTo,
    required this.pickupPlace,
    required this.sellersCount,
    required this.validatorsCount,
    this.collectorsCount = 0,
    this.coordinatorsCount = 0,
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

  /// Monto que el vendedor rinde cuando entrega solo la ganancia.
  double ticketProfit;

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

  /// Suggested max coordinators for this event.
  int coordinatorsCount;

  EventStatus status;
  bool paid;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// True after ticket docs 1..ticketCount were created in Firestore.
  bool ticketsGenerated;

  /// Visual style applied to shared ticket images for this event.
  TicketVisualStyle ticketDesign;

  /// Amount the collector receives per ticket for a given settle mode.
  double amountForSettleMode(TicketSettleMode mode) => switch (mode) {
        TicketSettleMode.full => ticketPrice,
        TicketSettleMode.profit => ticketProfit,
      };

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
      ticketProfit: (data['ticketProfit'] as num?)?.toDouble() ?? 0,
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
      coordinatorsCount: (data['coordinatorsCount'] as num?)?.toInt() ?? 0,
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
      'ticketProfit': ticketProfit,
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
      'coordinatorsCount': coordinatorsCount,
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
