import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/delete_collaborator_button.dart';
import '../../shared/widgets/regenerate_access_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

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
    final eventAsync = ref.watch(eventProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));

    if (eventAsync.isLoading || collabsAsync.isLoading || ticketsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || collabsAsync.hasError || ticketsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recaudador')),
        body: Center(
          child: Text(
            '${eventAsync.error ?? collabsAsync.error ?? ticketsAsync.error}',
          ),
        ),
      );
    }

    final event = eventAsync.requireValue;
    Collaborator? match;
    for (final c in collabsAsync.requireValue) {
      if (c.id == collectorId) {
        match = c;
        break;
      }
    }
    if (match == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final collector = match;
    final tickets = ticketsAsync.requireValue
        .where((t) => t.collectorId == collectorId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final currency = NumberFormat.currency(
      locale: 'es_AR',
      symbol: r'$',
      decimalDigits: 0,
    );
    final token = ref
            .watch(eventAccessTokensProvider(eventId))
            .valueOrNull?[collectorId] ??
        '';

    final bySeller = <String, List<Ticket>>{};
    for (final ticket in tickets) {
      final sellerId = ticket.sellerId;
      if (sellerId == null) continue;
      bySeller.putIfAbsent(sellerId, () => []).add(ticket);
    }

    Collaborator? sellerById(String id) {
      for (final c in collabsAsync.requireValue) {
        if (c.id == id) return c;
      }
      return null;
    }

    final totalSettled = tickets.fold<double>(
      0,
      (sum, t) => sum + t.resolvedSettledAmount(event.ticketPrice),
    );

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
                  currency.format(totalSettled),
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
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => AccessShare.copy(
                    context,
                    collector,
                    eventName: event.name,
                    token: token,
                  ),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Compartir acceso'),
                ),
                RegenerateAccessButton(
                  collaborator: collector,
                  eventName: event.name,
                ),
                DeleteCollaboratorButton(
                  collaborator: collector,
                  onDeleted: () {
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (tickets.isEmpty)
            const Text(
              'Todavía no rindió tickets.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final entry in bySeller.entries) ...[
              Text(
                sellerById(entry.key)?.name ?? 'Vendedor',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final ticket in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ticketStatusBg(ticket.status),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ticket #${ticket.number}'),
                              if (ticket.settleMode != null ||
                                  ticket.settledAmount != null)
                                Text(
                                  [
                                    if (ticket.settleMode != null)
                                      ticket.settleMode!.label,
                                    currency.format(
                                      ticket.resolvedSettledAmount(
                                        event.ticketPrice,
                                      ),
                                    ),
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: ticket.status.label,
                          tone: ticketStatusTone(ticket.status),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
