/// Effective UI role for the current session (organizer app vs deeplink portals).
enum Role {
  organizer,
  seller,
  validator;

  String get label {
    switch (this) {
      case Role.organizer:
        return 'Organizador';
      case Role.seller:
        return 'Vendedor';
      case Role.validator:
        return 'Validador';
    }
  }
}
