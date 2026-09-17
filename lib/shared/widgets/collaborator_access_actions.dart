import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import 'access_share.dart';
import 'app_snackbar.dart';
import 'regenerate_access_button.dart';

/// Standard collaborator access actions used on detail screens.
///
/// 1. Compartir acceso
/// 2. Regenerar acceso (revokes the old link without deleting the person)
class CollaboratorAccessActions extends ConsumerStatefulWidget {
  const CollaboratorAccessActions({
    super.key,
    required this.collaborator,
    required this.eventName,
    required this.token,
    this.tokenLoading = false,
  });

  final Collaborator collaborator;
  final String eventName;
  final String token;
  final bool tokenLoading;

  @override
  ConsumerState<CollaboratorAccessActions> createState() =>
      _CollaboratorAccessActionsState();
}

class _CollaboratorAccessActionsState
    extends ConsumerState<CollaboratorAccessActions> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      var token = widget.token;
      if (token.isEmpty) {
        token = await ensureCollaboratorAccessToken(
          ref,
          eventId: widget.collaborator.eventId,
          collaboratorId: widget.collaborator.id,
        );
      }
      if (!mounted) return;
      await AccessShare.share(
        context,
        widget.collaborator,
        eventName: widget.eventName,
        token: token,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'No se pudo compartir el acceso: $e',
        cause: e,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.tokenLoading || _sharing;
    const buttonStyle = ButtonStyle(
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: buttonStyle,
            onPressed: loading ? null : _share,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AccessShare.shareIcon, size: 20),
            label: const Text('Dar acceso'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RegenerateAccessButton(
            collaborator: widget.collaborator,
            eventName: widget.eventName,
          ),
        ),
      ],
    );
  }
}
