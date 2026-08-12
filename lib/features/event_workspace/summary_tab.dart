import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';

/// Unified overview + key figures (former Resumen + Reportes).
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.eventId});

  final String eventId;

  static const Color _assignedBlue = Color(0xFF2F6FED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));

    if (eventAsync.isLoading || ticketsAsync.isLoading || collabsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eventAsync.hasError) {
      return Center(child: Text('No se pudo cargar: ${eventAsync.error}'));
    }
    if (ticketsAsync.hasError) {
      return Center(child: Text('No se pudo cargar tickets: ${ticketsAsync.error}'));
    }
    if (collabsAsync.hasError) {
      return Center(
        child: Text('No se pudo cargar equipo: ${collabsAsync.error}'),
      );
    }

    final event = eventAsync.requireValue;
    final tickets = ticketsAsync.requireValue;
    final collaborators = collabsAsync.requireValue;
    final sellers =
        collaborators.where((c) => c.role == CollaboratorRole.seller).toList();
    final validators = collaborators
        .where((c) => c.role == CollaboratorRole.validator)
        .toList();
    final collectors = collaborators
        .where((c) => c.role == CollaboratorRole.collector)
        .toList();

    final currency =
        NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);
    final finished = event.status == EventStatus.finished;
    final hasPending = tickets.any(
      (t) =>
          t.status == TicketStatus.withSeller ||
          t.status == TicketStatus.reserved ||
          t.status == TicketStatus.collected,
    );

    final total = tickets.isEmpty ? event.ticketCount : tickets.length;
    var inPool = 0;
    var reserved = 0;
    var collected = 0;
    var settled = 0;
    var delivered = 0;
    for (final ticket in tickets) {
      switch (ticket.status) {
        case TicketStatus.unassigned:
        case TicketStatus.returned:
          inPool++;
        case TicketStatus.reserved:
          reserved++;
        case TicketStatus.collected:
          collected++;
        case TicketStatus.settled:
          settled++;
        case TicketStatus.delivered:
          delivered++;
        case TicketStatus.withSeller:
          break;
      }
    }
    final assigned = total - inPool;
    final cobradas = collected + settled + delivered;
    final noCobradas = total - cobradas;
    final rendidas = settled + delivered;
    final noRendidas = collected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FunnelSection(
          title: 'Distribución',
          children: [
            Expanded(
              child: StatCard(
                label: 'Asignadas',
                value: '$assigned',
                accentColor: _assignedBlue,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'En pool',
                value: '$inPool',
                accentColor: AppColors.textSecondary,
                large: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FunnelSection(
          title: 'Cobro',
          children: [
            Expanded(
              child: StatCard(
                label: 'Cobradas',
                value: '$cobradas',
                accentColor: AppColors.successText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'No cobradas',
                value: '$noCobradas',
                accentColor: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Reservadas',
                value: '$reserved',
                accentColor: AppColors.warnText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FunnelSection(
          title: 'Rendición',
          children: [
            Expanded(
              child: StatCard(
                label: 'Rendidas',
                value: '$rendidas',
                accentColor: AppColors.accentText,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'No rendidas',
                value: '$noRendidas',
                accentColor: AppColors.warnText,
                large: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'DESEMPEÑO',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Vendedores',
          child: sellers.isEmpty
              ? const Text(
                  'Todavía no hay vendedores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final seller in sellers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(seller.name)),
                            Text(
                              '${tickets.where((t) => t.sellerId == seller.id && (t.status == TicketStatus.collected || t.status == TicketStatus.settled || t.status == TicketStatus.delivered)).length} cobrados',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Validadores',
          child: validators.isEmpty
              ? const Text(
                  'Todavía no hay validadores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final validator in validators)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(validator.name)),
                            Text(
                              '${tickets.where((t) => t.validatorId == validator.id).length} validados',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Recaudadores',
          child: collectors.isEmpty
              ? const Text(
                  'Todavía no hay recaudadores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final collector in collectors)
                      Builder(
                        builder: (context) {
                          final collectorTickets = tickets
                              .where((t) => t.collectorId == collector.id)
                              .toList(growable: false);
                          final count = collectorTickets.length;
                          final amount = collectorTickets.fold<double>(
                            0,
                            (sum, t) =>
                                sum +
                                t.resolvedSettledAmount(event.ticketPrice),
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(collector.name)),
                                Text(
                                  '$count rendidos · ${currency.format(amount)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Cierre del evento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                finished
                    ? 'Evento finalizado. La operación está en solo consulta.'
                    : hasPending
                        ? 'Hay tickets en poder de vendedores, reservados o cobrados sin rendir.'
                        : 'No hay cobros pendientes de rendición. Podés finalizar cuando quieras.',
                style: TextStyle(
                  color: finished
                      ? AppColors.successText
                      : hasPending
                          ? AppColors.warnText
                          : AppColors.textSecondary,
                ),
              ),
              if (!finished) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _confirmFinish(
                    context,
                    ref,
                    hasPending: hasPending,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Finalizar evento'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmFinish(
    BuildContext context,
    WidgetRef ref, {
    required bool hasPending,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar evento'),
        content: Text(
          hasPending
              ? 'Todavía hay tickets en poder de vendedores, reservados o cobrados sin rendir. '
                  'Si finalizás igual, el evento pasa a solo consulta.'
              : 'Vas a finalizar el evento. La operación quedará en solo consulta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(hasPending ? 'Finalizar igual' : 'Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(eventRepositoryProvider).finishEvent(eventId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evento finalizado. Pasó a solo consulta.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo finalizar: $e')),
      );
    }
  }
}

class _FunnelSection extends StatelessWidget {
  const _FunnelSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
