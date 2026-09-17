import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/phone/ar_whatsapp_phone.dart';
import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import 'collaborator_access_actions.dart';
import 'collaborator_form_dialog.dart';
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
  });

  final String eventId;
  final String collaboratorId;

  /// When set, the card only renders if the collaborator has this role.
  final CollaboratorRole? expectedRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));
    final tokenAsync = ref.watch(
      collaboratorAccessTokenProvider((
        eventId: eventId,
        collaboratorId: collaboratorId,
      )),
    );

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
    if (match == null || (expectedRole != null && match.role != expectedRole)) {
      return const SizedBox.shrink();
    }

    final collaborator = match;
    final readOnly = event.isReadOnly;
    final phoneLabel = ArWhatsAppPhone.displayFromRaw(collaborator.phone);

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collaborator.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (phoneLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        phoneLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!readOnly)
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditDialog(context, ref, collaborator),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
            ],
          ),
          if (collaborator.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              collaborator.notes,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
          if (!readOnly) ...[
            const SizedBox(height: 10),
            CollaboratorAccessActions(
              collaborator: collaborator,
              eventName: event.name,
              token: tokenAsync.valueOrNull ?? '',
              tokenLoading: tokenAsync.isLoading,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Collaborator collaborator,
  ) {
    return showCollaboratorFormDialog(
      context: context,
      ref: ref,
      eventId: eventId,
      role: collaborator.role,
      existing: collaborator,
    );
  }
}
