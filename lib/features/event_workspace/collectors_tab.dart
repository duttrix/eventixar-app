import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/access_share.dart';
import 'organizer_collect_screen.dart';

/// Organizer hub for settlement: operate yourself + optional collector roster.
class CollectorsTab extends ConsumerWidget {
  const CollectorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collectorsAsync = ref.watch(eventCollectorsProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: eventAsync.hasValue
            ? () => _showEditor(
                  context,
                  ref,
                  eventName: eventAsync.requireValue.name,
                )
            : null,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar'),
      ),
      body: collectorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (collectors) {
          final eventName = eventAsync.valueOrNull?.name ?? '';
          final tickets = ticketsAsync.valueOrNull ?? const [];
          final tokens =
              ref.watch(eventAccessTokensProvider(eventId)).valueOrNull ??
                  const <String, String>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Rendí vos mismo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acá podés elegir un vendedor, ver lo que cobró y marcar '
                      'la rendición (ticket completo o solo ganancia), o devolver '
                      'tickets al pool, sin salir de tu cuenta de organizador.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OrganizerCollectScreen(eventId: eventId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Empezar a rendir'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Delegá con un link',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'También podés crear recaudadores y compartirles un link: '
                      'abren el acceso sin registrarse y rinden desde su celular.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Recaudadores del evento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (collectors.isEmpty)
                const Text(
                  'Todavía no creaste recaudadores. Usá Agregar para sumar uno y '
                  'compartirle el link.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              else
                for (final collector in collectors)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(collector.name),
                      subtitle: Text(
                        [
                          collector.phone.isEmpty
                              ? 'Sin celular'
                              : collector.phone,
                          if (collector.notes.isNotEmpty) collector.notes,
                          '${tickets.where((t) => t.collectorId == collector.id).length} tickets rendidos',
                        ].join(' · '),
                      ),
                      onTap: () => context.push(
                        '/event/$eventId/collectors/${collector.id}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditor(
                              context,
                              ref,
                              eventName: eventName,
                              existing: collector,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Compartir acceso',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () => AccessShare.copy(
                              context,
                              collector,
                              eventName: eventName,
                              token: tokens[collector.id] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _showEditor(
    BuildContext context,
    WidgetRef ref, {
    required String eventName,
    Collaborator? existing,
  }) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Editar recaudador' : 'Nuevo recaudador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Celular (WhatsApp)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Ej. Recauda los viernes en sede',
                ),
              ),
              if (!isEdit) ...[
                const SizedBox(height: 12),
                const Text(
                  'Al crearlo vas a poder compartir un acceso. Abre el link sin registrarse.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final phone = phoneController.text.trim();
              final notes = notesController.text.trim();

              try {
                if (isEdit) {
                  await saveCollaborator(
                    ref,
                    eventId: eventId,
                    collaboratorId: existing.id,
                    name: name,
                    phone: phone,
                    notes: notes,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recaudador actualizado.')),
                  );
                  return;
                }

                final collector = await inviteCollaborator(
                  ref,
                  eventId: eventId,
                  role: CollaboratorRole.collector,
                  name: name,
                  phone: phone,
                  notes: notes,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                AccessShare.copy(
                  context,
                  collector,
                  eventName: eventName,
                  token: collector.token,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: Text(isEdit ? 'Guardar' : 'Crear y compartir acceso'),
          ),
        ],
      ),
    );
  }
}
