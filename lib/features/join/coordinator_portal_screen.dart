import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';

/// Coordinator portal: manage all sellers for an event (no organizer account).
class CoordinatorPortalScreen extends ConsumerWidget {
  const CoordinatorPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinatorAsync = ref.watch(collaboratorByTokenProvider(token));
    if (coordinatorAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final coordinator = coordinatorAsync.valueOrNull;
    if (coordinator == null ||
        coordinator.role != CollaboratorRole.coordinator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso inválido')),
        body: const Center(
          child: Text('Este link de coordinador no es válido.'),
        ),
      );
    }

    final eventId = coordinator.eventId;
    final eventAsync = ref.watch(eventProvider(eventId));
    final sellersAsync = ref.watch(eventSellersProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));
    final eventName = eventAsync.valueOrNull?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(coordinator.name),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSeller(
          context,
          ref,
          eventId: eventId,
          coordinatorId: coordinator.id,
          eventName: eventName,
          token: token,
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar vendedor'),
      ),
      body: sellersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (sellers) {
          final tickets = ticketsAsync.valueOrNull ?? const <Ticket>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                eventName.isEmpty
                    ? 'Gestioná los vendedores del evento.'
                    : 'Evento: $eventName',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Podés crear vendedores, asignar rangos, compartir accesos y '
                'devolver tickets al pool.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (sellers.isEmpty)
                const Text(
                  'Todavía no hay vendedores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                for (final seller in sellers)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => context.push(
                        '/coordinator/$token/sellers/${seller.id}',
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        seller.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (seller.ranges.isEmpty)
                                            'Sin rangos'
                                          else
                                            'Rangos: ${seller.ranges.map((r) => r.label).join(', ')}',
                                          if (seller.notes.isNotEmpty)
                                            seller.notes,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            Builder(
                              builder: (context) {
                                final sellerTickets = tickets
                                    .where((t) => t.sellerId == seller.id)
                                    .toList();
                                if (sellerTickets.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: TicketStatusSummary(
                                    tickets: sellerTickets,
                                  ),
                                );
                              },
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

  void _showAddSeller(
    BuildContext context,
    WidgetRef ref, {
    required String eventId,
    required String coordinatorId,
    required String eventName,
    required String token,
  }) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
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
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
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
                  phone: phoneController.text.trim(),
                  notes: notesController.text.trim(),
                  createdByCoordinatorId: coordinatorId,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                await AccessShare.copy(
                  context,
                  seller,
                  eventName: eventName,
                  token: seller.token,
                );
                if (!context.mounted) return;
                context.push('/coordinator/$token/sellers/${seller.id}');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: const Text('Crear y compartir'),
          ),
        ],
      ),
    );
  }
}
