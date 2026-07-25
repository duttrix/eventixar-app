import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import 'access_share.dart';

/// Revokes a collaborator's invite link and issues a new one.
///
/// The previous link stops working immediately, which is the way to cut access
/// for someone who left the team or lost their phone.
class RegenerateAccessButton extends ConsumerStatefulWidget {
  const RegenerateAccessButton({
    super.key,
    required this.collaborator,
    required this.eventName,
    this.compact = false,
  });

  final Collaborator collaborator;
  final String eventName;

  /// Renders as an icon button instead of a full-width text button.
  final bool compact;

  @override
  ConsumerState<RegenerateAccessButton> createState() =>
      _RegenerateAccessButtonState();
}

class _RegenerateAccessButtonState
    extends ConsumerState<RegenerateAccessButton> {
  bool _busy = false;

  Future<void> _regenerate() async {
    final person = widget.collaborator;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerar acceso'),
        content: Text(
          'El link actual de ${person.name} va a dejar de funcionar y se '
          'cierra su sesión en el dispositivo. Vas a tener que compartirle '
          'el link nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await regenerateCollaboratorToken(
        ref,
        eventId: person.eventId,
        collaboratorId: person.id,
      );
      if (!mounted) return;
      await AccessShare.copy(
        context,
        updated,
        eventName: widget.eventName,
        token: updated.token,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo regenerar el acceso: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        tooltip: 'Regenerar acceso',
        onPressed: _busy ? null : _regenerate,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.link_off),
      );
    }

    return TextButton.icon(
      onPressed: _busy ? null : _regenerate,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.link_off, size: 18),
      label: const Text('Regenerar acceso'),
    );
  }
}
