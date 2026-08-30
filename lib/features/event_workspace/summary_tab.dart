import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';

/// Unified overview + key figures (former Resumen + Reportes).
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));

    if (eventAsync.isLoading ||
        ticketsAsync.isLoading ||
        collabsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eventAsync.hasError) {
      return Center(child: Text('No se pudo cargar: ${eventAsync.error}'));
    }
    if (ticketsAsync.hasError) {
      return Center(
        child: Text('No se pudo cargar tickets: ${ticketsAsync.error}'),
      );
    }
    if (collabsAsync.hasError) {
      return Center(
        child: Text('No se pudo cargar equipo: ${collabsAsync.error}'),
      );
    }

    final event = eventAsync.requireValue;
    final tickets = ticketsAsync.requireValue;
    final collaborators = collabsAsync.requireValue;
    final sellers = collaborators
        .where((c) => c.role == CollaboratorRole.seller)
        .toList();
    final validators = collaborators
        .where((c) => c.role == CollaboratorRole.validator)
        .toList();
    final collectors = collaborators
        .where((c) => c.role == CollaboratorRole.collector)
        .toList();

    final total = tickets.isEmpty ? event.ticketCount : tickets.length;
    var cobradosTotales = 0;
    var cobradosGanancia = 0;
    var porCobrar = 0;
    var rendidos = 0;
    var porRendir = 0;
    var enVendedor = 0;
    var validados = 0;
    var rendidoAmount = 0.0;
    var gananciaAmount = 0.0;

    for (final ticket in tickets) {
      switch (ticket.status) {
        case TicketStatus.unassigned:
        case TicketStatus.returned:
          porCobrar++;
        case TicketStatus.withSeller:
        case TicketStatus.reserved:
          porCobrar++;
          enVendedor++;
        case TicketStatus.collected:
          cobradosTotales++;
          porRendir++;
        case TicketStatus.settled:
        case TicketStatus.delivered:
          rendidos++;
          rendidoAmount += ticket.resolvedSettledAmount(event.ticketPrice);
          if (ticket.settleMode == TicketSettleMode.profit) {
            cobradosGanancia++;
            gananciaAmount += ticket.resolvedSettledAmount(event.ticketProfit);
          } else {
            cobradosTotales++;
          }
          if (ticket.status == TicketStatus.delivered) validados++;
      }
    }
    if (tickets.isEmpty) porCobrar = total;

    final noValidados = total - validados;
    final cobradoTotalesAmount = event.ticketPrice * cobradosTotales;
    final porCobrarAmount = event.ticketPrice * porCobrar;
    final porRendirAmount = event.ticketPrice * porRendir;
    final enVendedorAmount = event.ticketPrice * enVendedor;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FunnelSection(
          title: 'Cobro',
          children: [
            Expanded(
              child: StatCard(
                label: 'Totales',
                value: formatMoney(cobradoTotalesAmount),
                subtitle: '$cobradosTotales tickets',
                accentColor: AppColors.successText,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Ganancia',
                value: formatMoney(
                  gananciaAmount > 0
                      ? gananciaAmount
                      : event.ticketProfit * cobradosGanancia,
                ),
                subtitle: '$cobradosGanancia tickets',
                accentColor: AppColors.warnText,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Por cobrar',
                value: formatMoney(porCobrarAmount),
                subtitle: '$porCobrar tickets',
                accentColor: AppColors.textSecondary,
                large: true,
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
                label: 'Rendidos',
                value: '$rendidos',
                subtitle: formatMoney(rendidoAmount),
                accentColor: AppColors.accentText,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Por rendir',
                value: '$porRendir',
                subtitle: formatMoney(porRendirAmount),
                accentColor: AppColors.warnText,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'En vendedor',
                value: '$enVendedor',
                subtitle: formatMoney(enVendedorAmount),
                accentColor: AppColors.infoText,
                large: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FunnelSection(
          title: 'Validación',
          children: [
            Expanded(
              child: StatCard(
                label: 'Validados',
                value: '$validados',
                accentColor: AppColors.deliveredText,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'No validados',
                value: '$noValidados',
                accentColor: AppColors.textSecondary,
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
                      Builder(
                        builder: (context) {
                          final sold = tickets
                              .where(
                                (t) =>
                                    t.sellerId == seller.id &&
                                    (t.status == TicketStatus.collected ||
                                        t.status == TicketStatus.settled ||
                                        t.status == TicketStatus.delivered),
                              )
                              .length;
                          final held = tickets
                              .where(
                                (t) =>
                                    t.sellerId == seller.id &&
                                    (t.status == TicketStatus.withSeller ||
                                        t.status == TicketStatus.reserved),
                              )
                              .length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(seller.name)),
                                Text(
                                  '$sold cobrados · ${formatMoney(event.ticketPrice * sold)}'
                                  '${held > 0 ? ' · $held en mano' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
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
                                  '$count rendidos · ${formatMoney(amount)}',
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
      ],
    );
  }
}

class _FunnelSection extends StatelessWidget {
  const _FunnelSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
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
        ],
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
