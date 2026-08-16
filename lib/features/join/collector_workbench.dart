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
  final Set<TicketStatus> _statusFilters = {};

  static bool _isSettleable(TicketStatus status) =>
      status == TicketStatus.collected ||
      status == TicketStatus.withSeller ||
      status == TicketStatus.reserved;

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
                  : 'Elegí un vendedor para rendir tickets (en poder, '
                      'reservados o cobrados) o devolverlos al pool '
                      '(para que un coordinador los reasigne).',
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
                          (t.status == TicketStatus.collected ||
                              t.status == TicketStatus.withSeller ||
                              t.status == TicketStatus.reserved),
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
                  _statusFilters.clear();
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
    final sorted = [...tickets]
      ..sort((a, b) => a.number.compareTo(b.number));
    final visible = _statusFilters.isEmpty
        ? sorted
        : sorted
            .where((t) => _statusFilters.contains(t.status))
            .toList(growable: false);
    final selectableVisible = visible
        .where((t) => _isSettleable(t.status))
        .toList(growable: false);
    final selectedTickets = sorted
        .where(
          (t) => _isSettleable(t.status) && _selectedIds.contains(t.id),
        )
        .toList(growable: false);
    final selectedToSettle = selectedTickets;
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
            _statusFilters.clear();
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
                  'Seleccioná tickets en poder del vendedor, reservados o '
                  'cobrados. Rendirlos los marca como vendidos (aunque el '
                  'vendedor no haya cobrado en la app). Devolverlos los '
                  'manda al pool para reasignar.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TicketStatusSummary(
                    tickets: sorted,
                    selected: _statusFilters,
                    onStatusTap: (status) => setState(() {
                      if (_statusFilters.contains(status)) {
                        _statusFilters.remove(status);
                        if (_isSettleable(status)) {
                          _selectedIds.removeWhere(
                            (id) => tickets.any(
                              (t) => t.id == id && t.status == status,
                            ),
                          );
                        }
                      } else {
                        _statusFilters.add(status);
                        if (_isSettleable(status)) {
                          _selectedIds.addAll(
                            tickets
                                .where((t) => t.status == status)
                                .map((t) => t.id),
                          );
                        }
                      }
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: selectedToSettle.isEmpty
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
                                    'Vas a rendir ${selectedToSettle.length} ticket'
                                    '${selectedToSettle.length == 1 ? '' : 's'} '
                                    '(quedan como vendidos).',
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      TicketSettleMode.full,
                                    ),
                                    child: Text(
                                      'Ticket completo · '
                                      '\$${(selectedToSettle.length * fullAmount).toStringAsFixed(0)}',
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
                                      '\$${(selectedToSettle.length * profitAmount).toStringAsFixed(0)}',
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
                              ticketIds: selectedToSettle.map((t) => t.id),
                              collectorId: widget.actorId,
                              settleMode: mode,
                              actorRole: widget.actorRole,
                            );
                            if (!context.mounted) return;
                            setState(() {
                              _selectedIds.removeWhere(
                                (id) =>
                                    selectedToSettle.any((t) => t.id == id),
                              );
                            });
                            final unit = event.amountForSettleMode(mode);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Rendiste ${selectedToSettle.length} tickets '
                                  '(${mode.label.toLowerCase()} · '
                                  '\$${(selectedToSettle.length * unit).toStringAsFixed(0)}).',
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
                    selectedToSettle.isEmpty
                        ? 'Rendir'
                        : 'Rendir (${selectedToSettle.length})',
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _statusFilters.isEmpty
                      ? 'Tickets (${sorted.length})'
                      : 'Tickets (${visible.length} de ${sorted.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_statusFilters.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _statusFilters.clear();
                  }),
                  child: const Text('Ver todos'),
                ),
              if (selectableVisible.isNotEmpty) ...[
                TextButton(
                  onPressed: () => setState(() {
                    _selectedIds.addAll(selectableVisible.map((t) => t.id));
                  }),
                  child: const Text('Todos'),
                ),
                TextButton(
                  onPressed: selectedTickets.isEmpty
                      ? null
                      : () => setState(() {
                          _selectedIds.removeWhere(
                            (id) => selectableVisible.any((t) => t.id == id),
                          );
                        }),
                  child: const Text('Ninguno'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            const Text(
              'Ningún ticket con esos estados.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final ticket in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CollectorTicketCard(
                  ticket: ticket,
                  event: event,
                  selected: _selectedIds.contains(ticket.id),
                  selectable: _isSettleable(ticket.status),
                  collectorName: ticket.collectorId == null
                      ? null
                      : (ticket.collectorId == widget.actorId
                          ? widget.actorLabel
                          : null),
                  onToggle: _isSettleable(ticket.status)
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
            '$pending pendientes · $settled rendidos',
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
                      label: ticket.statusDisplayLabel,
                      tone: ticketTone(ticket),
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
