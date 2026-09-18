import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_providers.dart';

/// AppBar action that signs out (organizer or collaborator) and goes to login.
class LogoutIconButton extends ConsumerWidget {
  const LogoutIconButton({super.key});

  static const IconData icon = Icons.logout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Cerrar sesión',
      onPressed: () async {
        await ref.read(sessionProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
      icon: const Icon(icon),
    );
  }
}
