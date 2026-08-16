import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/collaborator_profile_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Organizer view of one validator: access actions + tickets they validated.
class ValidatorDetailScreen extends ConsumerWidget {
  const ValidatorDetailScreen({
    super.key,
    required this.eventId,
    required this.validatorId,
  });

  final String eventId;
  final String validatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));

    if (eventAsync.isLoading ||
        collabsAsync.isLoading ||
        ticketsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || collabsAsync.hasError || ticketsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Validador')),
        body: Center(
          child: Text(
            '${eventAsync.error ?? collabsAsync.error ?? ticketsAsync.error}',
          ),
        ),
      );
    }

    Collaborator? match;
    for (final c in collabsAsync.requireValue) {
      if (c.id == validatorId) {
        match = c;
        break;
      }
    }
    if (match == null || match.role != CollaboratorRole.validator) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tickets = ticketsAsync.requireValue
        .where((t) => t.validatorId == validatorId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    String? validatedAtLabel(Ticket ticket) {
      for (var i = ticket.history.length - 1; i >= 0; i--) {
        final entry = ticket.history[i];
        if (entry.action == TicketHistoryAction.delivered) {
          return dateFormat.format(entry.at);
        }
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Validador')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CollaboratorProfileCard(
            eventId: eventId,
            collaboratorId: validatorId,
            expectedRole: CollaboratorRole.validator,
          ),
          const SizedBox(height: 16),
          Text(
            'Tickets (${tickets.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (tickets.isEmpty)
            const Text(
              'Todavía no se validaron tickets.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final ticket in tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: ticketBg(ticket),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ticket #${ticket.number}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (ticket.buyerName.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Para: ${ticket.buyerName.trim()}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (validatedAtLabel(ticket) != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Validado: ${validatedAtLabel(ticket)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: ticket.status.label,
                          tone: ticketTone(ticket),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
