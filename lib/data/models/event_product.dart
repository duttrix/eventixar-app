/// How a product is sold. [piecesPerSale] expands dozens into units in reports.
enum ProductUnit {
  unit,
  dozen,
  halfDozen,
  pack,
  kg,
  liter,
  portion,
  card,
}

extension ProductUnitX on ProductUnit {
  String get firestoreValue => name;

  String get label => switch (this) {
        ProductUnit.unit => 'Unidad',
        ProductUnit.dozen => 'Docena',
        ProductUnit.halfDozen => '1/2 docena',
        ProductUnit.pack => 'Paquete',
        ProductUnit.kg => 'Kg',
        ProductUnit.liter => 'Litro',
        ProductUnit.portion => 'Porción',
        ProductUnit.card => 'Tarjeta',
      };

  String get shortLabel => switch (this) {
        ProductUnit.unit => 'u.',
        ProductUnit.dozen => 'doc.',
        ProductUnit.halfDozen => '1/2 doc.',
        ProductUnit.pack => 'paq.',
        ProductUnit.kg => 'kg',
        ProductUnit.liter => 'l',
        ProductUnit.portion => 'porc.',
        ProductUnit.card => 'tarj.',
      };

  /// Units to prepare for one ticket. Only dozens expand.
  int get piecesPerSale => switch (this) {
        ProductUnit.dozen => 12,
        ProductUnit.halfDozen => 6,
        _ => 1,
      };

  static ProductUnit fromFirestore(String? value) {
    return ProductUnit.values.firstWhere(
      (unit) => unit.name == value,
      orElse: () => ProductUnit.unit,
    );
  }
}

int _idSeq = 0;

String newProductId() =>
    'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idSeq++}';

String newVariantId() =>
    'v${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idSeq++}';

/// Flavor or priced option inside a product.
///
/// [quota] is how many tickets of this option are generated.
class EventProductVariant {
  const EventProductVariant({
    required this.id,
    required this.name,
    this.price = 0,
    this.profit = 0,
    this.quota = 0,
  });

  final String id;
  final String name;
  final double price;
  final double profit;
  final int quota;

  EventProductVariant copyWith({
    String? id,
    String? name,
    double? price,
    double? profit,
    int? quota,
  }) {
    return EventProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      profit: profit ?? this.profit,
      quota: quota ?? this.quota,
    );
  }

  factory EventProductVariant.fromMap(Map<String, dynamic> data) {
    final id = (data['id'] as String?)?.trim();
    return EventProductVariant(
      id: (id == null || id.isEmpty) ? newVariantId() : id,
      name: (data['name'] as String?)?.trim() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      profit: (data['profit'] as num?)?.toDouble() ?? 0,
      quota: (data['quota'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'profit': profit,
      'quota': quota,
    };
  }
}

/// One page of the ticket list: a product, or one variant of a product.
class TicketListSlice {
  const TicketListSlice({required this.product, this.variant});

  final EventProduct product;
  final EventProductVariant? variant;

  int get count => variant?.quota ?? product.ticketCount;

  String title(int productCount) {
    final variantName = variant?.name.trim() ?? '';
    if (variant == null || variantName.isEmpty) {
      final name = product.name.trim();
      return name.isEmpty ? 'Producto' : name;
    }
    if (productCount <= 1) return variantName;
    final productName = product.name.trim();
    final prefix = productName.isEmpty ? 'Producto' : productName;
    return '$prefix · $variantName';
  }
}

/// One thing sold in an event.
///
/// [ticketCount] is the number of tickets. When [variants] is not empty,
/// that total is the sum of each variant's [EventProductVariant.quota].
class EventProduct {
  const EventProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceOnVariant,
    required this.price,
    required this.profit,
    required this.ticketCount,
    required this.variants,
  });

  final String id;
  final String name;
  final ProductUnit unit;
  final bool priceOnVariant;
  final double price;
  final double profit;
  final int ticketCount;
  final List<EventProductVariant> variants;

  EventProductVariant? variantById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final variant in variants) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  String get priceSummary {
    if (priceOnVariant) return 'Precio según opción';
    final priceLabel = '\$${price.toStringAsFixed(0)}';
    if (profit <= 0) return priceLabel;
    return '$priceLabel · ganancia \$${profit.toStringAsFixed(0)}';
  }

  EventProduct copyWith({
    String? id,
    String? name,
    ProductUnit? unit,
    bool? priceOnVariant,
    double? price,
    double? profit,
    int? ticketCount,
    List<EventProductVariant>? variants,
  }) {
    return EventProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      priceOnVariant: priceOnVariant ?? this.priceOnVariant,
      price: price ?? this.price,
      profit: profit ?? this.profit,
      ticketCount: ticketCount ?? this.ticketCount,
      variants: variants ?? this.variants,
    );
  }

  /// Fresh ids so a copied event does not share ticket document ids.
  EventProduct cloneForNewEvent() {
    return EventProduct(
      id: newProductId(),
      name: name,
      unit: unit,
      priceOnVariant: priceOnVariant,
      price: price,
      profit: profit,
      ticketCount: ticketCount,
      variants: [
        for (final variant in variants)
          EventProductVariant(
            id: newVariantId(),
            name: variant.name,
            price: variant.price,
            profit: variant.profit,
            quota: variant.quota,
          ),
      ],
    );
  }

  factory EventProduct.legacy({
    required String name,
    required double price,
    required double profit,
    required int ticketCount,
  }) {
    return EventProduct(
      id: 'legacy',
      name: name,
      unit: ProductUnit.unit,
      priceOnVariant: false,
      price: price,
      profit: profit,
      ticketCount: ticketCount,
      variants: const [],
    );
  }

  factory EventProduct.fromMap(Map<String, dynamic> data) {
    final id = (data['id'] as String?)?.trim();
    final rawVariants = data['variants'];
    final variants = <EventProductVariant>[];
    if (rawVariants is List) {
      for (final item in rawVariants) {
        if (item is Map) {
          variants.add(
            EventProductVariant.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return EventProduct(
      id: (id == null || id.isEmpty) ? newProductId() : id,
      name: (data['name'] as String?)?.trim() ?? '',
      unit: ProductUnitX.fromFirestore(data['unit'] as String?),
      priceOnVariant: data['priceOnVariant'] == true,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      profit: (data['profit'] as num?)?.toDouble() ?? 0,
      ticketCount: (data['ticketCount'] as num?)?.toInt() ?? 0,
      variants: variants,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit.firestoreValue,
      'priceOnVariant': priceOnVariant,
      'price': price,
      'profit': profit,
      'ticketCount': ticketCount,
      'variants': variants.map((variant) => variant.toMap()).toList(),
    };
  }

  static List<EventProduct> listFromFirestore(Object? raw) {
    if (raw is! List) return const [];
    final products = <EventProduct>[];
    for (final item in raw) {
      if (item is Map) {
        products.add(EventProduct.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    return products;
  }
}

/// Flat fields kept on the event so billing and older screens keep working.
class ProductPricingSummary {
  const ProductPricingSummary({
    required this.label,
    required this.price,
    required this.profit,
    required this.ticketCount,
  });

  final String label;
  final double price;
  final double profit;
  final int ticketCount;

  static ProductPricingSummary fromProducts(List<EventProduct> products) {
    final label = products
        .map((product) => product.name.trim())
        .where((name) => name.isNotEmpty)
        .join(' · ');
    final ticketCount = products.fold<int>(
      0,
      (sum, product) => sum + product.ticketCount,
    );
    final only = products.length == 1 ? products.first : null;
    final singlePrice = only != null && !only.priceOnVariant;
    return ProductPricingSummary(
      label: label,
      price: singlePrice ? only.price : 0,
      profit: singlePrice ? only.profit : 0,
      ticketCount: ticketCount,
    );
  }
}
