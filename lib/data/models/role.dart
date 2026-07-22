/// Effective UI role for the current session (organizer app vs deeplink portals).
enum Role {
  organizer,
  seller,
  deliverer;

  String get label {
    switch (this) {
      case Role.organizer:
        return 'Organizador';
      case Role.seller:
        return 'Vendedor';
      case Role.deliverer:
        return 'Entregador';
    }
  }
}
