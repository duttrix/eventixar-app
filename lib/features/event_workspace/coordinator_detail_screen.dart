import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/bottom_system_inset.dart';
import '../../shared/widgets/collaborator_profile_card.dart';
import 'seller_detail_screen.dart';

/// Organizer view of one coordinator: access actions + assigned sellers.
class CoordinatorDetailScreen extends ConsumerWidget {
  const CoordinatorDetailScreen({
    super.key,
    required this.eventId,
    required this.coordinatorId,
  });

  final String eventId;
  final String coordinatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));

    if (eventAsync.isLoading ||
        collabsAsync.isLoading ||
        ticketsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || collabsAsync.hasError || ticketsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coordinador')),
        body: Center(
          child: Text(
            '${eventAsync.error ?? collabsAsync.error ?? ticketsAsync.error}',
          ),
        ),
      );
    }

    final collaborators = collabsAsync.requireValue;
    final tickets = ticketsAsync.requireValue;
    Collaborator? match;
    for (final c in collaborators) {
      if (c.id == coordinatorId) {
        match = c;
        break;
      }
    }
    if (match == null || match.role != CollaboratorRole.coordinator) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final coordinator = match;
    final allSellers = collaborators
        .where((c) => c.role == CollaboratorRole.seller)
        .toList(growable: false);
    final sellers = allSellers
        .where((c) => c.createdByCoordinatorId == coordinatorId)
        .toList(growable: false);
    final assignable = allSellers
        .where((c) => c.createdByCoordinatorId != coordinatorId)
        .toList(growable: false);
    final coordinatorNames = {
      for (final c in collaborators)
        if (c.role == CollaboratorRole.coordinator) c.id: c.name,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Coordinador')),
      floatingActionButton: assignable.isEmpty
          ? null
          : BottomSystemInset(
              child: FloatingActionButton.extended(
                onPressed: () => _showAssignSellerSheet(
                  context,
                  ref,
                  coordinator: coordinator,
                  assignable: assignable,
                  coordinatorNames: coordinatorNames,
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Asignar vendedor'),
              ),
            ),
      body: ListView(
        padding: listPaddingWithFab(context),
        children: [
          CollaboratorProfileCard(
            eventId: eventId,
            collaboratorId: coordinatorId,
            expectedRole: CollaboratorRole.coordinator,
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
            Text(
              assignable.isEmpty
                  ? 'Todavía no hay vendedores en el evento.'
                  : 'Todavía no tiene vendedores. Usá Asignar vendedor.',
              style: const TextStyle(color: AppColors.textMuted),
            )
          else
            for (final seller in sellers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SellerDetailScreen(
                          eventId: eventId,
                          sellerId: seller.id,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seller.name,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              if (seller.notes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  seller.notes,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              TicketStatusSummary(
                                tickets: tickets
                                    .where((t) => t.sellerId == seller.id)
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar del coordinador',
                          onPressed: () => _unassignSeller(
                            context,
                            ref,
                            seller: seller,
                          ),
                          icon: const Icon(Icons.link_off_outlined),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _unassignSeller(
    BuildContext context,
    WidgetRef ref, {
    required Collaborator seller,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar vendedor'),
        content: Text(
          '¿Sacar a ${seller.name} de este coordinador? '
          'Sigue siendo vendedor del evento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await setSellerCoordinatorAction(
        ref,
        eventId: eventId,
        sellerId: seller.id,
        coordinatorId: null,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${seller.name} ya no está en este coordinador.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showAssignSellerSheet(
    BuildContext context,
    WidgetRef ref, {
    required Collaborator coordinator,
    required List<Collaborator> assignable,
    required Map<String, String> coordinatorNames,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Asignar a ${coordinator.name}',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final seller in assignable)
                ListTile(
                  title: Text(seller.name),
                  subtitle: Text(
                    seller.createdByCoordinatorId == null
                        ? 'Sin coordinador'
                        : 'Ahora: ${coordinatorNames[seller.createdByCoordinatorId!] ?? 'Otro coordinador'}',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await setSellerCoordinatorAction(
                        ref,
                        eventId: eventId,
                        sellerId: seller.id,
                        coordinatorId: coordinatorId,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${seller.name} asignado a ${coordinator.name}.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

}
