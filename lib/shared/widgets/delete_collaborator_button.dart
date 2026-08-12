import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';

/// Removes a collaborator after confirmation.
///
/// Sellers: unsold tickets (`withSeller` / `reserved`) go back to the pool first.
class DeleteCollaboratorButton extends ConsumerStatefulWidget {
  const DeleteCollaboratorButton({
    super.key,
    required this.collaborator,
    this.compact = false,
    this.onDeleted,
  });

  final Collaborator collaborator;
  final bool compact;

  /// Called after a successful delete (e.g. pop the detail screen).
  final VoidCallback? onDeleted;

  @override
  ConsumerState<DeleteCollaboratorButton> createState() =>
      _DeleteCollaboratorButtonState();
}

class _DeleteCollaboratorButtonState
    extends ConsumerState<DeleteCollaboratorButton> {
  bool _busy = false;

  String get _roleLabel => widget.collaborator.role.label;

  Future<void> _delete() async {
    final person = widget.collaborator;
    final isSeller = person.role == CollaboratorRole.seller;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Eliminar $_roleLabel'),
        content: Text(
          isSeller
              ? 'Vas a eliminar a ${person.name}. Los tickets sin vender '
                  'vuelven al pool. Los ya cobrados se mantienen. '
                  'Su link deja de funcionar.'
              : 'Vas a eliminar a ${person.name}. Su link deja de funcionar '
                  'de inmediato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await deleteCollaboratorAction(
        ref,
        eventId: person.eventId,
        collaborator: person,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${person.name} eliminado.')),
      );
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    if (widget.compact) {
      return IconButton(
        tooltip: 'Eliminar',
        onPressed: _busy ? null : _delete,
        icon: _busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: errorColor,
                ),
              )
            : Icon(Icons.delete_outline, color: errorColor),
      );
    }

    return TextButton.icon(
      onPressed: _busy ? null : _delete,
      style: TextButton.styleFrom(foregroundColor: errorColor),
      icon: _busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: errorColor,
              ),
            )
          : const Icon(Icons.delete_outline, size: 18),
      label: const Text('Eliminar'),
    );
  }
}
