import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';

/// App-wide catalogs from Firestore (`config/...`).
class CatalogRepository {
  CatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _eventProducts =>
      _firestore.collection('config').doc('eventProducts');

  DocumentReference<Map<String, dynamic>> get _eventPricing =>
      _firestore.collection('config').doc('eventPricing');

  /// Live suggestions for “qué se vende” (free text always allowed).
  Stream<List<String>> watchEventProducts() {
    return _eventProducts.snapshots().map(_productsFromSnap);
  }

  Future<List<String>> getEventProducts() async {
    final snap = await _eventProducts.get();
    return _productsFromSnap(snap);
  }

  /// Live pricing table for event quotes.
  Stream<EventPricingConfig?> watchEventPricing() {
    return _eventPricing.snapshots().map(_pricingFromSnap);
  }

  Future<EventPricingConfig?> getEventPricing() async {
    final snap = await _eventPricing.get();
    return _pricingFromSnap(snap);
  }

  List<String> _productsFromSnap(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    final raw = data?['items'];
    if (raw is! List) {
      return normalizeEventProducts(const []);
    }
    return normalizeEventProducts(raw.map((e) => '$e'));
  }

  EventPricingConfig? _pricingFromSnap(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    final config = EventPricingConfig.fromFirestore(data);
    if (config.tiers.isEmpty && config.overage == null) return null;
    return config;
  }
}
