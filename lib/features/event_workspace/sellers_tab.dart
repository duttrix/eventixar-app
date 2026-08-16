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

/// Organizer roster of sellers: create, open detail, share access.
class SellersTab extends ConsumerWidget {
  const SellersTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellersAsync = ref.watch(eventSellersProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));
    final eventAsync = ref.watch(eventProvider(eventId));
    final readOnly = eventAsync.valueOrNull?.isReadOnly ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: readOnly
          ? null
          : BottomSystemInset(
              child: FloatingActionButton.extended(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Agregar'),
              ),
            ),
      body: sellersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (sellers) {
          final tickets = ticketsAsync.valueOrNull ?? const <Ticket>[];
          return ListView(
            padding: listPaddingWithFab(context),
            children: [
              const HelpCallout(
                message:
                    'Los vendedores reciben tickets, los reservan o '
                    'cobran y los comparten al comprador desde el celular, sin '
                    'crear cuenta. Abrí cada uno para asignar tickets, compartir '
                    'acceso o editar sus datos.',
              ),
              const SizedBox(height: 20),
              Text(
                sellers.isEmpty
                    ? 'Vendedores'
                    : 'Vendedores (${sellers.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (sellers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    readOnly
                        ? 'No se crearon vendedores para este evento.'
                        : 'Usá Agregar para crear un vendedor. Después vas a poder '
                            'asignarle tickets y compartirle el acceso.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                )
              else
                for (final seller in sellers)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => context.push(
                        '/event/$eventId/sellers/${seller.id}',
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
                                    seller.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (seller.notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      seller.notes,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  TicketStatusSummary(
                                    tickets: tickets
                                        .where((t) => t.sellerId == seller.id)
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo vendedor'),
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
                  hintText: 'Ej. Vende en el barrio Alberdi',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Después vas a poder asignar tickets y compartir el acceso desde su ficha.',
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
                final seller = await inviteCollaborator(
                  ref,
                  eventId: eventId,
                  role: CollaboratorRole.seller,
                  name: name,
                  phone: '',
                  notes: notesController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                context.push('/event/$eventId/sellers/${seller.id}');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
