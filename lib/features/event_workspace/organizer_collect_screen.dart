import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../join/collector_workbench.dart';

/// Organizer entry to the same settle UI used by collectors.
class OrganizerCollectScreen extends ConsumerWidget {
  const OrganizerCollectScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final uid = session.userUid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Tenés que iniciar sesión.')),
      );
    }

    final label = (session.displayName?.trim().isNotEmpty ?? false)
        ? session.displayName!.trim()
        : 'Organizador';

    return CollectorWorkbench(
      eventId: eventId,
      actorId: uid,
      actorLabel: label,
      actorRole: 'organizer',
      showLogout: false,
    );
  }
}
