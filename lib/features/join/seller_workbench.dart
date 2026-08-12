import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/ticket_pdf.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';
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
  });

  final String eventId;
  final String actorId;
  final String actorLabel;
  final String actorRole;
  final bool showLogout;

  /// When set, skips the seller picker (collaborator portal).
  final String? lockedSellerId;

  @override
  ConsumerState<SellerWorkbench> createState() => _SellerWorkbenchState();
}

class _SellerWorkbenchState extends ConsumerState<SellerWorkbench> {
  Collaborator? _selectedSeller;
  final Set<String> _selectedIds = {};
  final Set<TicketStatus> _statusFilters = {};

  bool get _isOrganizerSelf =>
      widget.actorRole == 'organizer' &&
      widget.lockedSellerId != null &&
      widget.lockedSellerId == widget.actorId;

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
        return const Scaffold(
          body: Center(child: Text('Vendedor no encontrado.')),
        );
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
      hasSellers: sellers.isNotEmpty,
    );
  }

  Widget _buildSellerPicker(
    BuildContext context, {
    required Event event,
    required List<Collaborator> sellers,
    required List<Ticket> allTickets,
  }) {
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
                  }),
                ),
              ),
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
    required bool hasSellers,
  }) {
    final sellerNames = {
      for (final s in sellers) s.id: s.name,
    };

    bool isOperable(Ticket ticket) {
      if (!canSelfAssign) return true;
      // Organizer overview: only sell pool tickets or ones already claimed
      // by the organizer — never mutate another seller's stock.
      if (ticket.status.isAssignablePool) return true;
      return ticket.sellerId == sellerId;
    }

    String? assignedSellerLabel(Ticket ticket) {
      if (!canSelfAssign) return null;
      final id = ticket.sellerId;
      if (id == null || id == sellerId || ticket.status.isAssignablePool) {
        return null;
      }
      return sellerNames[id] ?? 'Vendedor';
    }

    final sorted = [...tickets]
      ..sort((a, b) => a.number.compareTo(b.number));
    final visible = _statusFilters.isEmpty
        ? sorted
        : sorted
            .where((t) => _statusFilters.contains(t.status))
            .toList(growable: false);
    final selectableTickets = visible
        .where(
          (t) =>
              isOperable(t) &&
              (t.status.isSellable || t.status == TicketStatus.collected),
        )
        .toList(growable: false);
    final selectedTickets = selectableTickets
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final hasSelection = selectedTickets.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(sellerName),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedSeller = null;
                  _selectedIds.clear();
                  _statusFilters.clear();
                }),
              )
            : null,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canSelfAssign
                      ? 'Todos los tickets'
                      : (widget.actorRole == 'organizer'
                          ? 'Tickets de $sellerName'
                          : 'Tus tickets para vender'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!canSelfAssign && sorted.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    compactTicketNumbersLabel(sorted.map((t) => t.number)),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TicketStatusSummary(
                    tickets: sorted,
                    selected: _statusFilters,
                    includePoolStatuses: canSelfAssign,
                    onStatusTap: (status) => setState(() {
                      if (_statusFilters.contains(status)) {
                        _statusFilters.remove(status);
                      } else {
                        _statusFilters.add(status);
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
                child: OutlinedButton.icon(
                  onPressed: !hasSelection
                      ? null
                      : () => _printTickets(context, event, selectedTickets),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(
                    hasSelection
                        ? 'Imprimir lote (${selectedTickets.length})'
                        : 'Imprimir lote',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !hasSelection
                      ? null
                      : () => _whatsappTickets(context, event, selectedTickets),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(
                    hasSelection
                        ? 'WhatsApp (${selectedTickets.length})'
                        : 'WhatsApp',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                  onPressed: () => setState(_statusFilters.clear),
                  child: const Text('Ver todos'),
                ),
              if (selectableTickets.isNotEmpty) ...[
                TextButton(
                  onPressed: () => setState(() {
                    _selectedIds
                      ..clear()
                      ..addAll(selectableTickets.map((t) => t.id));
                  }),
                  child: const Text('Todos'),
                ),
                TextButton(
                  onPressed: hasSelection
                      ? () => setState(_selectedIds.clear)
                      : null,
                  child: const Text('Ninguno'),
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
                child: _SellerTicketCard(
                  ticket: ticket,
                  event: event,
                  selected: selectableTickets.any((t) => t.id == ticket.id) &&
                      _selectedIds.contains(ticket.id),
                  selectionEnabled:
                      selectableTickets.any((t) => t.id == ticket.id),
                  showUnassignedStatus: hasSellers,
                  assignedSellerLabel: assignedSellerLabel(ticket),
                  canReserve: isOperable(ticket) &&
                      ticket.status.isSellable &&
                      ticket.status != TicketStatus.reserved,
                  canCollect:
                      isOperable(ticket) && ticket.status.isSellable,
                  canClearReservation: isOperable(ticket) &&
                      ticket.status == TicketStatus.reserved,
                  canShare: true,
                  onToggleSelect:
                      selectableTickets.any((t) => t.id == ticket.id)
                          ? () => setState(() {
                              if (_selectedIds.contains(ticket.id)) {
                                _selectedIds.remove(ticket.id);
                              } else {
                                _selectedIds.add(ticket.id);
                              }
                            })
                          : null,
                  onReserve: () => _reserveTicket(
                    context,
                    event: event,
                    sellerId: sellerId,
                    ticket: ticket,
                  ),
                  onCollect: () => _collectTicket(
                    context,
                    event: event,
                    sellerId: sellerId,
                    ticket: ticket,
                  ),
                  onClearReservation: () => _clearReservation(
                    context,
                    event: event,
                    ticket: ticket,
                    returnToPool: canSelfAssign,
                  ),
                  clearReservationTooltip: canSelfAssign
                      ? 'Devolver al pool'
                      : 'Liberar reserva',
                  onWhatsApp: () => _whatsappTickets(context, event, [ticket]),
                  onPrint: () => _printTickets(context, event, [ticket]),
                ),
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _printTickets(
    BuildContext context,
    Event event,
    List<Ticket> tickets,
  ) async {
    final details = await _askShareDetails(
      context,
      title: tickets.length == 1
          ? 'Imprimir ticket #${tickets.first.number}'
          : 'Imprimir ${tickets.length} tickets',
      askPhone: false,
      initialBuyerName: _sharedBuyerHint(tickets),
      confirmLabel: 'Imprimir',
    );
    if (details == null || !context.mounted) return;

    final toPrint = await _applyOptionalBuyer(
      context,
      event: event,
      tickets: tickets,
      buyerName: details.buyerName,
    );
    if (toPrint == null || !context.mounted) return;

    try {
      await TicketPdf.printTickets(event: event, tickets: toPrint);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $e')),
      );
    }
  }

  Future<void> _whatsappTickets(
    BuildContext context,
    Event event,
    List<Ticket> tickets,
  ) async {
    final details = await _askShareDetails(
      context,
      title: tickets.length == 1
          ? 'WhatsApp ticket #${tickets.first.number}'
          : 'WhatsApp ${tickets.length} tickets',
      askPhone: true,
      initialBuyerName: _sharedBuyerHint(tickets),
      confirmLabel: 'Generar e ir a WhatsApp',
    );
    if (details == null || !context.mounted) return;

    final toShare = await _applyOptionalBuyer(
      context,
      event: event,
      tickets: tickets,
      buyerName: details.buyerName,
    );
    if (toShare == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Elegí WhatsApp y enviá a ${details.phone}. Solo van las imágenes.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    try {
      await TicketShare.shareImages(
        context,
        tickets: toShare,
        event: event,
        style: event.ticketDesign,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron generar las imágenes: $e')),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return null;
    }
  }

  Future<_ShareDetails?> _askShareDetails(
    BuildContext context, {
    required String title,
    required bool askPhone,
    String initialBuyerName = '',
    String confirmLabel = 'Continuar',
  }) {
    return showModalBottomSheet<_ShareDetails>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final buyerController =
            TextEditingController(text: initialBuyerName);
        final phoneController = TextEditingController();
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
              if (askPhone) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: '11 2345-6789',
                    helperText: 'Sin 0 ni código de país',
                    prefixText: '+549 ',
                    prefixStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontSize: 16,
                    ),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  String phone = '';
                  if (askPhone) {
                    final normalized = TicketShare.normalizeWhatsAppPhone(
                      phoneController.text,
                    );
                    if (normalized == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ingresá un número válido (ej. 11 2345-6789).',
                          ),
                        ),
                      );
                      return;
                    }
                    phone = TicketShare.formatWhatsAppPhone(normalized);
                  }
                  Navigator.pop(
                    sheetContext,
                    _ShareDetails(
                      buyerName: buyerController.text.trim(),
                      phone: phone,
                    ),
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
  const _ShareDetails({
    required this.buyerName,
    this.phone = '',
  });

  final String buyerName;
  final String phone;
}

class _SellerTicketCard extends StatelessWidget {
  const _SellerTicketCard({
    required this.ticket,
    required this.event,
    required this.selected,
    required this.selectionEnabled,
    required this.showUnassignedStatus,
    required this.canReserve,
    required this.canCollect,
    required this.canClearReservation,
    required this.canShare,
    required this.onReserve,
    required this.onCollect,
    required this.onClearReservation,
    required this.onWhatsApp,
    required this.onPrint,
    this.onToggleSelect,
    this.clearReservationTooltip = 'Liberar reserva',
    this.assignedSellerLabel,
  });

  final Ticket ticket;
  final Event event;
  final bool selected;
  final bool selectionEnabled;
  final bool showUnassignedStatus;
  final bool canReserve;
  final bool canCollect;
  final bool canClearReservation;
  final bool canShare;
  final VoidCallback? onToggleSelect;
  final VoidCallback onReserve;
  final VoidCallback onCollect;
  final VoidCallback onClearReservation;
  final VoidCallback onWhatsApp;
  final VoidCallback onPrint;
  final String clearReservationTooltip;
  final String? assignedSellerLabel;

  @override
  Widget build(BuildContext context) {
    final buyer = ticket.buyerName.trim();
    final sellerLabel = assignedSellerLabel?.trim() ?? '';
    final showStatus = ticket.status != TicketStatus.unassigned ||
        showUnassignedStatus;

    return Material(
      color: AppColors.card,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged:
                      selectionEnabled ? (_) => onToggleSelect?.call() : null,
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleSelect,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Ticket #${ticket.number}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (showStatus) ...[
                              const SizedBox(width: 8),
                              StatusBadge(
                                label: ticket.status.label,
                                tone: ticketStatusTone(ticket.status),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${event.ticketPrice.toStringAsFixed(0)} · ${event.product}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (sellerLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Vendedor: $sellerLabel',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (buyer.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Para: $buyer',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (canShare) ...[
                  IconButton(
                    tooltip: 'WhatsApp',
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Imprimir',
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            if (canReserve || canCollect || canClearReservation) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canReserve)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReserve,
                        child: const Text('Reservar'),
                      ),
                    ),
                  if (canReserve && canCollect) const SizedBox(width: 8),
                  if (canCollect)
                    Expanded(
                      child: FilledButton(
                        onPressed: onCollect,
                        child: const Text('Cobrar'),
                      ),
                    ),
                  if (canClearReservation) ...[
                    if (canCollect) const SizedBox(width: 8),
                    IconButton(
                      tooltip: clearReservationTooltip,
                      onPressed: onClearReservation,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
