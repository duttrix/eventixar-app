import 'package:cloud_firestore/cloud_firestore.dart';

/// How much money was handed over when settling a ticket with a collector.
enum TicketSettleMode {
  /// Seller remits the full ticket price.
  full,

  /// Seller remits only the organizer's profit / commission.
  profit,
}

extension TicketSettleModeX on TicketSettleMode {
  String get firestoreValue => name;

  String get label => switch (this) {
        TicketSettleMode.full => 'Ticket completo',
        TicketSettleMode.profit => 'Solo ganancia',
      };

  static TicketSettleMode fromFirestore(String? value) {
    return TicketSettleMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => TicketSettleMode.full,
    );
  }
}

/// Life-cycle status of a single ticket within an event.
enum TicketStatus {
  unassigned,
  withSeller,
  reserved,
  collected,
  settled,
  returned,
  delivered,
}

extension TicketStatusX on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.unassigned:
        return 'Sin vendedor';
      case TicketStatus.withSeller:
        return 'En poder del vendedor';
      case TicketStatus.reserved:
        return 'Reservado';
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

  /// Free for (re)assignment by organizer/coordinator.
  bool get isAssignablePool =>
      this == TicketStatus.unassigned || this == TicketStatus.returned;

  /// Can be reserved or collected by a seller (pool, assigned, or already reserved).
  bool get isSellable =>
      isAssignablePool ||
      this == TicketStatus.withSeller ||
      this == TicketStatus.reserved;

  static TicketStatus fromFirestore(String? value) {
    return TicketStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => TicketStatus.unassigned,
    );
  }
}

/// Kind of movement recorded on a ticket's history trail.
enum TicketHistoryAction {
  created,
  assigned,
  buyerSet,
  reserved,
  collected,
  settled,
  delivered,
  returnedToPool,
  returned,
  reservationCleared,
}

extension TicketHistoryActionX on TicketHistoryAction {
  String get firestoreValue => name;

  String get label => switch (this) {
    TicketHistoryAction.created => 'Ticket generado',
    TicketHistoryAction.assigned => 'Asignado a vendedor',
    TicketHistoryAction.buyerSet => 'Comprador cargado',
    TicketHistoryAction.reserved => 'Reservado',
    TicketHistoryAction.collected => 'Cobrado',
    TicketHistoryAction.settled => 'Rendido',
    TicketHistoryAction.delivered => 'Validado / entregado',
    TicketHistoryAction.returnedToPool => 'Devuelto al pool',
    TicketHistoryAction.returned => 'Marcado como devuelto',
    TicketHistoryAction.reservationCleared => 'Reserva liberada',
  };

  static TicketHistoryAction fromFirestore(String? value) {
    return TicketHistoryAction.values.firstWhere(
      (a) => a.name == value,
      orElse: () => TicketHistoryAction.created,
    );
  }
}

/// One movement in a ticket's audit trail.
class TicketHistoryEntry {
  TicketHistoryEntry({
    required this.at,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.actorId,
    this.actorRole,
    this.note,
  });

  final DateTime at;
  final TicketHistoryAction action;
  final TicketStatus? fromStatus;
  final TicketStatus? toStatus;

  /// Collaborator id or organizer uid when known.
  final String? actorId;

  /// `organizer` | `seller` | `validator` | `collector` | `coordinator`
  final String? actorRole;

  final String? note;

  String get actorRoleLabel => switch (actorRole) {
    'organizer' => 'Organizador',
    'seller' => 'Vendedor',
    'validator' => 'Validador',
    'collector' => 'Recaudador',
    'coordinator' => 'Coordinador',
    _ => actorRole ?? 'Sistema',
  };

  factory TicketHistoryEntry.fromFirestore(Map<String, dynamic> data) {
    return TicketHistoryEntry(
      at: data['at'] is Timestamp
          ? (data['at'] as Timestamp).toDate()
          : (data['at'] as DateTime? ?? DateTime.now()),
      action: TicketHistoryActionX.fromFirestore(data['action'] as String?),
      fromStatus: data['fromStatus'] == null
          ? null
          : TicketStatusX.fromFirestore(data['fromStatus'] as String?),
      toStatus: data['toStatus'] == null
          ? null
          : TicketStatusX.fromFirestore(data['toStatus'] as String?),
      actorId: data['actorId'] as String?,
      actorRole: data['actorRole'] as String?,
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'at': Timestamp.fromDate(at),
      'action': action.firestoreValue,
      if (fromStatus != null) 'fromStatus': fromStatus!.firestoreValue,
      if (toStatus != null) 'toStatus': toStatus!.firestoreValue,
      if (actorId != null) 'actorId': actorId,
      if (actorRole != null) 'actorRole': actorRole,
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
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
    this.assignedByCollaboratorId,
    this.buyerName = '',
    this.settleMode,
    this.settledAmount,
    List<TicketHistoryEntry>? history,
  }) : history = history ?? const [];

  final String id;
  final String eventId;
  final int number;
  TicketStatus status;
  String? sellerId;

  /// Validator who marked the ticket as delivered (if any).
  String? validatorId;

  /// Collector who received the money from the seller (rendición).
  String? collectorId;

  /// Coordinator who assigned this ticket to a seller (null = organizer).
  String? assignedByCollaboratorId;

  /// Who the ticket was sold / given to (filled when sharing / collecting).
  String buyerName;

  /// Whether the seller remitted full price or only profit (when settled).
  TicketSettleMode? settleMode;

  /// Amount received by the collector for this ticket (when settled).
  double? settledAmount;

  /// Chronological audit trail (append-only in Firestore).
  final List<TicketHistoryEntry> history;

  /// Amount recorded at settlement, or [fallbackFullPrice] for legacy tickets.
  double resolvedSettledAmount(double fallbackFullPrice) =>
      settledAmount ?? fallbackFullPrice;

  /// Payload encoded in the ticket QR for validators (not a buyer deeplink).
  ///
  /// Buyers receive the ticket as an image; this string is only for scanning.
  String get qrPayload => 'evx:$eventId:$id';

  factory Ticket.fromFirestore({
    required String id,
    required String eventId,
    required Map<String, dynamic> data,
  }) {
    final historyRaw = data['history'];
    final history = <TicketHistoryEntry>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(
            TicketHistoryEntry.fromFirestore(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    history.sort((a, b) => a.at.compareTo(b.at));

    final settleModeRaw = data['settleMode'] as String?;
    return Ticket(
      id: id,
      eventId: eventId,
      number: (data['number'] as num?)?.toInt() ?? 0,
      status: TicketStatusX.fromFirestore(data['status'] as String?),
      sellerId: data['sellerId'] as String?,
      validatorId: data['validatorId'] as String?,
      collectorId: data['collectorId'] as String?,
      assignedByCollaboratorId: data['assignedByCollaboratorId'] as String?,
      buyerName: (data['buyerName'] as String?) ?? '',
      settleMode: settleModeRaw == null
          ? null
          : TicketSettleModeX.fromFirestore(settleModeRaw),
      settledAmount: (data['settledAmount'] as num?)?.toDouble(),
      history: history,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'number': number,
      'status': status.firestoreValue,
      'sellerId': sellerId,
      'validatorId': validatorId,
      'collectorId': collectorId,
      'assignedByCollaboratorId': assignedByCollaboratorId,
      'buyerName': buyerName,
      if (settleMode != null) 'settleMode': settleMode!.firestoreValue,
      if (settledAmount != null) 'settledAmount': settledAmount,
      'history': history.map((e) => e.toFirestoreMap()).toList(),
    };
  }
}
