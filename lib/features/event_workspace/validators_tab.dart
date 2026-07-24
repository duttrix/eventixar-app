import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/access_share.dart';

/// Organizer roster of validators + access sharing.
///
/// A validator closes the ticket/card cycle: at product pickup or at an
/// event entrance (wedding, bingo, dinner, etc.).
class ValidatorsTab extends ConsumerWidget {
  const ValidatorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final validators = repo.validatorsForEvent(eventId);

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
            'Cada validador recibe un acceso para leer el ticket o la tarjeta: en el retiro del producto o en la entrada del evento. Abre el link sin necesidad de cuenta.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (validators.isEmpty)
            const Text('Todavía no hay validadores.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final v in validators)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(v.name),
                  subtitle: Text(
                    [
                      v.phone.isEmpty ? 'Sin celular' : v.phone,
                      if (v.notes.isNotEmpty) v.notes,
                    ].join(' · '),
                  ),
                  onTap: () => _showEditor(context, ref, eventName: event.name, existing: v),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditor(context, ref, eventName: event.name, existing: v),
                      ),
                      IconButton(
                        tooltip: 'Compartir acceso',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => AccessShare.copy(context, v, eventName: event.name),
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
        title: Text(isEdit ? 'Editar validador' : 'Nuevo validador'),
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
                  hintText: 'Ej. Retiro en puerta lateral',
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
                  const SnackBar(content: Text('Validador actualizado.')),
                );
                return;
              }

              final v = repo.addCollaborator(
                eventId: eventId,
                role: CollaboratorRole.validator,
                name: name,
                phone: phone,
                notes: notes,
              );
              Navigator.pop(dialogContext);
              AccessShare.copy(context, v, eventName: eventName);
            },
            child: Text(isEdit ? 'Guardar' : 'Crear y compartir acceso'),
          ),
        ],
      ),
    );
  }
}
