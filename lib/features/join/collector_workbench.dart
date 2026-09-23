import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/event_details_card.dart';
import '../../shared/widgets/logout_icon_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/ticket_list_card.dart';
import '../../shared/widgets/ticket_selection_bar.dart';

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
  bool _selectionMode = false;

  static bool _isSettleable(TicketStatus status) =>
      status == TicketStatus.collected ||
      status == TicketStatus.withSeller ||
      status == TicketStatus.reserved;

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelection([Ticket? first]) {
    setState(() {
      _selectionMode = true;
      if (first != null) _selectedIds.add(first.id);
    });
  }

  void _toggleSelected(Ticket ticket) {
    setState(() {
      if (_selectedIds.contains(ticket.id)) {
        _selectedIds.remove(ticket.id);
      } else {
        _selectedIds.add(ticket.id);
      }
    });
  }

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
        actions: [if (widget.showLogout) const LogoutIconButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.showLogout) ...[
            EventDetailsCard(event: event),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: widget.showLogout ? 'Rendición' : event.name,
            child: Text(
              widget.actorRole == 'organizer'
                  ? 'Estás rindiendo como organizador. Elegí un vendedor.'
                  : 'Elegí un vendedor para rendir lo cobrado '
                        '(ticket completo o solo ganancia).',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            sellers.isEmpty ? 'Vendedores' : 'Vendedores (${sellers.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                tickets: allTickets
                    .where((t) => t.sellerId == seller.id)
                    .toList(growable: false),
                onTap: () => setState(() {
                  _selectedSeller = seller;
                  _selectedIds.clear();
                  _statusFilters.clear();
                  _selectionMode = false;
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
    final sorted = [...tickets]..sort((a, b) => a.number.compareTo(b.number));
    final visible = _statusFilters.isEmpty
        ? sorted
        : sorted
              .where((t) => _statusFilters.contains(t.status))
              .toList(growable: false);
    final selectableTickets = event.isReadOnly
        ? const <Ticket>[]
        : visible
              .where((t) => _isSettleable(t.status))
              .toList(growable: false);
    final selectedTickets = selectableTickets
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final selectedToSettle = selectedTickets
        .where((t) => _isSettleable(t.status))
        .toList(growable: false);
    final hasSelection = selectedTickets.isNotEmpty;
    final showBar = !event.isReadOnly && _selectionMode && hasSelection;
    final allVisibleSelected =
        selectableTickets.isNotEmpty &&
        selectableTickets.every((t) => _selectedIds.contains(t.id));

    bool isFullSettle(Ticket ticket) =>
        ticket.settleMode == TicketSettleMode.full ||
        (ticket.settleMode == null && ticket.status == TicketStatus.settled);
    bool isProfitSettle(Ticket ticket) =>
        ticket.settleMode == TicketSettleMode.profit;

    final fullTickets = sorted.where(isFullSettle).toList(growable: false);
    final profitTickets = sorted.where(isProfitSettle).toList(growable: false);
    final fullSettledTotal = fullTickets.fold<double>(
      0,
      (sum, t) => sum + t.resolvedSettledAmount(event.ticketPrice),
    );
    final profitSettledTotal = profitTickets.fold<double>(
      0,
      (sum, t) => sum + t.resolvedSettledAmount(event.ticketPrice),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _selectedSeller = null;
            _selectedIds.clear();
            _statusFilters.clear();
            _selectionMode = false;
          }),
        ),
        actions: [if (widget.showLogout) const LogoutIconButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, showBar ? 8 : 16),
              children: [
                if (widget.showLogout) ...[
                  EventDetailsCard(event: event),
                  const SizedBox(height: 12),
                ],
                TicketStatusCard.summary(
                  tickets: sorted,
                  selected: _statusFilters,
                  emptyLabel: 'Este vendedor no tiene tickets.',
                  onStatusTap: sorted.isEmpty
                      ? null
                      : (status) => setState(() {
                          if (_statusFilters.contains(status)) {
                            _statusFilters.remove(status);
                          } else {
                            _statusFilters.add(status);
                          }
                        }),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Rendición',
                  child: fullTickets.isEmpty && profitTickets.isEmpty
                      ? const Text(
                          'Todavía no rindió tickets.',
                          style: TextStyle(color: AppColors.textMuted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (fullTickets.isNotEmpty) ...[
                              _SettleSummaryRow(
                                label:
                                    'Rendido completo (${fullTickets.length})',
                                amount: formatMoney(fullSettledTotal),
                                style: collectorFilterStyle(
                                  validated: false,
                                  fullSettle: true,
                                  profitSettle: false,
                                ),
                              ),
                              if (profitTickets.isNotEmpty)
                                const SizedBox(height: 8),
                            ],
                            if (profitTickets.isNotEmpty)
                              _SettleSummaryRow(
                                label:
                                    'Solo ganancia (${profitTickets.length})',
                                amount: formatMoney(profitSettledTotal),
                                style: collectorFilterStyle(
                                  validated: false,
                                  fullSettle: false,
                                  profitSettle: true,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
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
                    if (selectableTickets.isNotEmpty) ...[
                      if (_selectionMode) ...[
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (allVisibleSelected) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds
                                  ..clear()
                                  ..addAll(selectableTickets.map((t) => t.id));
                              }
                            });
                          },
                          child: Text(allVisibleSelected ? 'Ninguno' : 'Todos'),
                        ),
                        TextButton(
                          onPressed: _exitSelection,
                          child: const Text('Cancelar'),
                        ),
                      ] else
                        TextButton(
                          onPressed: () => _enterSelection(),
                          child: const Text('Seleccionar'),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (sorted.isEmpty)
                  const Text(
                    'Este vendedor no tiene tickets.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else if (visible.isEmpty)
                  const Text(
                    'Ningún ticket con esos estados.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else
                  for (final ticket in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TicketListCard(
                        ticket: ticket,
                        event: event,
                        readOnly: true,
                        selectionMode: _selectionMode,
                        selectable: !event.isReadOnly &&
                            _isSettleable(ticket.status),
                        selected: _selectedIds.contains(ticket.id),
                        onToggleSelect: () {
                          if (!_isSettleable(ticket.status)) return;
                          if (!_selectionMode) {
                            _enterSelection(ticket);
                          } else {
                            _toggleSelected(ticket);
                          }
                        },
                        onLongPress: event.isReadOnly ||
                                !_isSettleable(ticket.status)
                            ? null
                            : () {
                                if (!_selectionMode) {
                                  _enterSelection(ticket);
                                } else {
                                  _toggleSelected(ticket);
                                }
                              },
                      ),
                    ),
              ],
            ),
          ),
          if (showBar)
            TicketSelectionBar(
              selectedCount: selectedTickets.length,
              primaryLabel: selectedToSettle.isEmpty
                  ? 'Rendir'
                  : selectedToSettle.length == selectedTickets.length
                  ? 'Rendir (${selectedToSettle.length})'
                  : 'Rendir (${selectedToSettle.length} de ${selectedTickets.length})',
              onPrimary: selectedToSettle.isEmpty
                  ? null
                  : () => _settleSelected(
                      event: event,
                      selected: selectedTickets,
                      eligible: selectedToSettle,
                    ),
              onClear: _exitSelection,
            ),
        ],
      ),
    );
  }

  Future<void> _settleSelected({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
  }) async {
    if (eligible.isEmpty) return;
    final fullAmount = event.ticketPrice;
    final profitAmount = event.ticketProfit;
    final mode = await showDialog<TicketSettleMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Qué rinde el vendedor?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              eligible.length == selected.length
                  ? 'Vas a rendir ${eligible.length} ticket'
                        '${eligible.length == 1 ? '' : 's'} '
                        '(quedan como vendidos).'
                  : 'Vas a rendir ${eligible.length} de ${selected.length}. '
                        'Se omiten los que ya están rendidos.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, TicketSettleMode.full),
              child: Text(
                'Ticket completo · '
                '\$${(eligible.length * fullAmount).toStringAsFixed(0)}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, TicketSettleMode.profit),
              child: Text(
                'Solo ganancia · '
                '\$${(eligible.length * profitAmount).toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    try {
      await settleTicketsAction(
        ref,
        eventId: event.id,
        ticketIds: eligible.map((t) => t.id),
        collectorId: widget.actorId,
        settleMode: mode,
        actorRole: widget.actorRole,
      );
      if (!mounted) return;
      _exitSelection();
      final unit = event.amountForSettleMode(mode);
      AppSnackBar.success(
        context,
        'Rendiste ${eligible.length} tickets '
        '(${mode.label.toLowerCase()} · '
        '\$${(eligible.length * unit).toStringAsFixed(0)}).',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }
}

class _SettleSummaryRow extends StatelessWidget {
  const _SettleSummaryRow({
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

class _CollectorSellerCard extends StatelessWidget {
  const _CollectorSellerCard({
    required this.seller,
    required this.tickets,
    required this.onTap,
  });

  final Collaborator seller;
  final List<Ticket> tickets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (seller.notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        seller.notes,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TicketStatusSummary(tickets: tickets),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
