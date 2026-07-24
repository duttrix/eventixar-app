import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/stat_card.dart';

/// Unified overview + key figures (former Resumen + Reportes).
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final aggregate = repo.aggregateForEvent(eventId);
    final sellers = repo.sellersForEvent(eventId);
    final validators = repo.validatorsForEvent(eventId);
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

    final issued = repo.totalTicketsForEvent(eventId);
    final assigned = aggregate.entries
        .where((e) => e.key != TicketStatus.unassigned)
        .fold(0, (sum, e) => sum + e.value);
    final unassigned = aggregate[TicketStatus.unassigned] ?? 0;
    final collected = aggregate[TicketStatus.collected] ?? 0;
    final delivered = aggregate[TicketStatus.delivered] ?? 0;
    final returned = aggregate[TicketStatus.returned] ?? 0;
    final estimatedRevenue = collected * event.ticketPrice;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: AppColors.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recaudación estimada',
                      style: TextStyle(color: AppColors.accentText, fontSize: 12),
                    ),
                    Text(
                      currency.format(estimatedRevenue),
                      style: const TextStyle(
                        color: AppColors.accentText,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      'Según $collected tickets cobrados',
                      style: const TextStyle(color: AppColors.accentText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: [
            StatCard(label: 'Emitidos', value: '$issued'),
            StatCard(label: 'Asignados', value: '$assigned'),
            StatCard(label: 'Sin asignar', value: '$unassigned'),
            StatCard(label: 'Cobrados', value: '$collected', accentColor: AppColors.successText),
            StatCard(label: 'Validados', value: '$delivered', accentColor: AppColors.accentText),
            StatCard(label: 'Devueltos', value: '$returned', accentColor: AppColors.dangerText),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Desempeño por vendedor',
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
                              '${repo.ticketsForSeller(seller.id).where((t) => t.status == TicketStatus.collected || t.status == TicketStatus.delivered).length} cobrados',
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
        const SizedBox(height: 16),
        SectionCard(
          title: 'Desempeño por validador',
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
                              '${repo.ticketsValidatedBy(validator.id).length} validados',
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
