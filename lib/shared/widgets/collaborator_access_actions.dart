import 'package:flutter/material.dart';

import '../../data/models/collaborator.dart';
import 'access_share.dart';
import 'delete_collaborator_button.dart';
import 'regenerate_access_button.dart';

/// Standard collaborator access actions used on detail screens.
///
/// Order matches the seller detail layout:
/// 1. Compartir acceso (primary)
/// 2. Regenerar | Eliminar (side by side)
class CollaboratorAccessActions extends StatelessWidget {
  const CollaboratorAccessActions({
    super.key,
    required this.collaborator,
    required this.eventName,
    required this.token,
    this.onDeleted,
  });

  final Collaborator collaborator;
  final String eventName;
  final String token;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => AccessShare.share(
            context,
            collaborator,
            eventName: eventName,
            token: token,
          ),
          icon: const Icon(AccessShare.shareIcon),
          label: const Text('Compartir acceso'),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: RegenerateAccessButton(
                collaborator: collaborator,
                eventName: eventName,
              ),
            ),
            Expanded(
              child: DeleteCollaboratorButton(
                collaborator: collaborator,
                onDeleted: onDeleted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
