import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/access_share.dart';

/// Informative organizer view of everything received by one collector.
class CollectorDetailScreen extends ConsumerWidget {
  const CollectorDetailScreen({
    super.key,
    required this.eventId,
    required this.collectorId,
  });

  final String eventId;
  final String collectorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final collector = repo.collaboratorById(collectorId);
    final tickets = repo.ticketsSettledBy(collectorId)
      ..sort((a, b) => a.number.compareTo(b.number));
    final currency = NumberFormat.currency(
      locale: 'es_AR',
      symbol: r'$',
      decimalDigits: 0,
    );

    final bySeller = <String, List<Ticket>>{};
    for (final ticket in tickets) {
      final sellerId = ticket.sellerId;
      if (sellerId == null) continue;
      bySeller.putIfAbsent(sellerId, () => []).add(ticket);
    }

    return Scaffold(
      appBar: AppBar(title: Text(collector.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Resumen de recaudación',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tickets.length} tickets rendidos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(tickets.length * event.ticketPrice),
                  style: const TextStyle(
                    color: AppColors.successText,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  collector.phone.isEmpty ? 'Sin celular' : collector.phone,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (collector.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    collector.notes,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Rendido por vendedor',
            child: bySeller.isEmpty
                ? const Text(
                    'Este recaudador todavía no registró rendiciones.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    children: [
                      for (final entry in bySeller.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(repo.collaboratorById(entry.key).name),
                              ),
                              Text(
                                '${entry.value.length} tickets · '
                                '${currency.format(entry.value.length * event.ticketPrice)}',
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
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Detalle de tickets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final ticket in tickets)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    'Ticket #${ticket.number}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (ticket.sellerId != null)
                        'Vendedor: ${repo.collaboratorById(ticket.sellerId!).name}',
                      if (ticket.buyerName.isNotEmpty)
                        'Para: ${ticket.buyerName}',
                    ].join(' · '),
                  ),
                  trailing: StatusBadge(
                    label: ticket.status.label,
                    tone: ticketStatusTone(ticket.status),
                  ),
                ),
              ),
          ],
        ],
      ),
      backgroundColor: AppColors.background,
    );
  }
}
