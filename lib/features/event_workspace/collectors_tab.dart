import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/access_share.dart';

/// Organizer roster of collectors (recaudadores) + access sharing.
class CollectorsTab extends ConsumerWidget {
  const CollectorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final collectors = repo.collectorsForEvent(eventId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref, eventName: event.name),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'El recaudador rinde lo que el vendedor ya cobró. Cada uno recibe un acceso '
            'para ver a todos los vendedores y marcar la rendición. Abre el link sin cuenta.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (collectors.isEmpty)
            const Text('Todavía no hay recaudadores.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final collector in collectors)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(collector.name),
                  subtitle: Text(
                    [
                      collector.phone.isEmpty ? 'Sin celular' : collector.phone,
                      if (collector.notes.isNotEmpty) collector.notes,
                      '${repo.ticketsSettledBy(collector.id).length} tickets rendidos',
                    ].join(' · '),
                  ),
                  onTap: () => context.push(
                    '/event/$eventId/collectors/${collector.id}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showEditor(context, ref, eventName: event.name, existing: collector),
                      ),
                      IconButton(
                        tooltip: 'Compartir acceso',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => AccessShare.copy(context, collector, eventName: event.name),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _showEditor(
    BuildContext context,
    WidgetRef ref, {
    required String eventName,
    Collaborator? existing,
  }) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Editar recaudador' : 'Nuevo recaudador'),
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
                  hintText: 'Ej. Recauda los viernes en sede',
                ),
              ),
              if (!isEdit) ...[
                const SizedBox(height: 12),
                const Text(
                  'Al crearlo vas a poder compartir un acceso. Abre el link sin registrarse.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final phone = phoneController.text.trim();
              final notes = notesController.text.trim();
              final repo = ref.read(repositoryProvider);

              if (isEdit) {
                repo.updateCollaborator(existing.id, name: name, phone: phone, notes: notes);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recaudador actualizado.')),
                );
                return;
              }

              final collector = repo.addCollaborator(
                eventId: eventId,
                role: CollaboratorRole.collector,
                name: name,
                phone: phone,
                notes: notes,
              );
              Navigator.pop(dialogContext);
              AccessShare.copy(context, collector, eventName: eventName);
            },
            child: Text(isEdit ? 'Guardar' : 'Crear y compartir acceso'),
          ),
        ],
      ),
    );
  }
}
