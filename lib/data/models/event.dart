import 'package:flutter/material.dart';

/// Lifecycle of an event owned by a registered organizer.
enum EventStatus {
  /// Created but payment not completed yet.
  awaitingPayment,

  /// Paid and ready to use.
  active,

  /// Event date already passed (shown under "pasados").
  finished,
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

  /// Mock pricing by ticket volume. Team size (sellers/validators) does not affect price.
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
    this.notes = '',
    this.status = EventStatus.awaitingPayment,
    this.paid = false,
  });

  final String id;
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

  /// Suggested max validators for this event (pickup desk or event entrance).
  int validatorsCount;

  EventStatus status;
  bool paid;

  EventQuote get quote => EventQuote.calculate(ticketCount: ticketCount);

  bool get isPast {
    final today = DateTime.now();
    final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return day.isBefore(now) || status == EventStatus.finished;
  }
}
