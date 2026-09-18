import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/ticket_pdf.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/busy_dialog.dart';
import '../../shared/widgets/event_details_card.dart';
import '../../shared/widgets/logout_icon_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/ticket_list_card.dart';
import '../../shared/widgets/ticket_selection_bar.dart';
import '../../shared/widgets/ticket_share.dart';

/// Shared sell UI for the seller portal and the organizer workspace.
///
/// If [lockedSellerId] is set, shows that seller's tickets directly
/// (portal = collaborator id, organizer self-sell = owner uid).
/// If null, first pick a seller, then operate their tickets.
class SellerWorkbench extends ConsumerStatefulWidget {
  const SellerWorkbench({
    super.key,
    required this.eventId,
    required this.actorId,
    required this.actorLabel,
    this.actorRole = 'seller',
    this.showLogout = false,
    this.lockedSellerId,
    this.embedded = false,
  });

  final String eventId;
  final String actorId;
  final String actorLabel;
  final String actorRole;
  final bool showLogout;

  /// When set, skips the seller picker (collaborator portal).
  final String? lockedSellerId;

  /// When true, renders without its own [Scaffold]/[AppBar] (workspace tab).
  final bool embedded;

  @override
  ConsumerState<SellerWorkbench> createState() => _SellerWorkbenchState();
}

class _SellerWorkbenchState extends ConsumerState<SellerWorkbench> {
  Collaborator? _selectedSeller;
  final Set<String> _selectedIds = {};
  final Set<TicketStatus> _statusFilters = {};
  bool _selectionMode = false;

  bool get _isOrganizerSelf =>
      widget.actorRole == 'organizer' &&
      widget.lockedSellerId != null &&
      widget.lockedSellerId == widget.actorId;

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
      return _wrap(const Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || sellersAsync.hasError || ticketsAsync.hasError) {
      return _wrap(
        Center(
          child: Text(
            '${eventAsync.error ?? sellersAsync.error ?? ticketsAsync.error}',
          ),
        ),
      );
    }

    final event = eventAsync.requireValue;
    final sellers = sellersAsync.requireValue;
    final allTickets = ticketsAsync.requireValue;

    final lockedId = widget.lockedSellerId;
    String? sellerId;
    var sellerName = widget.actorLabel;

    if (lockedId != null) {
      Collaborator? found;
      for (final s in sellers) {
        if (s.id == lockedId) {
          found = s;
          break;
        }
      }
      if (found != null) {
        sellerId = found.id;
        sellerName = found.name;
      } else if (_isOrganizerSelf) {
        sellerId = lockedId;
        sellerName = widget.actorLabel;
      } else {
        return _wrap(const Center(child: Text('Vendedor no encontrado.')));
      }
    } else if (_selectedSeller != null) {
      final s = _selectedSeller!;
      sellerId = s.id;
      sellerName = s.name;
    }

    if (sellerId == null) {
      return _buildSellerPicker(
        context,
        event: event,
        sellers: sellers,
        allTickets: allTickets,
      );
    }

    return _buildSellerTickets(
      context,
      event: event,
      sellerId: sellerId,
      sellerName: sellerName,
      tickets: _isOrganizerSelf
          ? allTickets
          : allTickets.where((t) => t.sellerId == sellerId).toList(),
      sellers: sellers,
      canGoBack: lockedId == null,
      canSelfAssign: _isOrganizerSelf,
    );
  }

  Widget _wrap(Widget body, {PreferredSizeWidget? appBar}) {
    if (widget.embedded) return body;
    return Scaffold(appBar: appBar, body: body);
  }

  Widget _buildSellerPicker(
    BuildContext context, {
    required Event event,
    required List<Collaborator> sellers,
    required List<Ticket> allTickets,
  }) {
    return _wrap(
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Text(
              widget.actorRole == 'organizer'
                  ? 'Estás vendiendo como organizador. Elegí un vendedor '
                        'para reservar o cobrar sus tickets.'
                  : 'Elegí un vendedor.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vendedores', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (sellers.isEmpty)
            const Text(
              'Todavía no hay vendedores. Creá uno y asignale tickets.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final s in sellers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      () {
                        final sellerTickets = allTickets
                            .where((t) => t.sellerId == s.id)
                            .toList();
                        if (sellerTickets.isEmpty) return 'Sin tickets';
                        return compactTicketNumbersLabel(
                          sellerTickets.map((t) => t.number),
                        );
                      }(),
                      '${allTickets.where((t) => t.sellerId == s.id && t.status == TicketStatus.withSeller).length} para cobrar',
                      '${allTickets.where((t) => t.sellerId == s.id && t.status == TicketStatus.reserved).length} reservados',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() {
                    _selectedSeller = s;
                    _selectedIds.clear();
                    _selectionMode = false;
                    _statusFilters.clear();
                  }),
                ),
              ),
        ],
      ),
      appBar: AppBar(
        title: Text(widget.actorLabel),
        actions: [
          if (widget.showLogout) const LogoutIconButton(),
        ],
      ),
    );
  }

  Widget _buildSellerTickets(
    BuildContext context, {
    required Event event,
    required String sellerId,
    required String sellerName,
    required List<Ticket> tickets,
    required List<Collaborator> sellers,
    required bool canGoBack,
    required bool canSelfAssign,
  }) {
    final sellerNames = {for (final s in sellers) s.id: s.name};
    if (canSelfAssign) {
      sellerNames[sellerId] = sellerName;
    }

    bool isOperable(Ticket ticket) {
      if (event.isReadOnly) return false;
      if (!canSelfAssign) return true;
      // Organizer sees all event tickets and can sell on any of them.
      return true;
    }

    String sellerIdFor(Ticket ticket) {
      final assigned = ticket.sellerId;
      if (assigned != null &&
          assigned.isNotEmpty &&
          !ticket.status.isAssignablePool) {
        return assigned;
      }
      return sellerId;
    }

    bool clearReservationReturnsToPool(Ticket ticket) {
      if (!canSelfAssign) return false;
      final assigned = ticket.sellerId;
      return assigned == null || assigned.isEmpty || assigned == sellerId;
    }

    String? assignedSellerLabel(Ticket ticket) {
      if (!canSelfAssign) return null;
      final id = ticket.sellerId;
      if (id == null || id == sellerId || ticket.status.isAssignablePool) {
        return null;
      }
      return sellerNames[id] ?? 'Vendedor';
    }

    final sorted = [...tickets]..sort((a, b) => a.number.compareTo(b.number));
    final visible = _statusFilters.isEmpty
        ? sorted
        : sorted
              .where((t) => _statusFilters.contains(t.status))
              .toList(growable: false);
    final selectableTickets = event.isReadOnly ? const <Ticket>[] : visible;
    final selectedTickets = selectableTickets
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final hasSelection = selectedTickets.isNotEmpty;
    final showBar = !event.isReadOnly && _selectionMode && hasSelection;
    final reservable = selectedTickets
        .where(
          (t) =>
              isOperable(t) &&
              t.status.isSellable &&
              t.status != TicketStatus.reserved,
        )
        .toList(growable: false);
    final collectible = selectedTickets
        .where((t) => isOperable(t) && t.status.isSellable)
        .toList(growable: false);
    final allVisibleSelected =
        selectableTickets.isNotEmpty &&
        selectableTickets.every((t) => _selectedIds.contains(t.id));

    return _wrap(
      Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, showBar ? 8 : 16),
              children: [
                if (!widget.embedded) ...[
                  EventDetailsCard(event: event),
                  const SizedBox(height: 12),
                ],
                TicketStatusCard.summary(
                  tickets: sorted,
                  selected: _statusFilters,
                  includePoolStatuses: canSelfAssign,
                  emptyLabel: canSelfAssign
                      ? 'Todavía no hay tickets en este evento.'
                      : 'Cuando se asigne un rango, los tickets van a aparecer acá.',
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
                                  ..addAll(
                                    selectableTickets.map((t) => t.id),
                                  );
                              }
                            });
                          },
                          child: Text(
                            allVisibleSelected ? 'Ninguno' : 'Todos',
                          ),
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
                  Text(
                    canSelfAssign
                        ? 'Todavía no hay tickets en este evento.'
                        : 'Cuando se asigne un rango, los tickets van a aparecer acá.',
                    style: const TextStyle(color: AppColors.textMuted),
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
                        readOnly: event.isReadOnly || !isOperable(ticket),
                        selectionMode: _selectionMode,
                        selected: _selectedIds.contains(ticket.id),
                        sellerLabel: assignedSellerLabel(ticket),
                        onToggleSelect: () {
                          if (!_selectionMode) {
                            _enterSelection(ticket);
                          } else {
                            _toggleSelected(ticket);
                          }
                        },
                        onLongPress: event.isReadOnly
                            ? null
                            : () {
                                if (!_selectionMode) {
                                  _enterSelection(ticket);
                                } else {
                                  _toggleSelected(ticket);
                                }
                              },
                        onCollect: () => _collectTicket(
                          context,
                          event: event,
                          sellerId: sellerIdFor(ticket),
                          ticket: ticket,
                        ),
                        onReserve: () => _reserveTicket(
                          context,
                          event: event,
                          sellerId: sellerIdFor(ticket),
                          ticket: ticket,
                        ),
                        onSetBuyer: () => _setTicketBuyer(
                          context,
                          event: event,
                          ticket: ticket,
                        ),
                        onClearReservation: () => _clearReservation(
                          context,
                          event: event,
                          ticket: ticket,
                          returnToPool: clearReservationReturnsToPool(ticket),
                        ),
                        clearReservationLabel:
                            clearReservationReturnsToPool(ticket)
                            ? 'Devolver al pool'
                            : 'Liberar reserva',
                        onPrint: () => _printTickets(context, event, [
                          ticket,
                        ], sellerNames: sellerNames),
                        onShare: () => _shareTickets(context, event, [
                          ticket,
                        ], sellerNames: sellerNames),
                      ),
                    ),
              ],
            ),
          ),
          if (showBar)
            TicketSelectionBar(
              selectedCount: selectedTickets.length,
              primaryLabel: collectible.isEmpty
                  ? 'Cobrar'
                  : collectible.length == selectedTickets.length
                  ? 'Cobrar (${collectible.length})'
                  : 'Cobrar (${collectible.length} de ${selectedTickets.length})',
              onPrimary: collectible.isEmpty
                  ? null
                  : () => _bulkCollect(
                      event: event,
                      selected: selectedTickets,
                      eligible: collectible,
                      sellerId: sellerId,
                    ),
              onMore: () => _openBulkMore(
                event: event,
                selected: selectedTickets,
                reservable: reservable,
                sellerIdFor: sellerIdFor,
                sellerNames: sellerNames,
              ),
              onClear: _exitSelection,
            ),
        ],
      ),
      appBar: AppBar(
        title: Text(sellerName),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedSeller = null;
                  _selectedIds.clear();
                  _selectionMode = false;
                  _statusFilters.clear();
                }),
              )
            : null,
        actions: [
          if (widget.showLogout) const LogoutIconButton(),
        ],
      ),
    );
  }

  Future<void> _claimPoolTicketsIfNeeded({
    required String sellerId,
    required List<Ticket> tickets,
  }) async {
    final toClaim = tickets
        .where((t) => t.status.isAssignablePool)
        .map((t) => t.id)
        .toList(growable: false);
    if (toClaim.isEmpty) return;
    await claimTicketsForSellerAction(
      ref,
      eventId: widget.eventId,
      ticketIds: toClaim,
      sellerId: sellerId,
      actorId: widget.actorId,
      actorRole: widget.actorRole,
    );
  }

  Future<void> _reserveTicket(
    BuildContext context, {
    required Event event,
    required String sellerId,
    required Ticket ticket,
  }) async {
    final buyerName = await _askBuyerName(
      context,
      title: 'Reservar ticket #${ticket.number}',
      requiredName: true,
      initialName: ticket.buyerName,
    );
    if (buyerName == null || !context.mounted) return;

    try {
      await reserveTicketsAction(
        ref,
        eventId: event.id,
        ticketIds: [ticket.id],
        buyerName: buyerName,
        sellerId: sellerId,
        actorId: widget.actorId,
        actorRole: widget.actorRole,
      );
      if (!mounted) return;
      setState(() => _selectedIds.remove(ticket.id));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }

  Future<bool> _confirmEligible({
    required String title,
    required String confirmLabel,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String actionVerb,
  }) async {
    if (eligible.isEmpty) {
      AppSnackBar.warning(
        context,
        'Ningún ticket seleccionado se puede $actionVerb.',
      );
      return false;
    }

    final skipped = selected.length - eligible.length;
    final body = skipped == 0
        ? 'Se van a $actionVerb ${eligible.length} '
              'ticket${eligible.length == 1 ? '' : 's'}.'
        : 'Se van a $actionVerb ${eligible.length} de ${selected.length}.\n'
              'Se omiten $skipped que no aplican.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('$confirmLabel (${eligible.length})'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openBulkMore({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> reservable,
    required String Function(Ticket) sellerIdFor,
    required Map<String, String> sellerNames,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    '${selected.length} seleccionados',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  enabled: reservable.isNotEmpty,
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: Text(
                    reservable.isEmpty
                        ? 'Reservar'
                        : reservable.length == selected.length
                        ? 'Reservar (${reservable.length})'
                        : 'Reservar (${reservable.length} de ${selected.length})',
                  ),
                  onTap: reservable.isEmpty
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _bulkReserve(
                            event: event,
                            selected: selected,
                            eligible: reservable,
                            sellerIdFor: sellerIdFor,
                          );
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text('Imprimir (${selected.length})'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _printTickets(
                      context,
                      event,
                      selected,
                      sellerNames: sellerNames,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(AccessShare.shareIcon),
                  title: Text('Compartir (${selected.length})'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareTickets(
                      context,
                      event,
                      selected,
                      sellerNames: sellerNames,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _bulkReserve({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String Function(Ticket) sellerIdFor,
  }) async {
    final ok = await _confirmEligible(
      title: 'Reservar tickets',
      confirmLabel: 'Continuar',
      selected: selected,
      eligible: eligible,
      actionVerb: 'reservar',
    );
    if (!ok || !mounted) return;

    final buyerName = await _askBuyerName(
      context,
      title: 'Destinatario para ${eligible.length} tickets',
      requiredName: true,
      confirmLabel: 'Reservar',
    );
    if (buyerName == null || !mounted) return;

    try {
      await runBusyDialog(
        context,
        message: 'Reservando 0 de ${eligible.length}...',
        work: (setLabel) async {
          for (var i = 0; i < eligible.length; i++) {
            final ticket = eligible[i];
            setLabel('Reservando ${i + 1} de ${eligible.length}...');
            await reserveTicketsAction(
              ref,
              eventId: event.id,
              ticketIds: [ticket.id],
              buyerName: buyerName,
              sellerId: sellerIdFor(ticket),
              actorId: widget.actorId,
              actorRole: widget.actorRole,
            );
          }
        },
      );
      if (!mounted) return;
      _exitSelection();
      AppSnackBar.success(
        context,
        '${eligible.length} ticket${eligible.length == 1 ? '' : 's'} '
        'reservado${eligible.length == 1 ? '' : 's'}.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }

  Future<void> _bulkCollect({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String sellerId,
  }) async {
    final ok = await _confirmEligible(
      title: 'Cobrar tickets',
      confirmLabel: 'Cobrar',
      selected: selected,
      eligible: eligible,
      actionVerb: 'cobrar',
    );
    if (!ok || !mounted) return;

    try {
      await runBusyDialog(
        context,
        message: 'Cobrando ${eligible.length} tickets...',
        work: (_) async {
          await _claimPoolTicketsIfNeeded(sellerId: sellerId, tickets: eligible);
          await collectTicketsAction(
            ref,
            eventId: event.id,
            ticketIds: eligible.map((t) => t.id),
            actorId: widget.actorId,
            actorRole: widget.actorRole,
          );
        },
      );
      if (!mounted) return;
      _exitSelection();
      AppSnackBar.success(
        context,
        '${eligible.length} ticket${eligible.length == 1 ? '' : 's'} '
        'cobrado${eligible.length == 1 ? '' : 's'}.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }

  Future<void> _collectTicket(
    BuildContext context, {
    required Event event,
    required String sellerId,
    required Ticket ticket,
  }) async {
    String? buyerName = ticket.buyerName.trim().isEmpty
        ? null
        : ticket.buyerName.trim();

    if (buyerName == null) {
      final result = await _askBuyerName(
        context,
        title: 'Cobrar ticket #${ticket.number}',
        requiredName: false,
        initialName: '',
        confirmLabel: 'Cobrar',
      );
      if (result == null || !context.mounted) return;
      buyerName = result.trim().isEmpty ? null : result.trim();
    }

    try {
      await _claimPoolTicketsIfNeeded(sellerId: sellerId, tickets: [ticket]);
      await collectTicketsAction(
        ref,
        eventId: event.id,
        ticketIds: [ticket.id],
        actorId: widget.actorId,
        actorRole: widget.actorRole,
        buyerName: buyerName,
      );
      if (!mounted) return;
      setState(() => _selectedIds.remove(ticket.id));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }

  Future<void> _setTicketBuyer(
    BuildContext context, {
    required Event event,
    required Ticket ticket,
  }) async {
    final hasBuyer = ticket.buyerName.trim().isNotEmpty;
    final result = await _askBuyerName(
      context,
      title: hasBuyer
          ? 'Editar destinatario · ticket #${ticket.number}'
          : 'Destinatario · ticket #${ticket.number}',
      requiredName: false,
      initialName: ticket.buyerName,
      confirmLabel: 'Guardar',
    );
    if (result == null || !context.mounted) return;

    try {
      await setTicketsBuyerAction(
        ref,
        eventId: event.id,
        ticketIds: [ticket.id],
        buyerName: result,
        actorId: widget.actorId,
        actorRole: widget.actorRole,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }

  Future<void> _clearReservation(
    BuildContext context, {
    required Event event,
    required Ticket ticket,
    required bool returnToPool,
  }) async {
    try {
      if (returnToPool) {
        // Organizer selling from the pool: undoing a reserve puts the ticket
        // back in the free pool, not "with seller" (confusing for self-sell).
        await returnTicketsToPoolAction(
          ref,
          eventId: event.id,
          ticketIds: [ticket.id],
          actorId: widget.actorId,
          actorRole: widget.actorRole,
        );
      } else {
        await clearTicketReservationsAction(
          ref,
          eventId: event.id,
          ticketIds: [ticket.id],
          actorId: widget.actorId,
          actorRole: widget.actorRole,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, '$e', cause: e);
    }
  }

  Future<void> _printTickets(
    BuildContext context,
    Event event,
    List<Ticket> tickets, {
    Map<String, String> sellerNames = const {},
  }) async {
    final toPrint = await _prepareTicketsForExport(
      context,
      event: event,
      tickets: tickets,
      singleTitle: 'Imprimir ticket #${tickets.first.number}',
      confirmLabel: 'Imprimir',
    );
    if (toPrint == null || !context.mounted) return;

    if (!context.mounted) return;
    var progress = 0;
    final total = toPrint.length;
    void Function(void Function())? setDialogState;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) {
          setDialogState = setState;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    total <= 1
                        ? 'Generando PDF...'
                        : 'Generando PDF... $progress de $total',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      await TicketPdf.downloadTickets(
        event: event,
        tickets: toPrint,
        style: event.ticketDesign,
        sellerNames: sellerNames,
        onProgress: (done, count) {
          progress = done;
          setDialogState?.call(() {});
        },
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(context, 'PDF listo. Elegí dónde guardarlo.');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.error(context, 'No se pudo generar el PDF: $e', cause: e);
    }
  }

  Future<void> _shareTickets(
    BuildContext context,
    Event event,
    List<Ticket> tickets, {
    Map<String, String> sellerNames = const {},
  }) async {
    final toShare = await _prepareTicketsForExport(
      context,
      event: event,
      tickets: tickets,
      singleTitle: 'Compartir ticket #${tickets.first.number}',
      confirmLabel: 'Compartir',
    );
    if (toShare == null || !context.mounted) return;

    try {
      await TicketShare.shareImages(
        context,
        tickets: toShare,
        event: event,
        style: event.ticketDesign,
        sellerNames: sellerNames,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(
        context,
        'No se pudieron generar las imágenes: $e',
        cause: e,
      );
    }
  }

  /// Single ticket: optional destinatario. Several tickets: keep each as-is.
  Future<List<Ticket>?> _prepareTicketsForExport(
    BuildContext context, {
    required Event event,
    required List<Ticket> tickets,
    required String singleTitle,
    required String confirmLabel,
  }) async {
    if (tickets.length != 1) return tickets;

    final details = await _askShareDetails(
      context,
      title: singleTitle,
      initialBuyerName: _sharedBuyerHint(tickets),
      confirmLabel: confirmLabel,
    );
    if (details == null || !context.mounted) return null;

    return _applyOptionalBuyer(
      context,
      event: event,
      tickets: tickets,
      buyerName: details.buyerName,
    );
  }

  String _sharedBuyerHint(List<Ticket> tickets) {
    final names = tickets
        .map((t) => t.buyerName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    return names.length == 1 ? names.first : '';
  }

  /// Persists optional buyer when provided; returns tickets ready to share/print.
  Future<List<Ticket>?> _applyOptionalBuyer(
    BuildContext context, {
    required Event event,
    required List<Ticket> tickets,
    required String buyerName,
  }) async {
    final name = buyerName.trim();
    if (name.isEmpty) return tickets;

    try {
      await setTicketsBuyerAction(
        ref,
        eventId: event.id,
        ticketIds: tickets.map((t) => t.id),
        buyerName: name,
        actorId: widget.actorId,
        actorRole: widget.actorRole,
      );
      return [
        for (final ticket in tickets)
          Ticket(
            id: ticket.id,
            eventId: ticket.eventId,
            number: ticket.number,
            status: ticket.status,
            sellerId: ticket.sellerId,
            validatorId: ticket.validatorId,
            collectorId: ticket.collectorId,
            assignedByCollaboratorId: ticket.assignedByCollaboratorId,
            buyerName: name,
            settleMode: ticket.settleMode,
            settledAmount: ticket.settledAmount,
            history: ticket.history,
          ),
      ];
    } catch (e) {
      if (!context.mounted) return null;
      AppSnackBar.error(context, '$e', cause: e);
      return null;
    }
  }

  Future<_ShareDetails?> _askShareDetails(
    BuildContext context, {
    required String title,
    String initialBuyerName = '',
    String confirmLabel = 'Continuar',
  }) {
    return showModalBottomSheet<_ShareDetails>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final buyerController = TextEditingController(text: initialBuyerName);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: buyerController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Destinatario (opcional)',
                  hintText: 'Ej. Juan Pérez',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    sheetContext,
                    _ShareDetails(buyerName: buyerController.text.trim()),
                  );
                },
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askBuyerName(
    BuildContext context, {
    required String title,
    required bool requiredName,
    String initialName = '',
    String confirmLabel = 'Confirmar',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final controller = TextEditingController(text: initialName);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: requiredName
                      ? 'Destinatario'
                      : 'Destinatario (opcional)',
                  hintText: 'Ej. Juan Pérez',
                  isDense: true,
                ),
                onSubmitted: (value) {
                  final name = value.trim();
                  if (requiredName && name.isEmpty) return;
                  Navigator.pop(sheetContext, name);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (requiredName && name.isEmpty) return;
                  Navigator.pop(sheetContext, name);
                },
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShareDetails {
  const _ShareDetails({required this.buyerName});

  final String buyerName;
}
