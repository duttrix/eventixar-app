import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../shared/widgets/add_collaborator_fab.dart';
import '../../shared/widgets/collaborator_form_dialog.dart';
import '../../shared/widgets/event_details_card.dart';
import '../../shared/widgets/logout_icon_button.dart';

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
        actions: const [LogoutIconButton()],
      ),
      floatingActionButton: AddCollaboratorFab(
        onPressed: () => _createSeller(
          context,
          ref,
          eventId: eventId,
          coordinatorId: coordinator.id,
          eventName: eventName,
          token: token,
        ),
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

  Future<void> _createSeller(
    BuildContext context,
    WidgetRef ref, {
    required String eventId,
    required String coordinatorId,
    required String eventName,
    required String token,
  }) async {
    final seller = await showCollaboratorFormDialog(
      context: context,
      ref: ref,
      eventId: eventId,
      role: CollaboratorRole.seller,
      eventName: eventName,
      createdByCoordinatorId: coordinatorId,
    );
    if (seller == null || !context.mounted) return;
    context.push('/coordinator/$token/sellers/${seller.id}');
  }
}
