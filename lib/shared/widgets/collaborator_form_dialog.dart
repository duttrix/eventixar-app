import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import 'access_share.dart';
import 'app_snackbar.dart';
import 'busy_dialog.dart';

/// Create or edit a collaborator with the same fields everywhere:
/// name, WhatsApp, notes.
Future<Collaborator?> showCollaboratorFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String eventId,
  required CollaboratorRole role,
  Collaborator? existing,
  String? eventName,
  String? createdByCoordinatorId,
  bool shareAccess = true,
}) async {
  final values = await showDialog<_CollaboratorFormValues>(
    context: context,
    builder: (dialogContext) => _CollaboratorFormDialog(
      role: existing?.role ?? role,
      existing: existing,
    ),
  );
  if (values == null || !context.mounted) return null;

  final roleLabel = (existing?.role ?? role).label.toLowerCase();
  try {
    if (existing != null) {
      final updated = await runBusyDialog(
        context,
        message: 'Guardando...',
        work: (_) => saveCollaborator(
          ref,
          eventId: eventId,
          collaboratorId: existing.id,
          name: values.name,
          phone: values.phone,
          notes: values.notes,
        ),
      );
      if (!context.mounted) return updated;
      AppSnackBar.success(context, '${existing.role.label} actualizado.');
      return updated;
    }

    final created = await runBusyDialog(
      context,
      message: 'Creando $roleLabel...',
      work: (_) => inviteCollaborator(
        ref,
        eventId: eventId,
        role: role,
        name: values.name,
        phone: values.phone,
        notes: values.notes,
        createdByCoordinatorId: createdByCoordinatorId,
      ),
    );
    if (!context.mounted) return created;
    if (shareAccess && eventName != null && eventName.isNotEmpty) {
      await AccessShare.share(
        context,
        created,
        eventName: eventName,
        token: created.token,
      );
    }
    return created;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.error(context, '$e', cause: e);
    }
    return null;
  }
}

class _CollaboratorFormValues {
  const _CollaboratorFormValues({
    required this.name,
    required this.phone,
    required this.notes,
  });

  final String name;
  final String phone;
  final String notes;
}

class _CollaboratorFormDialog extends StatefulWidget {
  const _CollaboratorFormDialog({
    required this.role,
    this.existing,
  });

  final CollaboratorRole role;
  final Collaborator? existing;

  @override
  State<_CollaboratorFormDialog> createState() =>
      _CollaboratorFormDialogState();
}

class _CollaboratorFormDialogState extends State<_CollaboratorFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _phone = TextEditingController(
      text: (existing?.phone ?? '').replaceAll(RegExp(r'\D'), ''),
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _CollaboratorFormValues(
        name: name,
        phone: _phone.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(
        editing
            ? 'Editar ${role.label.toLowerCase()}'
            : 'Nuevo ${role.label.toLowerCase()}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Celular (WhatsApp)',
                prefixText: '+54 9 ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas',
                hintText: role.notesHint,
              ),
            ),
            if (!editing) ...[
              const SizedBox(height: 12),
              const Text(
                'El acceso se comparte con un link. No necesita crear cuenta.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Guardar' : 'Crear y compartir'),
        ),
      ],
    );
  }
}
