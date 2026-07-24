import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/stat_card.dart';

/// Overview visible to every role: 6 stat tiles plus an estimated revenue
/// note, all computed from the event's mock aggregate ticket counts.
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final aggregate = repo.aggregateForEvent(eventId);
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

    final issued = repo.totalTicketsForEvent(eventId);
    final assigned = aggregate.entries
        .where((e) => e.key != TicketStatus.unassigned)
        .fold(0, (sum, e) => sum + e.value);
    final unassigned = aggregate[TicketStatus.unassigned] ?? 0;
    final collected = aggregate[TicketStatus.collected] ?? 0;
    final withSeller = aggregate[TicketStatus.withSeller] ?? 0;
    final delivered = aggregate[TicketStatus.delivered] ?? 0;
    final estimatedRevenue = collected * event.ticketPrice;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatCard(label: 'Tickets emitidos', value: '$issued'),
            StatCard(label: 'Asignados a vendedores', value: '$assigned'),
            StatCard(label: 'Sin asignar', value: '$unassigned'),
            StatCard(label: 'Cobrados', value: '$collected', accentColor: AppColors.successText),
            StatCard(label: 'En poder del vendedor', value: '$withSeller', accentColor: AppColors.warnText),
            StatCard(label: 'Validados', value: '$delivered', accentColor: AppColors.accentText),
          ],
        ),
        const SizedBox(height: 16),
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
                child: Text(
                  'Recaudación estimada (según tickets cobrados): ${currency.format(estimatedRevenue)}',
                  style: const TextStyle(color: AppColors.accentText, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
