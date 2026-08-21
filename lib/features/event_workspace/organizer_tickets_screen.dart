import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/ticket_pdf.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/busy_dialog.dart';
import '../../shared/widgets/ticket_share.dart';
import '../../shared/widgets/ticket_status_style.dart';

/// Organizer ticket hub: individual cards + multi-select bulk actions.
class OrganizerTicketsScreen extends ConsumerStatefulWidget {
  const OrganizerTicketsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<OrganizerTicketsScreen> createState() =>
      _OrganizerTicketsScreenState();
}

class _OrganizerTicketsScreenState
    extends ConsumerState<OrganizerTicketsScreen> {
  final Set<TicketStatus> _statusFilters = {};
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

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
    final session = ref.watch(sessionProvider);
    final uid = session.userUid;
    if (uid == null) {
      return const Center(child: Text('Tenés que iniciar sesión.'));
    }

    final eventAsync = ref.watch(eventProvider(widget.eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(widget.eventId));
    final sellersAsync = ref.watch(eventSellersProvider(widget.eventId));

    if (eventAsync.isLoading ||
        ticketsAsync.isLoading ||
        sellersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eventAsync.hasError ||
        ticketsAsync.hasError ||
        sellersAsync.hasError) {
      return Center(
        child: Text(
          '${eventAsync.error ?? ticketsAsync.error ?? sellersAsync.error}',
        ),
      );
    }

    final event = eventAsync.requireValue;
    final tickets = ticketsAsync.requireValue;
    final sellers = sellersAsync.requireValue;
    final organizerName = (session.displayName?.trim().isNotEmpty ?? false)
        ? session.displayName!.trim()
        : 'Organizador';

    final sellerNames = <String, String>{
      for (final s in sellers) s.id: s.name,
      uid: organizerName,
    };

    final sorted = [...tickets]..sort((a, b) => a.number.compareTo(b.number));
    final visible = _statusFilters.isEmpty
        ? sorted
        : sorted
            .where((t) => _statusFilters.contains(t.status))
            .toList(growable: false);

    final selectedTickets = visible
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final showBar =
        !event.isReadOnly && _selectionMode && selectedTickets.isNotEmpty;

    final collectible =
        selectedTickets.where((t) => t.status.isSellable).toList();
    final reservable = selectedTickets
        .where(
          (t) =>
              t.status.isSellable && t.status != TicketStatus.reserved,
        )
        .toList();
    final assignable = selectedTickets
        .where(
          (t) =>
              t.status.isAssignablePool ||
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.reserved,
        )
        .toList();
    final returnable = selectedTickets
        .where(
          (t) =>
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.reserved,
        )
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, showBar ? 8 : 16),
            children: [
              TicketStatusCard.summary(
                tickets: sorted,
                selected: _statusFilters,
                includePoolStatuses: true,
                emptyLabel: 'Todavía no hay tickets en este evento.',
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
                  if (_statusFilters.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_statusFilters.clear),
                      child: const Text('Ver todos'),
                    ),
                  if (!event.isReadOnly && visible.isNotEmpty) ...[
                    if (_selectionMode) ...[
                      TextButton(
                        onPressed: () {
                          final allSelected = visible.isNotEmpty &&
                              visible.every((t) => _selectedIds.contains(t.id));
                          setState(() {
                            if (allSelected) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds
                                ..clear()
                                ..addAll(visible.map((t) => t.id));
                            }
                          });
                        },
                        child: Text(
                          visible.isNotEmpty &&
                                  visible.every(
                                    (t) => _selectedIds.contains(t.id),
                                  )
                              ? 'Ninguno'
                              : 'Todos',
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
                const Text(
                  'Todavía no hay tickets en este evento.',
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
                    child: _OrganizerTicketCard(
                      ticket: ticket,
                      event: event,
                      readOnly: event.isReadOnly,
                      selectionMode: _selectionMode,
                      selected: _selectedIds.contains(ticket.id),
                      sellerLabel: _sellerLabel(ticket, sellerNames, uid),
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
                      onCollect: () => _collect(
                        event: event,
                        ticket: ticket,
                        organizerId: uid,
                      ),
                      onReserve: () => _reserve(
                        event: event,
                        ticket: ticket,
                        organizerId: uid,
                      ),
                      onSetBuyer: () =>
                          _setBuyer(event: event, ticket: ticket),
                      onAssignSeller: () => _assignSeller(
                        event: event,
                        ticket: ticket,
                        sellers: sellers,
                        organizerId: uid,
                        organizerName: organizerName,
                      ),
                      onClearReservation: () => _clearReservation(
                        event: event,
                        ticket: ticket,
                        organizerId: uid,
                      ),
                      onReturnToPool: () => _returnToPool(
                        event: event,
                        ticket: ticket,
                      ),
                      onPrint: () => _printTickets(
                        event: event,
                        tickets: [ticket],
                        sellerNames: sellerNames,
                      ),
                      onShare: () => _shareTickets(
                        event: event,
                        tickets: [ticket],
                        sellerNames: sellerNames,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (showBar)
          _BulkActionBar(
            selectedCount: selectedTickets.length,
            collectibleCount: collectible.length,
            onCollect: collectible.isEmpty
                ? null
                : () => _bulkCollect(
                      event: event,
                      selected: selectedTickets,
                      eligible: collectible,
                      organizerId: uid,
                    ),
            onMore: () => _openBulkMore(
              event: event,
              selected: selectedTickets,
              reservable: reservable,
              assignable: assignable,
              returnable: returnable,
              sellers: sellers,
              organizerId: uid,
              organizerName: organizerName,
              sellerNames: sellerNames,
            ),
            onClear: _exitSelection,
          ),
      ],
    );
  }

  String? _sellerLabel(
    Ticket ticket,
    Map<String, String> sellerNames,
    String organizerId,
  ) {
    if (ticket.status.isAssignablePool) return null;
    final id = ticket.sellerId?.trim();
    if (id == null || id.isEmpty) return null;
    if (id == organizerId) return sellerNames[id] ?? 'Organizador';
    return sellerNames[id] ?? 'Vendedor';
  }

  String _sellerIdFor(Ticket ticket, String organizerId) {
    final assigned = ticket.sellerId;
    if (assigned != null &&
        assigned.isNotEmpty &&
        !ticket.status.isAssignablePool) {
      return assigned;
    }
    return organizerId;
  }

  Future<bool> _confirmEligible({
    required String title,
    required String confirmLabel,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String actionVerb,
  }) async {
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ningún ticket seleccionado se puede $actionVerb.')),
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

  /// Blocking progress dialog for bulk / multi-step writes.
  Future<T?> _runBusy<T>({
    required String message,
    required Future<T> Function(void Function(String label) setLabel) work,
  }) {
    return runBusyDialog(context, message: message, work: work);
  }

  Future<void> _openBulkMore({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> reservable,
    required List<Ticket> assignable,
    required List<Ticket> returnable,
    required List<Collaborator> sellers,
    required String organizerId,
    required String organizerName,
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
                            organizerId: organizerId,
                          );
                        },
                ),
                ListTile(
                  enabled: assignable.isNotEmpty,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(
                    assignable.isEmpty
                        ? 'Asignar vendedor'
                        : assignable.length == selected.length
                            ? 'Asignar vendedor (${assignable.length})'
                            : 'Asignar vendedor (${assignable.length} de ${selected.length})',
                  ),
                  onTap: assignable.isEmpty
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _bulkAssignSeller(
                            event: event,
                            selected: selected,
                            eligible: assignable,
                            sellers: sellers,
                            organizerId: organizerId,
                            organizerName: organizerName,
                          );
                        },
                ),
                ListTile(
                  enabled: returnable.isNotEmpty,
                  leading: const Icon(Icons.undo),
                  title: Text(
                    returnable.isEmpty
                        ? 'Devolver al pool'
                        : returnable.length == selected.length
                            ? 'Devolver al pool (${returnable.length})'
                            : 'Devolver al pool (${returnable.length} de ${selected.length})',
                  ),
                  onTap: returnable.isEmpty
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _bulkReturnToPool(
                            event: event,
                            selected: selected,
                            eligible: returnable,
                            organizerId: organizerId,
                          );
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text('Imprimir (${selected.length})'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _printTickets(
                      event: event,
                      tickets: selected,
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
                      event: event,
                      tickets: selected,
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

  Future<void> _bulkCollect({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String organizerId,
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
      await _runBusy(
        message: 'Cobrando ${eligible.length} tickets...',
        work: (_) async {
          final poolIds = eligible
              .where((t) => t.status.isAssignablePool)
              .map((t) => t.id)
              .toList(growable: false);
          if (poolIds.isNotEmpty) {
            await claimTicketsForSellerAction(
              ref,
              eventId: event.id,
              ticketIds: poolIds,
              sellerId: organizerId,
              actorId: organizerId,
              actorRole: 'organizer',
            );
          }
          await collectTicketsAction(
            ref,
            eventId: event.id,
            ticketIds: eligible.map((t) => t.id),
            actorId: organizerId,
            actorRole: 'organizer',
          );
        },
      );
      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${eligible.length} ticket${eligible.length == 1 ? '' : 's'} '
            'cobrado${eligible.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _bulkReserve({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String organizerId,
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
      title: 'Destinatario para ${eligible.length} tickets',
      requiredName: true,
      confirmLabel: 'Reservar',
    );
    if (buyerName == null || !mounted) return;

    try {
      await _runBusy(
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
              sellerId: _sellerIdFor(ticket, organizerId),
              actorId: organizerId,
              actorRole: 'organizer',
            );
          }
        },
      );
      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${eligible.length} ticket${eligible.length == 1 ? '' : 's'} '
            'reservado${eligible.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _bulkAssignSeller({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required List<Collaborator> sellers,
    required String organizerId,
    required String organizerName,
  }) async {
    final ok = await _confirmEligible(
      title: 'Asignar vendedor',
      confirmLabel: 'Continuar',
      selected: selected,
      eligible: eligible,
      actionVerb: 'asignar',
    );
    if (!ok || !mounted) return;

    final chosen = await _pickSeller(
      title: 'Asignar ${eligible.length} tickets',
      sellers: sellers,
      organizerId: organizerId,
      organizerName: organizerName,
    );
    if (chosen == null || !mounted) return;

    final needsRelease = eligible.any((t) => !t.status.isAssignablePool);
    if (needsRelease) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cambiar vendedor'),
          content: Text(
            'Algunos tickets ya tienen vendedor o están reservados. '
            'Al reasignar a ${chosen.name} se liberan y pasan al nuevo vendedor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    try {
      await _runBusy(
        message: 'Asignando a ${chosen.name}...',
        work: (_) async {
          final toRelease = eligible
              .where((t) => !t.status.isAssignablePool)
              .map((t) => t.id)
              .toList(growable: false);
          if (toRelease.isNotEmpty) {
            await returnTicketsToPoolAction(
              ref,
              eventId: event.id,
              ticketIds: toRelease,
              actorId: organizerId,
              actorRole: 'organizer',
            );
          }
          await claimTicketsForSellerAction(
            ref,
            eventId: event.id,
            ticketIds: eligible.map((t) => t.id),
            sellerId: chosen.id,
            actorId: organizerId,
            actorRole: 'organizer',
          );
        },
      );
      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${eligible.length} ticket${eligible.length == 1 ? '' : 's'} '
            '→ ${chosen.name}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _bulkReturnToPool({
    required Event event,
    required List<Ticket> selected,
    required List<Ticket> eligible,
    required String organizerId,
  }) async {
    final ok = await _confirmEligible(
      title: 'Devolver al pool',
      confirmLabel: 'Devolver',
      selected: selected,
      eligible: eligible,
      actionVerb: 'devolver',
    );
    if (!ok || !mounted) return;

    try {
      await _runBusy(
        message: 'Devolviendo ${eligible.length} tickets...',
        work: (_) async {
          await returnTicketsToPoolAction(
            ref,
            eventId: event.id,
            ticketIds: eligible.map((t) => t.id),
            actorId: organizerId,
            actorRole: 'organizer',
          );
        },
      );
      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${eligible.length} ticket${eligible.length == 1 ? '' : 's'} '
            'vuelve${eligible.length == 1 ? '' : 'n'} al pool.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<_SellerPick?> _pickSeller({
    required String title,
    required List<Collaborator> sellers,
    required String organizerId,
    required String organizerName,
  }) {
    return showModalBottomSheet<_SellerPick>(
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
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(organizerName),
                  subtitle: const Text('Vos (organizador)'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _SellerPick(organizerId, organizerName),
                  ),
                ),
                for (final s in sellers)
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(s.name),
                    subtitle: s.phone.trim().isEmpty ? null : Text(s.phone),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _SellerPick(s.id, s.name),
                    ),
                  ),
                if (sellers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Text(
                      'No hay vendedores todavía. Podés asignártelo a vos '
                      'o crear uno en Colaboradores.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _collect({
    required Event event,
    required Ticket ticket,
    required String organizerId,
  }) async {
    if (event.isReadOnly || !ticket.status.isSellable) return;

    String? buyerName = ticket.buyerName.trim().isEmpty
        ? null
        : ticket.buyerName.trim();

    if (buyerName == null) {
      final result = await _askBuyerName(
        title: 'Cobrar ticket #${ticket.number}',
        requiredName: false,
        confirmLabel: 'Cobrar',
      );
      if (result == null || !mounted) return;
      buyerName = result.trim().isEmpty ? null : result.trim();
    }

    final sellerId = _sellerIdFor(ticket, organizerId);
    try {
      await _runBusy(
        message: 'Cobrando ticket #${ticket.number}...',
        work: (_) async {
          if (ticket.status.isAssignablePool) {
            await claimTicketsForSellerAction(
              ref,
              eventId: event.id,
              ticketIds: [ticket.id],
              sellerId: sellerId,
              actorId: organizerId,
              actorRole: 'organizer',
            );
          }
          await collectTicketsAction(
            ref,
            eventId: event.id,
            ticketIds: [ticket.id],
            actorId: organizerId,
            actorRole: 'organizer',
            buyerName: buyerName,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reserve({
    required Event event,
    required Ticket ticket,
    required String organizerId,
  }) async {
    if (event.isReadOnly) return;
    if (!ticket.status.isSellable || ticket.status == TicketStatus.reserved) {
      return;
    }

    final buyerName = await _askBuyerName(
      title: 'Reservar ticket #${ticket.number}',
      requiredName: true,
      initialName: ticket.buyerName,
      confirmLabel: 'Reservar',
    );
    if (buyerName == null || !mounted) return;

    try {
      await _runBusy(
        message: 'Reservando ticket #${ticket.number}...',
        work: (_) async {
          await reserveTicketsAction(
            ref,
            eventId: event.id,
            ticketIds: [ticket.id],
            buyerName: buyerName,
            sellerId: _sellerIdFor(ticket, organizerId),
            actorId: organizerId,
            actorRole: 'organizer',
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _setBuyer({
    required Event event,
    required Ticket ticket,
  }) async {
    if (event.isReadOnly) return;
    final hasBuyer = ticket.buyerName.trim().isNotEmpty;
    final result = await _askBuyerName(
      title: hasBuyer
          ? 'Editar destinatario · #${ticket.number}'
          : 'Destinatario · #${ticket.number}',
      requiredName: false,
      initialName: ticket.buyerName,
      confirmLabel: 'Guardar',
    );
    if (result == null || !mounted) return;

    try {
      await _runBusy(
        message: 'Guardando destinatario...',
        work: (_) async {
          await setTicketsBuyerAction(
            ref,
            eventId: event.id,
            ticketIds: [ticket.id],
            buyerName: result,
            actorId: ref.read(sessionProvider).userUid,
            actorRole: 'organizer',
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _assignSeller({
    required Event event,
    required Ticket ticket,
    required List<Collaborator> sellers,
    required String organizerId,
    required String organizerName,
  }) async {
    if (event.isReadOnly) return;
    final canAssign = ticket.status.isAssignablePool ||
        ticket.status == TicketStatus.withSeller ||
        ticket.status == TicketStatus.reserved;
    if (!canAssign) return;

    final chosen = await _pickSeller(
      title: ticket.status.isAssignablePool
          ? 'Asignar vendedor · #${ticket.number}'
          : 'Cambiar vendedor · #${ticket.number}',
      sellers: sellers,
      organizerId: organizerId,
      organizerName: organizerName,
    );
    if (chosen == null || !mounted) return;

    final current = ticket.sellerId?.trim();
    if (current == chosen.id && !ticket.status.isAssignablePool) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya está asignado a ${chosen.name}.')),
      );
      return;
    }

    if (!ticket.status.isAssignablePool) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cambiar vendedor'),
          content: Text(
            ticket.status == TicketStatus.reserved
                ? 'El ticket #${ticket.number} está reservado. Al cambiar de '
                    'vendedor se libera la reserva y el destinatario.'
                : 'El ticket #${ticket.number} pasa a ${chosen.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    try {
      await _runBusy(
        message: 'Asignando a ${chosen.name}...',
        work: (_) async {
          if (!ticket.status.isAssignablePool) {
            await returnTicketsToPoolAction(
              ref,
              eventId: event.id,
              ticketIds: [ticket.id],
              actorId: organizerId,
              actorRole: 'organizer',
            );
          }
          await claimTicketsForSellerAction(
            ref,
            eventId: event.id,
            ticketIds: [ticket.id],
            sellerId: chosen.id,
            actorId: organizerId,
            actorRole: 'organizer',
          );
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket #${ticket.number} → ${chosen.name}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _clearReservation({
    required Event event,
    required Ticket ticket,
    required String organizerId,
  }) async {
    if (event.isReadOnly || ticket.status != TicketStatus.reserved) return;
    final assigned = ticket.sellerId;
    final returnToPool = assigned == null ||
        assigned.isEmpty ||
        assigned == organizerId;

    try {
      await _runBusy(
        message: 'Liberando reserva...',
        work: (_) async {
          if (returnToPool) {
            await returnTicketsToPoolAction(
              ref,
              eventId: event.id,
              ticketIds: [ticket.id],
              actorId: organizerId,
              actorRole: 'organizer',
            );
          } else {
            await clearTicketReservationsAction(
              ref,
              eventId: event.id,
              ticketIds: [ticket.id],
              actorId: organizerId,
              actorRole: 'organizer',
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _returnToPool({
    required Event event,
    required Ticket ticket,
  }) async {
    if (event.isReadOnly) return;
    if (ticket.status != TicketStatus.withSeller &&
        ticket.status != TicketStatus.reserved) {
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Devolver al pool'),
        content: Text(
          'El ticket #${ticket.number} vuelve a “Sin vendedor”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Devolver'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _runBusy(
        message: 'Devolviendo al pool...',
        work: (_) async {
          await returnTicketsToPoolAction(
            ref,
            eventId: event.id,
            ticketIds: [ticket.id],
            actorId: ref.read(sessionProvider).userUid,
            actorRole: 'organizer',
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _printTickets({
    required Event event,
    required List<Ticket> tickets,
    required Map<String, String> sellerNames,
  }) async {
    if (event.isReadOnly || tickets.isEmpty) return;
    var progress = 0;
    final total = tickets.length;
    void Function(void Function())? setDialogState;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
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
        tickets: tickets,
        style: event.ticketDesign,
        sellerNames: sellerNames,
        onProgress: (done, _) {
          progress = done;
          setDialogState?.call(() {});
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (_selectionMode) _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF listo. Elegí dónde guardarlo.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $e')),
      );
    }
  }

  Future<void> _shareTickets({
    required Event event,
    required List<Ticket> tickets,
    required Map<String, String> sellerNames,
  }) async {
    if (event.isReadOnly || tickets.isEmpty) return;
    try {
      await TicketShare.shareImages(
        context,
        tickets: tickets,
        event: event,
        style: event.ticketDesign,
        sellerNames: sellerNames,
      );
      if (_selectionMode && mounted) _exitSelection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron generar las imágenes: $e')),
      );
    }
  }

  Future<String?> _askBuyerName({
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

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.collectibleCount,
    required this.onCollect,
    required this.onMore,
    required this.onClear,
  });

  final int selectedCount;
  final int collectibleCount;
  final VoidCallback? onCollect;
  final VoidCallback onMore;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final collectLabel = collectibleCount == 0
        ? 'Cobrar'
        : collectibleCount == selectedCount
            ? 'Cobrar ($collectibleCount)'
            : 'Cobrar ($collectibleCount de $selectedCount)';

    return Material(
      elevation: 8,
      color: AppColors.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$selectedCount seleccionados',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onCollect,
                child: Text(collectLabel),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Más acciones',
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz),
              ),
              IconButton(
                tooltip: 'Cancelar selección',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerPick {
  const _SellerPick(this.id, this.name);
  final String id;
  final String name;
}

class _OrganizerTicketCard extends StatelessWidget {
  const _OrganizerTicketCard({
    required this.ticket,
    required this.event,
    required this.readOnly,
    required this.selectionMode,
    required this.selected,
    required this.sellerLabel,
    required this.onToggleSelect,
    required this.onLongPress,
    required this.onCollect,
    required this.onReserve,
    required this.onSetBuyer,
    required this.onAssignSeller,
    required this.onClearReservation,
    required this.onReturnToPool,
    required this.onPrint,
    required this.onShare,
  });

  final Ticket ticket;
  final Event event;
  final bool readOnly;
  final bool selectionMode;
  final bool selected;
  final String? sellerLabel;
  final VoidCallback onToggleSelect;
  final VoidCallback? onLongPress;
  final VoidCallback onCollect;
  final VoidCallback onReserve;
  final VoidCallback onSetBuyer;
  final VoidCallback onAssignSeller;
  final VoidCallback onClearReservation;
  final VoidCallback onReturnToPool;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  bool get _canCollect => !readOnly && ticket.status.isSellable;

  bool get _canReserve =>
      !readOnly &&
      ticket.status.isSellable &&
      ticket.status != TicketStatus.reserved;

  bool get _canSetBuyer =>
      !readOnly &&
      (ticket.status == TicketStatus.reserved ||
          ticket.status == TicketStatus.collected ||
          ticket.status == TicketStatus.settled ||
          ticket.status == TicketStatus.delivered ||
          ticket.status == TicketStatus.withSeller);

  bool get _canAssignSeller =>
      !readOnly &&
      (ticket.status.isAssignablePool ||
          ticket.status == TicketStatus.withSeller ||
          ticket.status == TicketStatus.reserved);

  bool get _canClearReservation =>
      !readOnly && ticket.status == TicketStatus.reserved;

  bool get _canReturnToPool =>
      !readOnly &&
      (ticket.status == TicketStatus.withSeller ||
          ticket.status == TicketStatus.reserved);

  bool get _canExport => !readOnly;

  @override
  Widget build(BuildContext context) {
    final buyer = ticket.buyerName.trim();
    final seller = sellerLabel?.trim() ?? '';
    final style = ticketStyle(ticket);
    final bg = selected
        ? Color.alphaBlend(
            AppColors.accent.withValues(alpha: 0.12),
            style.background,
          )
        : style.background;
    final borderColor = selected
        ? AppColors.accent
        : Color.alphaBlend(
            style.foreground.withValues(alpha: 0.22),
            style.background,
          );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selectionMode ? onToggleSelect : null,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: EdgeInsets.fromLTRB(selectionMode ? 6 : 14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect(),
                      visualDensity: VisualDensity.compact,
                    ),
                  Expanded(
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
                            const SizedBox(width: 8),
                            TicketStatusPill.forTicket(ticket),
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
                        if (seller.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Vendedor: $seller',
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
                  if (!readOnly && !selectionMode)
                    IconButton(
                      tooltip: 'Más acciones',
                      onPressed: () => _openActions(context),
                      icon: const Icon(Icons.more_horiz),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (_canCollect && !selectionMode) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton(
                    onPressed: onCollect,
                    child: const Text('Cobrar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    final buyer = ticket.buyerName.trim();
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ticket #${ticket.number}',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (_canCollect)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Cobrar'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onCollect();
                    },
                  ),
                if (_canReserve)
                  ListTile(
                    leading: const Icon(Icons.bookmark_add_outlined),
                    title: const Text('Reservar'),
                    subtitle:
                        const Text('Pide destinatario y marca reservado'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReserve();
                    },
                  ),
                if (_canSetBuyer)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      buyer.isEmpty ? 'Destinatario' : 'Editar destinatario',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSetBuyer();
                    },
                  ),
                if (_canAssignSeller)
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(
                      ticket.status.isAssignablePool
                          ? 'Asignar vendedor'
                          : 'Cambiar vendedor',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onAssignSeller();
                    },
                  ),
                if (_canClearReservation)
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('Liberar reserva'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onClearReservation();
                    },
                  ),
                if (_canReturnToPool)
                  ListTile(
                    leading: const Icon(Icons.undo),
                    title: const Text('Devolver al pool'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReturnToPool();
                    },
                  ),
                if (_canExport) ...[
                  ListTile(
                    leading: const Icon(Icons.print_outlined),
                    title: const Text('Imprimir'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPrint();
                    },
                  ),
                  ListTile(
                    leading: const Icon(AccessShare.shareIcon),
                    title: const Text('Compartir'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onShare();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
