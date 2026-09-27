import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_product.dart';

/// Reusable product templates owned by an organizer (`users/{uid}/products`).
///
/// Choosing one copies it into the event. Later edits do not rewrite old events.
class ProductCatalogRepository {
  ProductCatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _products(String ownerId) =>
      _firestore.collection('users').doc(ownerId).collection('products');

  Stream<List<EventProduct>> watch(String ownerId) {
    return _products(ownerId).snapshots().map((snap) {
      final products = snap.docs
          .map((doc) => EventProduct.fromMap(doc.data()))
          .toList();
      products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return products;
    });
  }

  Future<void> upsertAll(String ownerId, List<EventProduct> products) async {
    if (products.isEmpty) return;
    final batch = _firestore.batch();
    for (final product in products) {
      final name = product.name.trim();
      if (name.isEmpty) continue;
      final ref = _products(ownerId).doc(_docId(name));
      batch.set(ref, {
        ...product.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  String _docId(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[/\\#?\[\]]'), '');
    if (slug.isEmpty) return 'producto';
    return slug.length > 80 ? slug.substring(0, 80) : slug;
  }
}
