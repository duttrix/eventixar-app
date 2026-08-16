import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../join/validator_workbench.dart';

/// Organizer entry to the same validate UI used by validators.
class OrganizerValidateScreen extends ConsumerWidget {
  const OrganizerValidateScreen({
    super.key,
    required this.eventId,
    this.embedded = false,
  });

  final String eventId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final uid = session.userUid;
    if (uid == null) {
      final child = const Center(child: Text('Tenés que iniciar sesión.'));
      return embedded ? child : Scaffold(body: child);
    }

    final label = (session.displayName?.trim().isNotEmpty ?? false)
        ? session.displayName!.trim()
        : 'Organizador';

    return ValidatorWorkbench(
      eventId: eventId,
      actorId: uid,
      actorLabel: label,
      actorRole: 'organizer',
      showLogout: false,
      embedded: embedded,
    );
  }
}
