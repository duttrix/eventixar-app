import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import 'section_card.dart';
import 'ticket_status_style.dart';

export 'ticket_status_style.dart';

/// Shared copy + actions for sharing collaborator access links.
class AccessShare {
  AccessShare._();

  static const IconData shareIcon = Icons.ios_share;

  static String messageFor(
    Collaborator person, {
    required String eventName,
    required String token,
  }) {
    final url = collaboratorShareUrl(token);
    return switch (person.role) {
      CollaboratorRole.seller =>
        'Hola ${person.name}, te comparto tu acceso a los tickets de "$eventName". '
            'Abrí el link (con Duttrix instalada) y vas a ver tus tickets. '
            'No necesitás registrarte.\n\n$url',
      CollaboratorRole.validator =>
        'Hola ${person.name}, te comparto tu acceso de validador para "$eventName". '
            'Abrí el link (con Duttrix instalada) para leer tickets. '
            'No necesitás registrarte.\n\n$url',
      CollaboratorRole.collector =>
        'Hola ${person.name}, te comparto tu acceso de recaudador para "$eventName". '
            'Abrí el link (con Duttrix instalada) para las rendiciones. '
            'No necesitás registrarte.\n\n$url',
      CollaboratorRole.coordinator =>
        'Hola ${person.name}, te comparto tu acceso de coordinador para "$eventName". '
            'Abrí el link (con Duttrix instalada) para gestionar vendedores y '
            'asignar tickets. No necesitás registrarte.\n\n$url',
    };
  }

  static Future<void> share(
    BuildContext context,
    Collaborator person, {
    required String eventName,
    required String token,
  }) async {
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavía no se pudo leer el link de acceso.'),
        ),
      );
      return;
    }
    final text = messageFor(person, eventName: eventName, token: token);
    await Share.share(text);
  }

  static Future<void> copy(
    BuildContext context,
    Collaborator person, {
    required String eventName,
    required String token,
  }) async {
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavía no se pudo leer el link de acceso.'),
        ),
      );
      return;
    }
    final text = messageFor(person, eventName: eventName, token: token);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Acceso de ${person.name} (${person.role.label}) listo para enviar.',
        ),
      ),
    );
  }
}

/// Card with a fixed title wrapping status chips (organizer + collaborators).
class TicketStatusCard extends StatelessWidget {
  static const String title = 'Estado de los tickets';

  const TicketStatusCard({super.key, required this.child});

  /// Convenience: standard [TicketStatusSummary] chips inside the card.
  factory TicketStatusCard.summary({
    Key? key,
    required List<Ticket> tickets,
    Set<TicketStatus> selected = const {},
    ValueChanged<TicketStatus>? onStatusTap,
    bool includePoolStatuses = false,
    String emptyLabel = 'Sin tickets asignados.',
  }) {
    return TicketStatusCard(
      key: key,
      child: TicketStatusSummary(
        tickets: tickets,
        selected: selected,
        onStatusTap: onStatusTap,
        includePoolStatuses: includePoolStatuses,
        emptyLabel: emptyLabel,
      ),
    );
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(title: title, child: child);
  }
}

/// Compact summary chips: Cobrado / En poder / Devuelto / etc.
///
/// When [onStatusTap] is set, chips toggle a multi-select filter. Selected
/// chips get a stronger border so the active filter is obvious.
class TicketStatusSummary extends StatelessWidget {
  const TicketStatusSummary({
    super.key,
    required this.tickets,
    this.selected = const {},
    this.onStatusTap,
    this.includePoolStatuses = false,
    this.emptyLabel = 'Sin tickets asignados.',
  });

  final List<Ticket> tickets;
  final Set<TicketStatus> selected;
  final ValueChanged<TicketStatus>? onStatusTap;

  /// When true, also shows `Sin vendedor` / `Devuelto` chips (organizer overview).
  final bool includePoolStatuses;

  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Text(emptyLabel, style: const TextStyle(color: AppColors.textMuted));
    }

    final counts = <TicketStatus, int>{};
    for (final t in tickets) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }

    final order = [
      if (includePoolStatuses) ...[
        TicketStatus.unassigned,
        TicketStatus.returned,
      ],
      TicketStatus.withSeller,
      TicketStatus.reserved,
      TicketStatus.collected,
      TicketStatus.settled,
      TicketStatus.delivered,
      if (!includePoolStatuses) TicketStatus.returned,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in order)
          if ((counts[status] ?? 0) > 0)
            _StatusChip(
              status: status,
              count: counts[status]!,
              selected: selected.contains(status),
              onTap: onStatusTap == null ? null : () => onStatusTap!(status),
            ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final TicketStatus status;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TicketStatusPill(
      label: status.label,
      style: ticketStatusStyle(status),
      count: count,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Read-only chips for collector tickets: Validados / Rendido / Solo ganancia.
class CollectorTicketSummary extends StatelessWidget {
  const CollectorTicketSummary({super.key, required this.tickets});

  final List<Ticket> tickets;

  bool _isFullSettle(Ticket ticket) =>
      ticket.settleMode == TicketSettleMode.full ||
      (ticket.settleMode == null && ticket.status == TicketStatus.settled);

  bool _isProfitSettle(Ticket ticket) =>
      ticket.settleMode == TicketSettleMode.profit;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Text(
        'Sin tickets rendidos.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    final validatedCount =
        tickets.where((t) => t.status == TicketStatus.delivered).length;
    final fullCount = tickets.where(_isFullSettle).length;
    final profitCount = tickets.where(_isProfitSettle).length;

    if (validatedCount == 0 && fullCount == 0 && profitCount == 0) {
      return Text(
        'Tickets: ${tickets.length}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (validatedCount > 0)
          _SummaryChip(
            label: 'Validados',
            count: validatedCount,
            style: collectorFilterStyle(
              validated: true,
              fullSettle: false,
              profitSettle: false,
            ),
          ),
        if (fullCount > 0)
          _SummaryChip(
            label: 'Rendido',
            count: fullCount,
            style: collectorFilterStyle(
              validated: false,
              fullSettle: true,
              profitSettle: false,
            ),
          ),
        if (profitCount > 0)
          _SummaryChip(
            label: 'Solo ganancia',
            count: profitCount,
            style: collectorFilterStyle(
              validated: false,
              fullSettle: false,
              profitSettle: true,
            ),
          ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.style,
  });

  final String label;
  final int count;
  final TicketStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style.foreground,
        ),
      ),
    );
  }
}
