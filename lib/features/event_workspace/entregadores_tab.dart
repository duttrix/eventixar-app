import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/mock/providers.dart';

/// Organizer roster of deliverers + deeplink sharing.
class EntregadoresTab extends ConsumerWidget {
  const EntregadoresTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final deliverers = repo.deliverersForEvent(eventId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: deliverers.length >= event.deliverersCount
            ? null
            : () => _showAddDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text('Agregar (${deliverers.length}/${event.deliverersCount})'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Cada entregador recibe un link para escanear cupones en el retiro. No necesita cuenta.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (deliverers.isEmpty)
            const Text('Todavía no hay entregadores.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final d in deliverers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(d.name),
                  subtitle: Text(d.phone),
                  trailing: IconButton(
                    tooltip: 'Copiar deeplink',
                    icon: const Icon(Icons.link),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: d.shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Link de ${d.name} copiado.')),
                      );
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo entregador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular (WhatsApp)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final d = ref.read(repositoryProvider).addCollaborator(
                      eventId: eventId,
                      role: CollaboratorRole.deliverer,
                      name: name,
                      phone: phoneController.text.trim(),
                    );
                Navigator.pop(dialogContext);
                Clipboard.setData(ClipboardData(text: d.shareUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Entregador creado. Link copiado.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Crear y copiar link'),
          ),
        ],
      ),
    );
  }
}
