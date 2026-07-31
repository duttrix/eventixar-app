import 'package:cloud_firestore/cloud_firestore.dart';

/// Role of a collaborator invited to an event via deeplink (no account required up front).
enum CollaboratorRole { seller, validator, collector, coordinator }

extension CollaboratorRoleX on CollaboratorRole {
  String get label => switch (this) {
    CollaboratorRole.seller => 'Vendedor',
    CollaboratorRole.validator => 'Validador',
    CollaboratorRole.collector => 'Recaudador',
    CollaboratorRole.coordinator => 'Coordinador',
  };

  String get firestoreValue => name;

  static CollaboratorRole fromFirestore(String? value) {
    return CollaboratorRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => CollaboratorRole.seller,
    );
  }
}

/// HTTPS invite link shared in WhatsApp (clickable).
///
/// Canonical host: Firebase Hosting. Landing opens `eventixar://join/...`.
String collaboratorShareUrl(String token) =>
    'https://eventixar.web.app/join/$token';

String collaboratorDeeplink(String token) => 'eventixar://join/$token';

/// A seller, validator, collector or coordinator slot on an event.
class Collaborator {
  Collaborator({
    required this.id,
    required this.eventId,
    required this.role,
    required this.name,
    required this.phone,
    this.token = '',
    this.notes = '',
    this.createdByCoordinatorId,
    this.createdAt,
    this.updatedAt,
    List<TicketRange>? ranges,
  }) : ranges = ranges ?? [];

  final String id;
  final String eventId;
  final CollaboratorRole role;
  String name;
  String phone;
  String notes;

  /// Opaque token used in deeplinks: eventixar://join/{token}
  ///
  /// It is **not** stored on the collaborator document (portals can read those)
  /// but in the organizer-only `access` subcollection, so it is empty unless
  /// the repository explicitly loaded it.
  String token;

  /// When a seller was created by a coordinator portal (null = organizer).
  String? createdByCoordinatorId;

  DateTime? createdAt;
  DateTime? updatedAt;

  /// Ticket number ranges assigned to this seller (empty for other roles).
  final List<TicketRange> ranges;

  String get deeplink => collaboratorDeeplink(token);

  String get shareUrl => collaboratorShareUrl(token);

  factory Collaborator.fromFirestore({
    required String id,
    required String eventId,
    required Map<String, dynamic> data,
  }) {
    final rangesRaw = data['ranges'];
    final ranges = <TicketRange>[];
    if (rangesRaw is List) {
      for (final item in rangesRaw) {
        if (item is Map) {
          ranges.add(
            TicketRange.fromFirestore(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return Collaborator(
      id: id,
      eventId: eventId,
      role: CollaboratorRoleX.fromFirestore(data['role'] as String?),
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      notes: (data['notes'] as String?) ?? '',
      createdByCoordinatorId: data['createdByCoordinatorId'] as String?,
      createdAt: _readTimestamp(data['createdAt']),
      updatedAt: _readTimestamp(data['updatedAt']),
      ranges: ranges,
    );
  }

  Map<String, dynamic> toFirestoreMap({
    FieldValue? createdAtValue,
    FieldValue? updatedAtValue,
  }) {
    return {
      'role': role.firestoreValue,
      'name': name,
      'phone': phone,
      'notes': notes,
      'ranges': ranges.map((r) => r.toFirestoreMap()).toList(),
      if (createdByCoordinatorId != null)
        'createdByCoordinatorId': createdByCoordinatorId,
      'createdAt': ?createdAtValue,
      'updatedAt': ?updatedAtValue,
    };
  }

  static DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Inclusive ticket number range given to a seller.
class TicketRange {
  TicketRange({
    required this.id,
    required this.from,
    required this.to,
    required this.date,
    this.assignedByCollaboratorId,
  });

  final String id;
  final int from;
  final int to;
  final DateTime date;

  /// Coordinator who assigned this range (null = organizer).
  final String? assignedByCollaboratorId;

  int get count => to - from + 1;

  String get label => '$from–$to';

  factory TicketRange.fromFirestore(Map<String, dynamic> data) {
    return TicketRange(
      id: (data['id'] as String?) ?? '',
      from: (data['from'] as num?)?.toInt() ?? 0,
      to: (data['to'] as num?)?.toInt() ?? 0,
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : (data['date'] as DateTime? ?? DateTime.now()),
      assignedByCollaboratorId: data['assignedByCollaboratorId'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'date': Timestamp.fromDate(date),
      if (assignedByCollaboratorId != null)
        'assignedByCollaboratorId': assignedByCollaboratorId,
    };
  }
}
