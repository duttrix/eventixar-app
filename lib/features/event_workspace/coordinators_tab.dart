import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/delete_collaborator_button.dart';
import '../../shared/widgets/regenerate_access_button.dart';

/// Organizer roster of coordinators + access sharing.
///
/// A coordinator manages all sellers: create, assign ranges, share links,
/// return tickets to the pool and delete.
class CoordinatorsTab extends ConsumerWidget {
  const CoordinatorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final coordinatorsAsync = ref.watch(eventCoordinatorsProvider(eventId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: eventAsync.hasValue
            ? () => _showEditor(
                  context,
                  ref,
                  eventName: eventAsync.requireValue.name,
                )
            : null,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar'),
      ),
      body: coordinatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (coordinators) {
          final eventName = eventAsync.valueOrNull?.name ?? '';
          final tokens =
              ref.watch(eventAccessTokensProvider(eventId)).valueOrNull ??
                  const <String, String>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'El coordinador gestiona los vendedores del evento: crear, '
                'asignar rangos, compartir accesos y devolver tickets al pool. '
                'Abre el link sin necesidad de cuenta.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (coordinators.isEmpty)
                const Text(
                  'Todavía no hay coordinadores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                for (final coordinator in coordinators)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(coordinator.name),
                      subtitle: Text(
                        [
                          if (coordinator.phone.isNotEmpty) coordinator.phone,
                          if (coordinator.notes.isNotEmpty) coordinator.notes,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Compartir acceso',
                            onPressed: () => AccessShare.copy(
                              context,
                              coordinator,
                              eventName: eventName,
                              token: tokens[coordinator.id] ?? '',
                            ),
                            icon: const Icon(Icons.ios_share),
                          ),
                          RegenerateAccessButton(
                            collaborator: coordinator,
                            eventName: eventName,
                            compact: true,
                          ),
                          DeleteCollaboratorButton(
                            collaborator: coordinator,
                            compact: true,
                          ),
                        ],
                      ),
                      onTap: () => _showEditor(
                        context,
                        ref,
                        eventName: eventName,
                        existing: coordinator,
                      ),
                    ),
                  ),
            ],
          );
        },
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
        title: Text(isEdit ? 'Editar coordinador' : 'Nuevo coordinador'),
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
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Ej. Zona norte',
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final phone = phoneController.text.trim();
              final notes = notesController.text.trim();

              try {
                if (isEdit) {
                  await saveCollaborator(
                    ref,
                    eventId: eventId,
                    collaboratorId: existing.id,
                    name: name,
                    phone: phone,
                    notes: notes,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coordinador actualizado.')),
                  );
                  return;
                }

                final c = await inviteCollaborator(
                  ref,
                  eventId: eventId,
                  role: CollaboratorRole.coordinator,
                  name: name,
                  phone: phone,
                  notes: notes,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                AccessShare.copy(
                  context,
                  c,
                  eventName: eventName,
                  token: c.token,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: Text(isEdit ? 'Guardar' : 'Crear y compartir acceso'),
          ),
        ],
      ),
    );
  }
}
