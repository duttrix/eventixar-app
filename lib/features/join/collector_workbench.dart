import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Shared collect / settle UI for collector portal and organizer workspace.
class CollectorWorkbench extends ConsumerStatefulWidget {
  const CollectorWorkbench({
    super.key,
    required this.eventId,
    required this.actorId,
    required this.actorLabel,
    this.actorRole = 'collector',
    this.showLogout = false,
  });

  final String eventId;
  final String actorId;
  final String actorLabel;

  /// Stored on ticket history: `collector` | `organizer`.
  final String actorRole;

  final bool showLogout;

  @override
  ConsumerState<CollectorWorkbench> createState() => _CollectorWorkbenchState();
}

class _CollectorWorkbenchState extends ConsumerState<CollectorWorkbench> {
  Collaborator? _selectedSeller;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    final sellersAsync = ref.watch(eventSellersProvider(widget.eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(widget.eventId));

    if (eventAsync.isLoading ||
        sellersAsync.isLoading ||
        ticketsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || sellersAsync.hasError || ticketsAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Text(
            '${eventAsync.error ?? sellersAsync.error ?? ticketsAsync.error}',
          ),
        ),
      );
    }

    final event = eventAsync.requireValue;
    final sellers = sellersAsync.requireValue;
    final allTickets = ticketsAsync.requireValue;

    if (_selectedSeller != null) {
      return _buildSellerSettlement(
        context,
        event: event,
        seller: _selectedSeller!,
        tickets: allTickets
            .where((t) => t.sellerId == _selectedSeller!.id)
            .toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.actorLabel),
        actions: [
          if (widget.showLogout)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Text(
              widget.actorRole == 'organizer'
                  ? 'Estás rindiendo como organizador. Elegí un vendedor.'
                  : 'Elegí un vendedor para rendir lo cobrado o devolver tickets '
                      'al pool (para que un coordinador los reasigne).',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vendedores', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (sellers.isEmpty)
            const Text(
              'Todavía no hay vendedores.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final seller in sellers)
              _CollectorSellerCard(
                seller: seller,
                pending: allTickets
                    .where(
                      (t) =>
                          t.sellerId == seller.id &&
                          t.status == TicketStatus.collected,
                    )
                    .length,
                settled: allTickets
                    .where(
                      (t) =>
                          t.sellerId == seller.id &&
                          (t.status == TicketStatus.settled ||
                              t.status == TicketStatus.delivered),
                    )
                    .length,
                onTap: () => setState(() {
                  _selectedSeller = seller;
                  _selectedIds.clear();
                }),
              ),
        ],
      ),
    );
  }

  Widget _buildSellerSettlement(
    BuildContext context, {
    required Event event,
    required Collaborator seller,
    required List<Ticket> tickets,
  }) {
    final sorted = [...tickets]..sort((a, b) {
        final byStatus = _collectorTicketSortRank(a.status)
            .compareTo(_collectorTicketSortRank(b.status));
        if (byStatus != 0) return byStatus;
        return a.number.compareTo(b.number);
      });
    final selectable = sorted
        .where(
          (t) =>
              t.status == TicketStatus.collected ||
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.reserved,
        )
        .toList(growable: false);
    final selectedTickets = selectable
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final selectedCollected = selectedTickets
        .where((t) => t.status == TicketStatus.collected)
        .toList(growable: false);
    final fullAmount = event.ticketPrice;
    final profitAmount = event.ticketProfit;

    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _selectedSeller = null;
            _selectedIds.clear();
          }),
        ),
        actions: [
          if (widget.showLogout)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Rendición · ${seller.name}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccioná tickets cobrados o en poder del vendedor. '
                  'Podés rendir lo cobrado, o marcar como devuelto para que '
                  'vuelvan al pool y el coordinador los reasigne.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                TicketStatusSummary(tickets: sorted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: selectedCollected.isEmpty
                      ? null
                      : () async {
                          final mode = await showDialog<TicketSettleMode>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('¿Qué rinde el vendedor?'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Vas a rendir ${selectedCollected.length} ticket'
                                    '${selectedCollected.length == 1 ? '' : 's'}.',
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      TicketSettleMode.full,
                                    ),
                                    child: Text(
                                      'Ticket completo · '
                                      '\$${(selectedCollected.length * fullAmount).toStringAsFixed(0)}',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      TicketSettleMode.profit,
                                    ),
                                    child: Text(
                                      'Solo ganancia · '
                                      '\$${(selectedCollected.length * profitAmount).toStringAsFixed(0)}',
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext),
                                  child: const Text('Cancelar'),
                                ),
                              ],
                            ),
                          );
                          if (mode == null || !context.mounted) return;
                          try {
                            await settleTicketsAction(
                              ref,
                              eventId: event.id,
                              ticketIds: selectedCollected.map((t) => t.id),
                              collectorId: widget.actorId,
                              settleMode: mode,
                              actorRole: widget.actorRole,
                            );
                            if (!context.mounted) return;
                            setState(() {
                              _selectedIds.removeWhere(
                                (id) =>
                                    selectedCollected.any((t) => t.id == id),
                              );
                            });
                            final unit = event.amountForSettleMode(mode);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Rendiste ${selectedCollected.length} tickets '
                                  '(${mode.label.toLowerCase()} · '
                                  '\$${(selectedCollected.length * unit).toStringAsFixed(0)}).',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    selectedCollected.isEmpty
                        ? 'Rendir cobrados'
                        : 'Rendir (${selectedCollected.length})',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: selectedTickets.isEmpty
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Marcar como devuelto'),
                              content: Text(
                                'Vas a devolver ${selectedTickets.length} ticket'
                                '${selectedTickets.length == 1 ? '' : 's'} al pool. '
                                'Quedan libres para que un coordinador los reasigne.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Devolver'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                            await markTicketsReturnedAction(
                              ref,
                              eventId: event.id,
                              ticketIds: selectedTickets.map((t) => t.id),
                              actorId: widget.actorId,
                              actorRole: widget.actorRole,
                            );
                            if (!context.mounted) return;
                            setState(_selectedIds.clear);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${selectedTickets.length} ticket'
                                  '${selectedTickets.length == 1 ? '' : 's'} '
                                  'vuelve${selectedTickets.length == 1 ? '' : 'n'} '
                                  'al pool (devuelto).',
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
                  icon: const Icon(Icons.undo),
                  label: Text(
                    selectedTickets.isEmpty
                        ? 'Devolver'
                        : 'Devolver (${selectedTickets.length})',
                  ),
                ),
              ),
            ],
          ),
          if (selectable.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _selectedIds
                      ..clear()
                      ..addAll(selectable.map((t) => t.id));
                  }),
                  child: const Text('Todos'),
                ),
                TextButton(
                  onPressed: selectedTickets.isEmpty
                      ? null
                      : () => setState(_selectedIds.clear),
                  child: const Text('Ninguno'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text('Tickets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final ticket in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CollectorTicketCard(
                ticket: ticket,
                event: event,
                selected: _selectedIds.contains(ticket.id),
                selectable: ticket.status == TicketStatus.collected ||
                    ticket.status == TicketStatus.withSeller ||
                    ticket.status == TicketStatus.reserved,
                collectorName: ticket.collectorId == null
                    ? null
                    : (ticket.collectorId == widget.actorId
                        ? widget.actorLabel
                        : null),
                onToggle: ticket.status == TicketStatus.collected ||
                        ticket.status == TicketStatus.withSeller ||
                        ticket.status == TicketStatus.reserved
                    ? () => setState(() {
                        if (_selectedIds.contains(ticket.id)) {
                          _selectedIds.remove(ticket.id);
                        } else {
                          _selectedIds.add(ticket.id);
                        }
                      })
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  /// Order: cobrados → reservados → en poder → rendidos → devueltos → validados.
  static int _collectorTicketSortRank(TicketStatus status) {
    return switch (status) {
      TicketStatus.collected => 0,
      TicketStatus.reserved => 1,
      TicketStatus.withSeller => 2,
      TicketStatus.unassigned => 3,
      TicketStatus.settled => 4,
      TicketStatus.returned => 5,
      TicketStatus.delivered => 6,
    };
  }
}

class _CollectorSellerCard extends StatelessWidget {
  const _CollectorSellerCard({
    required this.seller,
    required this.pending,
    required this.settled,
    required this.onTap,
  });

  final Collaborator seller;
  final int pending;
  final int settled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(seller.name),
        subtitle: Text(
          [
            if (seller.notes.isNotEmpty) seller.notes,
            '$pending cobrados · $settled rendidos',
          ].join(' · '),
        ),
        trailing: StatusBadge(
          label: pending == 0 ? 'Al día' : 'Pendiente',
          tone: pending == 0 ? BadgeTone.success : BadgeTone.warn,
        ),
      ),
    );
  }
}

class _CollectorTicketCard extends StatelessWidget {
  const _CollectorTicketCard({
    required this.ticket,
    required this.event,
    required this.selected,
    required this.selectable,
    required this.onToggle,
    this.collectorName,
  });

  final Ticket ticket;
  final Event event;
  final bool selected;
  final bool selectable;
  final VoidCallback? onToggle;
  final String? collectorName;

  @override
  Widget build(BuildContext context) {
    final buyer = ticket.buyerName.trim();

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? AppColors.accentBg.withValues(alpha: 0.35) : null,
          ),
          padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: selectable ? (_) => onToggle?.call() : null,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket #${ticket.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${event.ticketPrice.toStringAsFixed(0)} · ${event.product}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (buyer.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Para: $buyer',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (collectorName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Recaudó: $collectorName',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    StatusBadge(
                      label: ticket.status.label,
                      tone: ticketStatusTone(ticket.status),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
