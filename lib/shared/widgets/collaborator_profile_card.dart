import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import 'collaborator_access_actions.dart';
import 'section_card.dart';

/// Shared profile card for collaborator detail screens.
///
/// Loads the collaborator by [eventId] + [collaboratorId] and shows name,
/// notes, edit dialog and access actions.
class CollaboratorProfileCard extends ConsumerWidget {
  const CollaboratorProfileCard({
    super.key,
    required this.eventId,
    required this.collaboratorId,
    this.expectedRole,
    this.onDeleted,
  });

  final String eventId;
  final String collaboratorId;

  /// When set, the card only renders if the collaborator has this role.
  final CollaboratorRole? expectedRole;

  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));
    final token = ref
            .watch(eventAccessTokensProvider(eventId))
            .valueOrNull?[collaboratorId] ??
        '';

    if (eventAsync.isLoading || collabsAsync.isLoading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (eventAsync.hasError || collabsAsync.hasError) {
      return SectionCard(
        child: Text(
          '${eventAsync.error ?? collabsAsync.error}',
          style: const TextStyle(color: AppColors.dangerText),
        ),
      );
    }

    final event = eventAsync.requireValue;
    Collaborator? match;
    for (final c in collabsAsync.requireValue) {
      if (c.id == collaboratorId) {
        match = c;
        break;
      }
    }
    if (match == null ||
        (expectedRole != null && match.role != expectedRole)) {
      return const SizedBox.shrink();
    }

    final collaborator = match;
    final readOnly = event.isReadOnly;

    return SectionCard(
      title: collaborator.name,
      trailing: readOnly
          ? null
          : IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, ref, collaborator),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (collaborator.notes.isNotEmpty) ...[
            Text(
              'Notas: ${collaborator.notes}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
          if (!readOnly)
            CollaboratorAccessActions(
              collaborator: collaborator,
              eventName: event.name,
              token: token,
              onDeleted: onDeleted ??
                  () {
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
            ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Collaborator collaborator,
  ) {
    final nameController = TextEditingController(text: collaborator.name);
    final notesController = TextEditingController(text: collaborator.notes);
    final notesHint = switch (collaborator.role) {
      CollaboratorRole.seller => 'Ej. Vende en el barrio Alberdi',
      CollaboratorRole.validator => 'Ej. Retiro en puerta lateral',
      CollaboratorRole.collector => 'Ej. Recauda los viernes en sede',
      CollaboratorRole.coordinator => 'Ej. Zona norte',
    };

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Editar ${collaborator.role.label.toLowerCase()}'),
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
                decoration: InputDecoration(
                  labelText: 'Notas',
                  hintText: notesHint,
                ),
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
                await saveCollaborator(
                  ref,
                  eventId: eventId,
                  collaboratorId: collaborator.id,
                  name: name,
                  phone: collaborator.phone,
                  notes: notesController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${collaborator.role.label} actualizado.'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
