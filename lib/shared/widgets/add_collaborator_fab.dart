import 'package:flutter/material.dart';

import 'bottom_system_inset.dart';

/// Shared FAB to create a collaborator (seller, coordinator, validator, collector).
class AddCollaboratorFab extends StatelessWidget {
  const AddCollaboratorFab({
    super.key,
    required this.onPressed,
    this.wrapInset = true,
  });

  final VoidCallback? onPressed;

  /// When true, lifts the FAB above the system home indicator.
  final bool wrapInset;

  static const IconData icon = Icons.person_add_alt_1_outlined;

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(icon),
      label: const Text('Agregar'),
    );
    if (!wrapInset) return fab;
    return BottomSystemInset(child: fab);
  }
}
