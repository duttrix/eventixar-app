import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/add_collaborator_fab.dart';
import '../../shared/widgets/bottom_system_inset.dart';
import '../../shared/widgets/collaborator_form_dialog.dart';
import '../../shared/widgets/help_callout.dart';
import 'coordinator_detail_screen.dart';

/// Organizer roster of coordinators.
///
/// Each coordinator creates and manages sellers via their invite link.
class CoordinatorsTab extends ConsumerWidget {
  const CoordinatorsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final coordinatorsAsync = ref.watch(eventCoordinatorsProvider(eventId));
    final sellersAsync = ref.watch(eventSellersProvider(eventId));
    final readOnly = eventAsync.valueOrNull?.isReadOnly ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: readOnly
          ? null
          : AddCollaboratorFab(
              onPressed: eventAsync.hasValue
                  ? () => _createCoordinator(
                      context,
                      ref,
                      eventName: eventAsync.requireValue.name,
                    )
                  : null,
            ),
      body: coordinatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (coordinators) {
          final sellers = sellersAsync.valueOrNull ?? const <Collaborator>[];
          return ListView(
            padding: listPaddingWithFab(context),
            children: [
              const HelpCallout(
                message:
                    'Los coordinadores gestionan vendedores: los crean, les '
                    'asignan tickets y comparten accesos desde el '
                    'celular, sin cuenta. Abrí cada uno para ver sus vendedores '
                    'o gestionar el acceso.',
              ),
              const SizedBox(height: 20),
              Text(
                coordinators.isEmpty
                    ? 'Coordinadores'
                    : 'Coordinadores (${coordinators.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (coordinators.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    readOnly
                        ? 'No se crearon coordinadores para este evento.'
                        : 'Usá Agregar para crear un coordinador y compartirle el link.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                )
              else
                for (final coordinator in coordinators)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CoordinatorDetailScreen(
                              eventId: eventId,
                              coordinatorId: coordinator.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Builder(
                          builder: (context) {
                            final sellerCount = sellers
                                .where(
                                  (s) =>
                                      s.createdByCoordinatorId ==
                                      coordinator.id,
                                )
                                .length;
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coordinator.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          sellerCount == 0
                                              ? 'Sin vendedores'
                                              : '$sellerCount vendedor'
                                                    '${sellerCount == 1 ? '' : 'es'}',
                                          if (coordinator.notes.isNotEmpty)
                                            coordinator.notes,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createCoordinator(
    BuildContext context,
    WidgetRef ref, {
    required String eventName,
  }) async {
    final created = await showCollaboratorFormDialog(
      context: context,
      ref: ref,
      eventId: eventId,
      role: CollaboratorRole.coordinator,
      eventName: eventName,
    );
    if (created == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoordinatorDetailScreen(
          eventId: eventId,
          coordinatorId: created.id,
        ),
      ),
    );
  }
}
