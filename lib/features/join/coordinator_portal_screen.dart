import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/busy_dialog.dart';
import '../../shared/widgets/event_details_card.dart';

/// Coordinator portal: manage all sellers for an event (no organizer account).
class CoordinatorPortalScreen extends ConsumerWidget {
  const CoordinatorPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinatorAsync = ref.watch(collaboratorByTokenProvider(token));
    if (coordinatorAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final coordinator = coordinatorAsync.valueOrNull;
    if (coordinator == null ||
        coordinator.role != CollaboratorRole.coordinator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso inválido')),
        body: const Center(
          child: Text('Este link de coordinador no es válido.'),
        ),
      );
    }

    final eventId = coordinator.eventId;
    final eventAsync = ref.watch(eventProvider(eventId));
    final sellersAsync = ref.watch(eventSellersProvider(eventId));
    final event = eventAsync.valueOrNull;
    if (eventAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (event == null || event.isReadOnly) {
      final session = ref.read(sessionProvider);
      if (session.collaboratorToken != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sessionProvider.notifier).logout();
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Evento finalizado')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Este evento ya finalizó.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final eventName = event.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(coordinator.name),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSeller(
          context,
          ref,
          eventId: eventId,
          coordinatorId: coordinator.id,
          eventName: eventName,
          token: token,
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar vendedor'),
      ),
      body: sellersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (sellers) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              EventDetailsCard(event: event),
              const SizedBox(height: 16),
              Text(
                'Podés crear vendedores, asignar tickets, compartir accesos y '
                'devolver tickets al pool.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                sellers.isEmpty
                    ? 'Vendedores'
                    : 'Vendedores (${sellers.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (sellers.isEmpty)
                const Text(
                  'Todavía no hay vendedores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                for (final seller in sellers)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(seller.name),
                      subtitle: seller.notes.isEmpty
                          ? null
                          : Text(seller.notes),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                      onTap: () => context.push(
                        '/coordinator/$token/sellers/${seller.id}',
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSeller(
    BuildContext context,
    WidgetRef ref, {
    required String eventId,
    required String coordinatorId,
    required String eventName,
    required String token,
  }) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo vendedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final phone = phoneController.text.trim();
              final notes = notesController.text.trim();
              Navigator.pop(dialogContext);
              try {
                final seller = await runBusyDialog(
                  context,
                  message: 'Creando vendedor...',
                  work: (_) => inviteCollaborator(
                    ref,
                    eventId: eventId,
                    role: CollaboratorRole.seller,
                    name: name,
                    phone: phone,
                    notes: notes,
                    createdByCoordinatorId: coordinatorId,
                  ),
                );
                if (!context.mounted) return;
                await AccessShare.copy(
                  context,
                  seller,
                  eventName: eventName,
                  token: seller.token,
                );
                if (!context.mounted) return;
                context.push('/coordinator/$token/sellers/${seller.id}');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Crear y compartir'),
          ),
        ],
      ),
    );
  }
}
