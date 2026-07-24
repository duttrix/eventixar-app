import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import 'status_badge.dart';

/// Shared copy + actions for sharing collaborator access links.
class AccessShare {
  AccessShare._();

  static String messageFor(Collaborator person, {required String eventName}) {
    return switch (person.role) {
      CollaboratorRole.seller =>
        'Hola ${person.name}, te comparto tu acceso a los tickets de "$eventName". '
            'Abrí el link y vas a ver tus tickets. No necesitás registrarte.\n\n${person.shareUrl}',
      CollaboratorRole.validator =>
        'Hola ${person.name}, te comparto tu acceso de validador para "$eventName". '
            'Abrí el link para leer tickets (retiro o entrada). No necesitás registrarte.\n\n${person.shareUrl}',
      CollaboratorRole.collector =>
        'Hola ${person.name}, te comparto tu acceso de recaudador para "$eventName". '
            'Abrí el link para cobrar las rendiciones de los vendedores. No necesitás registrarte.\n\n${person.shareUrl}',
    };
  }

  static Future<void> copy(
    BuildContext context,
    Collaborator person, {
    required String eventName,
  }) async {
    final text = messageFor(person, eventName: eventName);
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
    TicketStatus.withSeller => AppColors.warnBg,
    TicketStatus.unassigned => AppColors.border,
  };
}

/// Compact summary chips: Cobrado / En poder / Devuelto / etc.
class TicketStatusSummary extends StatelessWidget {
  const TicketStatusSummary({super.key, required this.tickets});

  final List<Ticket> tickets;

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
      TicketStatus.withSeller,
      TicketStatus.collected,
      TicketStatus.settled,
      TicketStatus.returned,
      TicketStatus.delivered,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in order)
          if ((counts[status] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ticketStatusBg(status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${status.label}: ${counts[status]}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: switch (status) {
                    TicketStatus.collected => AppColors.successText,
                    TicketStatus.settled => AppColors.accentText,
                    TicketStatus.returned => AppColors.dangerText,
                    TicketStatus.delivered => AppColors.accentText,
                    TicketStatus.withSeller => AppColors.warnText,
                    TicketStatus.unassigned => AppColors.textSecondary,
                  },
                ),
              ),
            ),
      ],
    );
  }
}
