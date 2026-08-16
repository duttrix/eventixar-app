import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/bottom_system_inset.dart';
import '../../shared/widgets/help_callout.dart';

/// Organizer roster of collectors (settlement helpers).
class CollectorsTab extends ConsumerWidget {
  const CollectorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collectorsAsync = ref.watch(eventCollectorsProvider(eventId));
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
      body: collectorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (collectors) {
          final tickets = ticketsAsync.valueOrNull ?? const <Ticket>[];
          return ListView(
            padding: listPaddingWithFab(context),
            children: [
              const HelpCallout(
                message:
                    'Los recaudadores rinden lo cobrado por los vendedores '
                    '(ticket completo o solo ganancia) y pueden devolver '
                    'tickets al pool. Abrí cada uno para compartir acceso, '
                    'editar datos o ver lo rendido.',
              ),
              const SizedBox(height: 20),
              Text(
                collectors.isEmpty
                    ? 'Recaudadores'
                    : 'Recaudadores (${collectors.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (collectors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Usá Agregar para crear uno y compartirle el acceso con un link.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                )
              else
                for (final collector in collectors)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => context.push(
                        '/event/$eventId/collectors/${collector.id}',
                      ),
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
                                    collector.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (collector.notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      collector.notes,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  CollectorTicketSummary(
                                    tickets: tickets
                                        .where(
                                          (t) => t.collectorId == collector.id,
                                        )
                                        .toList(growable: false),
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
        title: const Text('Nuevo recaudador'),
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
                  hintText: 'Ej. Recauda los viernes en sede',
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
                final collector = await inviteCollaborator(
                  ref,
                  eventId: eventId,
                  role: CollaboratorRole.collector,
                  name: name,
                  phone: '',
                  notes: notesController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                await AccessShare.share(
                  context,
                  collector,
                  eventName: eventName,
                  token: collector.token,
                );
                if (!context.mounted) return;
                context.push('/event/$eventId/collectors/${collector.id}');
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
