import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import 'status_badge.dart';

/// Shared copy + actions for sharing collaborator access links.
class AccessShare {
  AccessShare._();

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
          'Acceso de ${person.name} (${person.role.label}) listo para enviar por WhatsApp.',
        ),
      ),
    );
  }
}

BadgeTone ticketStatusTone(TicketStatus status) {
  return switch (status) {
    TicketStatus.collected => BadgeTone.success,
    TicketStatus.settled => BadgeTone.success,
    TicketStatus.returned => BadgeTone.danger,
    TicketStatus.delivered => BadgeTone.info,
    TicketStatus.reserved => BadgeTone.info,
    TicketStatus.withSeller => BadgeTone.warn,
    TicketStatus.unassigned => BadgeTone.neutral,
  };
}

Color ticketStatusBg(TicketStatus status) {
  return switch (status) {
    TicketStatus.collected => AppColors.successBg,
    TicketStatus.settled => AppColors.accentBg,
    TicketStatus.returned => AppColors.dangerBg,
    TicketStatus.delivered => AppColors.accentBg,
    TicketStatus.reserved => AppColors.accentBg,
    TicketStatus.withSeller => AppColors.warnBg,
    TicketStatus.unassigned => AppColors.border,
  };
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
  });

  final List<Ticket> tickets;
  final Set<TicketStatus> selected;
  final ValueChanged<TicketStatus>? onStatusTap;

  /// When true, also shows `Sin vendedor` / `Devuelto` chips (organizer overview).
  final bool includePoolStatuses;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Text('Sin tickets asignados.', style: TextStyle(color: AppColors.textMuted));
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
    final textColor = switch (status) {
      TicketStatus.collected => AppColors.successText,
      TicketStatus.settled => AppColors.accentText,
      TicketStatus.returned => AppColors.dangerText,
      TicketStatus.delivered => AppColors.accentText,
      TicketStatus.reserved => AppColors.accentText,
      TicketStatus.withSeller => AppColors.warnText,
      TicketStatus.unassigned => AppColors.textSecondary,
    };

    return Material(
      color: ticketStatusBg(status),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            '${status.label}: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
