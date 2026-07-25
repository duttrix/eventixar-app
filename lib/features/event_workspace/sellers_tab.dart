import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/access_share.dart';

/// Organizer roster of sellers. Share access only from seller detail.
class SellersTab extends ConsumerWidget {
  const SellersTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final sellers = repo.sellersForEvent(eventId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Entrá a cada vendedor para asignar rangos y compartir el acceso.',
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
                                    [
                                      if (seller.ranges.isEmpty)
                                        'Sin rangos'
                                      else
                                        'Rangos: ${seller.ranges.map((r) => r.label).join(', ')}',
                                      if (seller.notes.isNotEmpty) seller.notes,
                                    ].join(' · '),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
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
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Celular (WhatsApp)'),
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
                'Después vas a poder asignar rangos y compartir el acceso desde su ficha.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
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
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                context.push('/event/$eventId/sellers/${seller.id}');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}