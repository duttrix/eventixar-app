import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';

/// Admin-only placeholder: reporting is not fully specified yet, this
/// shows the three data points already agreed for stage 1.
class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final aggregate = repo.aggregateForEvent(eventId);
    final sellers = repo.sellersForEvent(eventId);
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);
    final collected = aggregate[TicketStatus.collected] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warnBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Pendiente de definir en detalle. Etapa 1: recaudación total, tickets por estado, '
            'desempeño por vendedor.',
            style: TextStyle(color: AppColors.warnText),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Recaudación total (tickets cobrados)',
          child: Text(
            currency.format(collected * event.ticketPrice),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Tickets por estado',
          child: Column(
            children: [
              for (final status in TicketStatus.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(status.label)),
                      Text('${aggregate[status] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Desempeño por vendedor',
          child: Column(
            children: [
              for (final seller in sellers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(seller.name)),
                      Text(
                        '${repo.ticketsForSeller(seller.id).where((t) => t.status == TicketStatus.collected).length} cobrados',
                        style: const TextStyle(color: AppColors.textSecondary),
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
