import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/bottom_system_inset.dart';
import '../../shared/widgets/help_callout.dart';
import 'validator_detail_screen.dart';

/// Organizer roster of validators.
///
/// Validation closes the ticket cycle at product pickup or event entrance.
class ValidatorsTab extends ConsumerWidget {
  const ValidatorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final validatorsAsync = ref.watch(eventValidatorsProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: BottomSystemInset(
        child: FloatingActionButton.extended(
          onPressed: eventAsync.hasValue
              ? () => _showCreateDialog(
                    context,
                    ref,
                    eventName: eventAsync.requireValue.name,
                  )
              : null,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Agregar'),
        ),
      ),
      body: validatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (validators) {
          final tickets = ticketsAsync.valueOrNull ?? const <Ticket>[];
          return ListView(
            padding: listPaddingWithFab(context),
            children: [
              const HelpCallout(
                message:
                    'Los validadores escanean o buscan el QR del ticket y lo '
                    'marcan como validado en el retiro o en la entrada, sin '
                    'crear cuenta. Abrí cada uno para compartir acceso, editar '
                    'datos o ver lo que ya validó.',
              ),
              const SizedBox(height: 20),
              Text(
                validators.isEmpty
                    ? 'Validadores'
                    : 'Validadores (${validators.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (validators.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Usá Agregar para crear un validador y compartirle el link. '
                    'Abre el acceso sin registrarse.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                )
              else
                for (final validator in validators)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ValidatorDetailScreen(
                              eventId: eventId,
                              validatorId: validator.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    validator.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (validator.notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      validator.notes,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  TicketStatusSummary(
                                    tickets: tickets
                                        .where(
                                          (t) => t.validatorId == validator.id,
                                        )
                                        .toList(growable: false),
                                    emptyLabel: 'Sin tickets validados.',
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    required String eventName,
  }) {
    final nameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo validador'),
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
              const SizedBox(height: 12),
              const Text(
                'Al crearlo vas a poder compartir un acceso. Abre el link sin registrarse.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                final v = await inviteCollaborator(
                  ref,
                  eventId: eventId,
                  role: CollaboratorRole.validator,
                  name: name,
                  phone: '',
                  notes: notesController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                await AccessShare.share(
                  context,
                  v,
                  eventName: eventName,
                  token: v.token,
                );
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ValidatorDetailScreen(
                      eventId: eventId,
                      validatorId: v.id,
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: const Text('Crear y compartir acceso'),
          ),
        ],
      ),
    );
  }
}
