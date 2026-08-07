import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/delete_collaborator_button.dart';
import '../../shared/widgets/regenerate_access_button.dart';
import 'organizer_validate_screen.dart';

/// Organizer hub for validation: operate yourself + optional validator roster.
///
/// Validation closes the ticket cycle at product pickup or event entrance.
class ValidatorsTab extends ConsumerWidget {
  const ValidatorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final validatorsAsync = ref.watch(eventValidatorsProvider(eventId));

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
      body: validatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (validators) {
          final eventName = eventAsync.valueOrNull?.name ?? '';
          final tokens =
              ref.watch(eventAccessTokensProvider(eventId)).valueOrNull ??
                  const <String, String>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Validá tickets vos mismo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acá podés escanear o buscar un ticket y marcarlo como '
                      'validado en el retiro o en la entrada del evento, '
                      'sin salir de tu cuenta de organizador.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OrganizerValidateScreen(eventId: eventId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('Empezar a validar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Delegá con un link',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'También podés crear validadores y compartirles un link: '
                      'abren el acceso sin registrarse y validan desde su celular.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Validadores del evento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (validators.isEmpty)
                const Text(
                  'Todavía no creaste validadores. Usá Agregar para sumar uno y '
                  'compartirle el link.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              else
                for (final validator in validators)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(validator.name),
                      subtitle: Text(
                        [
                          if (validator.phone.isNotEmpty) validator.phone,
                          if (validator.notes.isNotEmpty) validator.notes,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Compartir acceso',
                            onPressed: () => AccessShare.copy(
                              context,
                              validator,
                              eventName: eventName,
                              token: tokens[validator.id] ?? '',
                            ),
                            icon: const Icon(Icons.ios_share),
                          ),
                          RegenerateAccessButton(
                            collaborator: validator,
                            eventName: eventName,
                            compact: true,
                          ),
                          DeleteCollaboratorButton(
                            collaborator: validator,
                            compact: true,
                          ),
                        ],
                      ),
                      onTap: () => _showEditor(
                        context,
                        ref,
                        eventName: eventName,
                        existing: validator,
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
        title: Text(isEdit ? 'Editar validador' : 'Nuevo validador'),
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
                decoration:
                    const InputDecoration(labelText: 'Celular (WhatsApp)'),
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
                    const SnackBar(content: Text('Validador actualizado.')),
                  );
                  return;
                }

                final v = await inviteCollaborator(
                  ref,
                  eventId: eventId,
                  role: CollaboratorRole.validator,
                  name: name,
                  phone: phone,
                  notes: notes,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                AccessShare.copy(
                  context,
                  v,
                  eventName: eventName,
                  token: v.token,
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
