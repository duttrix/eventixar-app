/// Life-cycle status of a single ticket within an event.
enum TicketStatus {
  unassigned,
  withSeller,
  collected,
  settled,
  returned,
  delivered,
}

extension TicketStatusX on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.unassigned:
        return 'Sin asignar';
      case TicketStatus.withSeller:
        return 'En poder del vendedor';
      case TicketStatus.collected:
        return 'Cobrado';
      case TicketStatus.settled:
        return 'Rendido';
      case TicketStatus.returned:
        return 'Devuelto';
      case TicketStatus.delivered:
        return 'Validado';
    }
  }

  String get firestoreValue => name;

  static TicketStatus fromFirestore(String? value) {
    return TicketStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => TicketStatus.unassigned,
    );
  }
}

class Ticket {
  Ticket({
    required this.id,
    required this.eventId,
    required this.number,
    this.status = TicketStatus.unassigned,
    this.sellerId,
    this.validatorId,
    this.collectorId,
    this.buyerName = '',
  });

  final String id;
  final String eventId;
  final int number;
  TicketStatus status;
  String? sellerId;

  /// Validator who marked the ticket as delivered (if any).
  String? validatorId;

  /// Collector who received the money from the seller (rendición).
  String? collectorId;

  /// Who the ticket was sold / given to (filled when sharing / collecting).
  String buyerName;

  /// Public deeplink the buyer opens to see this ticket.
  String get shareUrl => 'https://app.eventixar.com/ticket/$id';

  factory Ticket.fromFirestore({
    required String id,
    required String eventId,
    required Map<String, dynamic> data,
  }) {
    return Ticket(
      id: id,
      eventId: eventId,
      number: (data['number'] as num?)?.toInt() ?? 0,
      status: TicketStatusX.fromFirestore(data['status'] as String?),
      sellerId: data['sellerId'] as String?,
      validatorId: data['validatorId'] as String?,
      collectorId: data['collectorId'] as String?,
      buyerName: (data['buyerName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'number': number,
      'status': status.firestoreValue,
      'sellerId': sellerId,
      'validatorId': validatorId,
      'collectorId': collectorId,
      'buyerName': buyerName,
    };
  }
}
