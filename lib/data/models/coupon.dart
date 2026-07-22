/// Life-cycle status of a single coupon within an event.
enum CouponStatus {
  unassigned,
  withSeller,
  collected,
  returned,
  delivered,
}

extension CouponStatusX on CouponStatus {
  String get label {
    switch (this) {
      case CouponStatus.unassigned:
        return 'Sin asignar';
      case CouponStatus.withSeller:
        return 'En poder del vendedor';
      case CouponStatus.collected:
        return 'Cobrado';
      case CouponStatus.returned:
        return 'Devuelto';
      case CouponStatus.delivered:
        return 'Entregado';
    }
  }
}

class Coupon {
  Coupon({
    required this.id,
    required this.eventId,
    required this.number,
    this.status = CouponStatus.unassigned,
    this.sellerId,
  });

  final String id;
  final String eventId;
  final int number;
  CouponStatus status;
  String? sellerId;
}
