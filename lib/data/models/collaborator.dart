/// Role of a collaborator invited to an event via deeplink (no account required up front).
enum CollaboratorRole { seller, validator, collector }

extension CollaboratorRoleX on CollaboratorRole {
  String get label => switch (this) {
        CollaboratorRole.seller => 'Vendedor',
        CollaboratorRole.validator => 'Validador',
        CollaboratorRole.collector => 'Recaudador',
      };
}

/// A seller, validator or collector slot on an event, accessed through a shareable deeplink token.
class Collaborator {
  Collaborator({
    required this.id,
    required this.eventId,
    required this.role,
    required this.name,
    required this.phone,
    required this.token,
    this.notes = '',
    List<TicketRange>? ranges,
  }) : ranges = ranges ?? [];

  final String id;
  final String eventId;
  final CollaboratorRole role;
  String name;
  String phone;
  String notes;

  /// Opaque token used in deeplinks: eventixar://join/{token}
  final String token;

  /// Ticket number ranges assigned to this seller (empty for validators / collectors).
  final List<TicketRange> ranges;

  String get deeplink => 'eventixar://join/$token';

  String get shareUrl => 'https://app.eventixar.com/join/$token';
}

/// Inclusive ticket number range given to a seller.
class TicketRange {
  TicketRange({
    required this.id,
    required this.from,
    required this.to,
    required this.date,
  });

  final String id;
  final int from;
  final int to;
  final DateTime date;

  int get count => to - from + 1;

  String get label => '$from–$to';
}
