import 'package:flutter/material.dart';

import '../../data/models/collaborator.dart';
import 'access_share.dart';
import 'regenerate_access_button.dart';

/// Standard collaborator access actions used on detail screens.
///
/// 1. Compartir acceso
/// 2. Regenerar acceso (revokes the old link without deleting the person)
class CollaboratorAccessActions extends StatelessWidget {
  const CollaboratorAccessActions({
    super.key,
    required this.collaborator,
    required this.eventName,
    required this.token,
  });

  final Collaborator collaborator;
  final String eventName;
  final String token;

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
        RegenerateAccessButton(
          collaborator: collaborator,
          eventName: eventName,
        ),
      ],
    );
  }
}
