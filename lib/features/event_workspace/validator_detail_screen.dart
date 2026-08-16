import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/collaborator_access_actions.dart';
import '../../shared/widgets/section_card.dart';
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

    final event = eventAsync.requireValue;
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
    final validator = match;
    final tickets = ticketsAsync.requireValue
        .where((t) => t.validatorId == validatorId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final token = ref
            .watch(eventAccessTokensProvider(eventId))
            .valueOrNull?[validatorId] ??
        '';
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
          SectionCard(
            title: validator.name,
            trailing: IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, ref, validator),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (validator.notes.isNotEmpty) ...[
                  Text(
                    'Notas: ${validator.notes}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  tickets.isEmpty
                      ? 'Todavía no validó tickets.'
                      : '${tickets.length} ticket'
                          '${tickets.length == 1 ? '' : 's'} validado'
                          '${tickets.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                CollaboratorAccessActions(
                  collaborator: validator,
                  eventName: event.name,
                  token: token,
                  onDeleted: () {
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
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
                  color: ticketStatusBg(ticket.status),
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
                          tone: ticketStatusTone(ticket.status),
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

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Collaborator validator,
  ) {
    final nameController = TextEditingController(text: validator.name);
    final notesController = TextEditingController(text: validator.notes);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar validador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Ej. Retiro en puerta lateral',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                await saveCollaborator(
                  ref,
                  eventId: eventId,
                  collaboratorId: validator.id,
                  name: name,
                  phone: validator.phone,
                  notes: notesController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Validador actualizado.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
