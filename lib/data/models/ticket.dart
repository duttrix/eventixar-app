/// Life-cycle status of a single ticket within an event.
enum TicketStatus {
  unassigned,
  withSeller,
  collected,
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
      case TicketStatus.returned:
        return 'Devuelto';
      case TicketStatus.delivered:
        return 'Validado';
    }
  }
}

class Ticket {
  Ticket({
    required this.id,
    required this.eventId,
    required this.number,
    this.status = TicketStatus.unassigned,
    this.sellerId,
  });

  final String id;
  final String eventId;
  final int number;
  TicketStatus status;
  String? sellerId;

  /// Public deeplink the buyer opens to see this ticket.
  String get shareUrl => 'https://app.eventixar.com/ticket/$id';
}
