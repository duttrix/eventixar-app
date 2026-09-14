import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';

/// Discount coupon under `sellers/{sellerId}/coupons/{code}`.
class Coupon {
  const Coupon({
    required this.code,
    required this.sellerId,
    required this.discountPercent,
    required this.used,
    this.eventId,
    this.originalAmount,
    this.discountAmount,
    this.finalAmount,
  });

  final String code;
  final String sellerId;
  final int discountPercent;
  final bool used;
  final String? eventId;
  final int? originalAmount;
  final int? discountAmount;
  final int? finalAmount;
}

class CouponRepository {
  CouponRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _index =>
      _firestore.collection('couponIndex');

  DocumentReference<Map<String, dynamic>> _couponDoc(
    String sellerId,
    String code,
  ) => _firestore.collection('sellers').doc(sellerId).collection('coupons').doc(code);

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// Looks up a code and attaches it to the event. One-time use.
  Future<Coupon> applyToEvent({
    required String eventId,
    required String eventName,
    required String code,
    String? organizerName,
  }) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) {
      throw StateError('Ingresá un cupón.');
    }

    return _firestore.runTransaction((tx) async {
      final indexSnap = await tx.get(_index.doc(normalized));
      final sellerId = indexSnap.data()?['sellerId'] as String?;
      if (!indexSnap.exists || sellerId == null || sellerId.isEmpty) {
        throw StateError('Ese cupón no existe.');
      }

      final couponRef = _couponDoc(sellerId, normalized);
      final eventRef = _firestore.collection('events').doc(eventId);
      final couponSnap = await tx.get(couponRef);
      final eventSnap = await tx.get(eventRef);
      final couponData = couponSnap.data();
      final eventData = eventSnap.data();
      if (!couponSnap.exists || couponData == null) {
        throw StateError('Ese cupón no existe.');
      }
      if (!eventSnap.exists || eventData == null) {
        throw StateError('Evento no encontrado.');
      }
      if (couponData['used'] == true) {
        throw StateError('Ese cupón ya fue usado.');
      }

      final percent = (couponData['discountPercent'] as num?)?.toInt() ?? 0;
      if (percent < 1 || percent > 99) {
        throw StateError('Cupón inválido.');
      }

      final pricingSnap = await tx.get(
        _firestore.collection('config').doc('eventPricing'),
      );
      final pricingData = pricingSnap.data();
      if (!pricingSnap.exists || pricingData == null) {
        throw StateError('No hay precio configurado para aplicar el cupón.');
      }
      final quote = EventPricingConfig.fromFirestore(
        pricingData,
      ).quoteFor((eventData['ticketCount'] as num?)?.toInt() ?? 0);
      if (quote.amount <= 0) {
        throw StateError('No hay precio configurado para aplicar el cupón.');
      }
      final discounted = quote.withDiscount(percent);
      final originalAmount = quote.amount;
      final finalAmount = discounted.amount;
      final discountAmount = originalAmount - finalAmount;
      final ownerId = (eventData['ownerId'] as String?)?.trim() ?? '';
      var resolvedOrganizer = organizerName?.trim() ?? '';
      if (ownerId.isNotEmpty) {
        final userSnap = await tx.get(
          _firestore.collection('users').doc(ownerId),
        );
        final userData = userSnap.data();
        final fromDoc = (userData?['displayName'] as String?)?.trim() ??
            (userData?['name'] as String?)?.trim() ??
            '';
        if (fromDoc.isNotEmpty) {
          resolvedOrganizer = fromDoc;
        } else if (resolvedOrganizer.isEmpty) {
          final email = (userData?['email'] as String?) ?? '';
          resolvedOrganizer = email.contains('@')
              ? email.split('@').first
              : email;
        }
      }

      tx.update(couponRef, {
        'used': true,
        'status': 'applied',
        'usedAt': FieldValue.serverTimestamp(),
        'eventId': eventId,
        'eventName': eventName,
        'organizerId': ownerId.isEmpty ? null : ownerId,
        'organizerName': resolvedOrganizer,
        'originalAmount': originalAmount,
        'discountAmount': discountAmount,
        'finalAmount': finalAmount,
      });
      tx.update(eventRef, {
        'couponCode': normalized,
        'couponPercent': percent,
        'couponSellerId': sellerId,
        'couponOriginalAmount': originalAmount,
        'couponDiscountAmount': discountAmount,
        'couponFinalAmount': finalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return Coupon(
        code: normalized,
        sellerId: sellerId,
        discountPercent: percent,
        used: true,
        eventId: eventId,
        originalAmount: originalAmount,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
      );
    });
  }
}
