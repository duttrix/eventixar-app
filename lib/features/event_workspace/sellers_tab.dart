import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/access_share.dart';

/// Organizer roster of sellers for an event + access sharing.
class SellersTab extends ConsumerWidget {
  const SellersTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final sellers = repo.sellersForEvent(eventId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref, event.name),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Asigná rangos de tickets y compartí el acceso. El vendedor abre el link y ve sus tickets: no necesita registrarse.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (sellers.isEmpty)
            const Text('Todavía no hay vendedores.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final seller in sellers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push('/event/$eventId/sellers/${seller.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(seller.name, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                    seller.ranges.isEmpty
                                        ? 'Sin rangos · ${seller.phone}'
                                        : 'Rangos: ${seller.ranges.map((r) => r.label).join(', ')}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Compartir acceso',
                              icon: const Icon(Icons.ios_share),
                              onPressed: () => AccessShare.copy(context, seller, eventName: event.name),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          ],
                        ),
                        if (repo.ticketsForSeller(seller.id).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TicketStatusSummary(tickets: repo.ticketsForSeller(seller.id)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, String eventName) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo vendedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular (WhatsApp)'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Al crearlo vas a poder compartir un acceso. Abre el link sin registrarse.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final seller = ref.read(repositoryProvider).addCollaborator(
                      eventId: eventId,
                      role: CollaboratorRole.seller,
                      name: name,
                      phone: phoneController.text.trim(),
                    );
                Navigator.pop(dialogContext);
                AccessShare.copy(context, seller, eventName: eventName);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Crear y compartir acceso'),
          ),
        ],
      ),
    );
  }
}
