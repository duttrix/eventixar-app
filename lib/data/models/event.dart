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

/// Suggested price quote computed from coupons + team size.
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

  /// Mock pricing: base by coupon volume + slots for sellers/deliverers.
  static EventQuote calculate({
    required int couponCount,
    required int sellersCount,
    required int deliverersCount,
  }) {
    final breakdown = <String>[];
    int base;
    String plan;

    if (couponCount <= 50) {
      base = 0;
      plan = 'Free (hasta 50 cupones)';
    } else if (couponCount <= 100) {
      base = 15000;
      plan = 'Base hasta 100 cupones';
    } else if (couponCount <= 200) {
      base = 20000;
      plan = 'Base hasta 200 cupones';
    } else if (couponCount <= 300) {
      base = 35000;
      plan = 'Base hasta 300 cupones';
    } else {
      base = 35000 + ((couponCount - 300) * 80);
      plan = 'Base a medida ($couponCount cupones)';
    }
    breakdown.add('$plan → \$${_format(base)}');

    final sellersExtra = sellersCount * 2500;
    if (sellersCount > 0) {
      breakdown.add('$sellersCount vendedor(es) × \$2.500 → \$${_format(sellersExtra)}');
    }

    final deliverersExtra = deliverersCount * 2000;
    if (deliverersCount > 0) {
      breakdown.add(
        '$deliverersCount entregador(es) × \$2.000 → \$${_format(deliverersExtra)}',
      );
    }

    final total = base + sellersExtra + deliverersExtra;
    return EventQuote(
      amount: total,
      label: total == 0 ? 'Gratis' : 'Cotización del evento',
      breakdown: breakdown,
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
    required this.couponPrice,
    required this.couponCount,
    required this.eventDate,
    required this.pickupFrom,
    required this.pickupTo,
    required this.pickupPlace,
    required this.sellersCount,
    required this.deliverersCount,
    this.notes = '',
    this.status = EventStatus.awaitingPayment,
    this.paid = false,
  });

  final String id;
  final String ownerEmail;
  String name;
  String product;
  double couponPrice;
  int couponCount;
  DateTime eventDate;
  TimeOfDay pickupFrom;
  TimeOfDay pickupTo;
  String pickupPlace;
  String notes;

  /// Max seller slots purchased with the event.
  int sellersCount;

  /// Max deliverer slots purchased with the event.
  int deliverersCount;

  EventStatus status;
  bool paid;

  EventQuote get quote => EventQuote.calculate(
        couponCount: couponCount,
        sellersCount: sellersCount,
        deliverersCount: deliverersCount,
      );

  bool get isPast {
    final today = DateTime.now();
    final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return day.isBefore(now) || status == EventStatus.finished;
  }
}
