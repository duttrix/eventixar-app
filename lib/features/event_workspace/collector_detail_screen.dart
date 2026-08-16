import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/collaborator_profile_card.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

enum _CollectorTicketFilter { validated, full, profit }

/// Organizer view of one collector: access actions + tickets they settled.
class CollectorDetailScreen extends ConsumerStatefulWidget {
  const CollectorDetailScreen({
    super.key,
    required this.eventId,
    required this.collectorId,
  });

  final String eventId;
  final String collectorId;

  @override
  ConsumerState<CollectorDetailScreen> createState() =>
      _CollectorDetailScreenState();
}

class _CollectorDetailScreenState extends ConsumerState<CollectorDetailScreen> {
  final Set<_CollectorTicketFilter> _filters = {};

  String get eventId => widget.eventId;
  String get collectorId => widget.collectorId;

  bool _isFullSettle(Ticket ticket) =>
      ticket.settleMode == TicketSettleMode.full ||
      (ticket.settleMode == null && ticket.status == TicketStatus.settled);

  bool _isProfitSettle(Ticket ticket) =>
      ticket.settleMode == TicketSettleMode.profit;

  bool _matches(Ticket ticket) {
    if (_filters.isEmpty) return true;
    for (final filter in _filters) {
      switch (filter) {
        case _CollectorTicketFilter.validated:
          if (ticket.status == TicketStatus.delivered) return true;
        case _CollectorTicketFilter.full:
          if (_isFullSettle(ticket)) return true;
        case _CollectorTicketFilter.profit:
          if (_isProfitSettle(ticket)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
    if (match == null || match.role != CollaboratorRole.collector) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tickets = ticketsAsync.requireValue
        .where((t) => t.collectorId == collectorId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final visible = tickets.where(_matches).toList(growable: false);
    final fullTickets = tickets.where(_isFullSettle).toList(growable: false);
    final profitTickets =
        tickets.where(_isProfitSettle).toList(growable: false);
    final fullAmount = fullTickets.fold<double>(
      0,
      (sum, t) => sum + t.resolvedSettledAmount(event.ticketPrice),
    );
    final profitAmount = profitTickets.fold<double>(
      0,
      (sum, t) => sum + t.resolvedSettledAmount(event.ticketPrice),
    );
    final validatedCount =
        tickets.where((t) => t.status == TicketStatus.delivered).length;
    final fullCount = fullTickets.length;
    final profitCount = profitTickets.length;

    Collaborator? sellerById(String? id) {
      if (id == null) return null;
      for (final c in collabsAsync.requireValue) {
        if (c.id == id) return c;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recaudador')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CollaboratorProfileCard(
            eventId: eventId,
            collaboratorId: collectorId,
            expectedRole: CollaboratorRole.collector,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Rendición',
            child: tickets.isEmpty
                ? const Text(
                    'Todavía no rindió tickets.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (fullCount > 0) ...[
                        _RendicionStatRow(
                          label: 'Rendido completo ($fullCount)',
                          amount: formatMoney(fullAmount),
                          style: collectorFilterStyle(
                            validated: false,
                            fullSettle: true,
                            profitSettle: false,
                          ),
                        ),
                        if (profitCount > 0) const SizedBox(height: 8),
                      ],
                      if (profitCount > 0)
                        _RendicionStatRow(
                          label: 'Solo ganancia ($profitCount)',
                          amount: formatMoney(profitAmount),
                          style: collectorFilterStyle(
                            validated: false,
                            fullSettle: false,
                            profitSettle: true,
                          ),
                        ),
                    ],
                  ),
          ),
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: 16),
            TicketStatusCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (validatedCount > 0)
                    _CollectorFilterChip(
                      label: 'Validados',
                      count: validatedCount,
                      selected:
                          _filters.contains(_CollectorTicketFilter.validated),
                      style: collectorFilterStyle(
                        validated: true,
                        fullSettle: false,
                        profitSettle: false,
                      ),
                      onTap: () => setState(() {
                        final f = _CollectorTicketFilter.validated;
                        if (_filters.contains(f)) {
                          _filters.remove(f);
                        } else {
                          _filters.add(f);
                        }
                      }),
                    ),
                  if (fullCount > 0)
                    _CollectorFilterChip(
                      label: 'Rendido',
                      count: fullCount,
                      selected: _filters.contains(_CollectorTicketFilter.full),
                      style: collectorFilterStyle(
                        validated: false,
                        fullSettle: true,
                        profitSettle: false,
                      ),
                      onTap: () => setState(() {
                        final f = _CollectorTicketFilter.full;
                        if (_filters.contains(f)) {
                          _filters.remove(f);
                        } else {
                          _filters.add(f);
                        }
                      }),
                    ),
                  if (profitCount > 0)
                    _CollectorFilterChip(
                      label: 'Solo ganancia',
                      count: profitCount,
                      selected: _filters.contains(_CollectorTicketFilter.profit),
                      style: collectorFilterStyle(
                        validated: false,
                        fullSettle: false,
                        profitSettle: true,
                      ),
                      onTap: () => setState(() {
                        final f = _CollectorTicketFilter.profit;
                        if (_filters.contains(f)) {
                          _filters.remove(f);
                        } else {
                          _filters.add(f);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _filters.isEmpty
                        ? 'Tickets (${tickets.length})'
                        : 'Tickets (${visible.length} de ${tickets.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_filters.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_filters.clear),
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const Text(
                'Ningún ticket con ese filtro.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (final ticket in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: ticketBg(ticket),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ticket #${ticket.number}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (sellerById(ticket.sellerId) != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Vendedor: ${sellerById(ticket.sellerId)!.name}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (ticket.buyerName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Para: ${ticket.buyerName}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (ticket.settleMode != null)
                                      ticket.settleMode!.label,
                                    formatMoney(
                                      ticket.resolvedSettledAmount(
                                        event.ticketPrice,
                                      ),
                                    ),
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: ticket.status.label,
                            tone: ticketTone(ticket),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _RendicionStatRow extends StatelessWidget {
  const _RendicionStatRow({
    required this.label,
    required this.amount,
    required this.style,
  });

  final String label;
  final String amount;
  final TicketStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: style.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: style.foreground,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorFilterChip extends StatelessWidget {
  const _CollectorFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final TicketStatusStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: style.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
