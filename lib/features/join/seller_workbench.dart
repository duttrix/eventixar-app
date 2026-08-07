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
    var rangesLabel = 'Todavía no hay rangos asignados.';

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
        rangesLabel = found.ranges.isEmpty
            ? 'Todavía no hay rangos asignados.'
            : 'Rangos: ${found.ranges.map((r) => r.label).join(', ')}';
      } else if (_isOrganizerSelf) {
        sellerId = lockedId;
        sellerName = widget.actorLabel;
        rangesLabel =
            'Tickets libres del pool (sin asignar a un vendedor).';
      } else {
        return const Scaffold(
          body: Center(child: Text('Vendedor no encontrado.')),
        );
      }
    } else if (_selectedSeller != null) {
      final s = _selectedSeller!;
      sellerId = s.id;
      sellerName = s.name;
      rangesLabel = s.ranges.isEmpty
          ? 'Todavía no hay rangos asignados.'
          : 'Rangos: ${s.ranges.map((r) => r.label).join(', ')}';
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
      rangesLabel: rangesLabel,
      tickets: _isOrganizerSelf
          ? allTickets
              .where(
                (t) =>
                    t.status.isAssignablePool || t.sellerId == sellerId,
              )
              .toList()
          : allTickets.where((t) => t.sellerId == sellerId).toList(),
      canGoBack: lockedId == null,
      canSelfAssign: _isOrganizerSelf,
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
                      'para compartir o cobrar sus tickets.'
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
                      if (s.ranges.isEmpty)
                        'Sin rangos'
                      else
                        'Rangos: ${s.ranges.map((r) => r.label).join(', ')}',
                      '${allTickets.where((t) => t.sellerId == s.id && t.status == TicketStatus.withSeller).length} para cobrar',
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
    required String rangesLabel,
    required List<Ticket> tickets,
    required bool canGoBack,
    required bool canSelfAssign,
  }) {
    final sorted = [...tickets]..sort((a, b) {
        final byStatus = _sellerTicketSortRank(a.status)
            .compareTo(_sellerTicketSortRank(b.status));
        if (byStatus != 0) return byStatus;
        return a.number.compareTo(b.number);
      });
    final selectableTickets = sorted
        .where(
          (t) =>
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.collected ||
              (canSelfAssign && t.status.isAssignablePool),
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
                      ? 'Tickets libres para vender'
                      : (widget.actorRole == 'organizer'
                          ? 'Tickets de $sellerName'
                          : 'Tus tickets para vender'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  rangesLabel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  canSelfAssign
                      ? 'Acá ves solo tickets sin vendedor. Los que ya están '
                          'asignados a alguien no aparecen, para que no se '
                          'vendan dos veces. Podés cobrar y después compartir '
                          'por WhatsApp, o al revés.'
                      : 'Seleccioná tickets para compartir o imprimir '
                          '(también si ya están cobrados). Compartir pide '
                          'destinatario y WhatsApp, genera una imagen por ticket.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TicketStatusSummary(tickets: sorted),
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
                      : () => _prepareAndContinue(
                            context,
                            tickets: selectedTickets,
                            event: event,
                            sellerId: sellerId,
                            action: _SharePrintAction.printPdf,
                          ),
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
                      : () => _prepareAndContinue(
                            context,
                            tickets: selectedTickets,
                            event: event,
                            sellerId: sellerId,
                            action: _SharePrintAction.whatsapp,
                          ),
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
                  'Tickets (${sorted.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                  ? 'No hay tickets libres en el pool. Todos están asignados '
                      'a vendedores o ya se vendieron.'
                  : 'Cuando se asigne un rango, los tickets van a aparecer acá.',
              style: const TextStyle(color: AppColors.textMuted),
            )
          else
            for (final ticket in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SellerTicketCard(
                  ticket: ticket,
                  event: event,
                  selected: selectableTickets.any((t) => t.id == ticket.id) &&
                      _selectedIds.contains(ticket.id),
                  selectionEnabled:
                      selectableTickets.any((t) => t.id == ticket.id),
                  canCollect: ticket.status == TicketStatus.withSeller ||
                      (canSelfAssign && ticket.status.isAssignablePool),
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
                  onMarkCollected: () async {
                    try {
                      await _claimPoolTicketsIfNeeded(
                        sellerId: sellerId,
                        tickets: [ticket],
                      );
                      await collectTicketsAction(
                        ref,
                        eventId: event.id,
                        ticketIds: [ticket.id],
                        actorId: widget.actorId,
                        actorRole: widget.actorRole,
                      );
                      if (!mounted) return;
                      setState(() => _selectedIds.remove(ticket.id));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
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

  static int _sellerTicketSortRank(TicketStatus status) {
    return switch (status) {
      TicketStatus.unassigned => 0,
      TicketStatus.returned => 1,
      TicketStatus.withSeller => 2,
      TicketStatus.collected => 3,
      TicketStatus.settled => 4,
      TicketStatus.delivered => 5,
    };
  }

  Future<void> _prepareAndContinue(
    BuildContext context, {
    required List<Ticket> tickets,
    required Event event,
    required String sellerId,
    required _SharePrintAction action,
  }) async {
    final result = await showDialog<_SharePrintFormResult>(
      context: context,
      builder: (dialogContext) =>
          _SharePrintFormDialog(tickets: tickets, action: action),
    );

    if (result == null || !context.mounted) return;

    try {
      await _claimPoolTicketsIfNeeded(sellerId: sellerId, tickets: tickets);
      await setTicketsBuyerAction(
        ref,
        eventId: event.id,
        ticketIds: tickets.map((t) => t.id),
        buyerName: result.buyerName,
        actorId: widget.actorId,
        actorRole: widget.actorRole,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    if (!context.mounted) return;
    setState(() {
      _selectedIds.removeAll(tickets.map((ticket) => ticket.id));
    });

    final updated = [
      for (final ticket in tickets)
        Ticket(
          id: ticket.id,
          eventId: ticket.eventId,
          number: ticket.number,
          status: ticket.status,
          sellerId: ticket.sellerId,
          validatorId: ticket.validatorId,
          collectorId: ticket.collectorId,
          buyerName: result.buyerName,
        ),
    ];

    if (action == _SharePrintAction.whatsapp) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Elegí WhatsApp y enviá a ${result.buyerName} (${result.phone}). '
              'Solo van las imágenes.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      try {
        await TicketShare.shareImages(
          context,
          tickets: updated,
          event: event,
          style: event.ticketDesign,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron generar las imágenes: $e')),
        );
      }
    } else if (context.mounted) {
      try {
        await TicketPdf.printTickets(event: event, tickets: updated);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF: $e')),
        );
      }
    }
  }
}

enum _SharePrintAction { whatsapp, printPdf }

class _SharePrintFormResult {
  const _SharePrintFormResult({
    required this.buyerName,
    this.phone = '',
  });

  final String buyerName;
  final String phone;
}

class _SharePrintFormDialog extends StatefulWidget {
  const _SharePrintFormDialog({required this.tickets, required this.action});

  final List<Ticket> tickets;
  final _SharePrintAction action;

  @override
  State<_SharePrintFormDialog> createState() => _SharePrintFormDialogState();
}

class _SharePrintFormDialogState extends State<_SharePrintFormDialog> {
  late final TextEditingController _buyerController;
  late final TextEditingController _phoneController;

  bool get _isWhatsApp => widget.action == _SharePrintAction.whatsapp;

  @override
  void initState() {
    super.initState();
    _buyerController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _buyerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isWhatsApp ? 'Enviar por WhatsApp' : 'Antes de imprimir'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isWhatsApp
                    ? 'Se van a generar ${widget.tickets.length} '
                        'imagen${widget.tickets.length == 1 ? '' : 'es'} '
                        '(una por ticket). El comprador solo recibe las fotos.'
                    : 'Ingresá el destinatario para todos los tickets seleccionados.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Tickets: ${widget.tickets.map((ticket) => '#${ticket.number}').join(', ')}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyerController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Destinatario',
                  hintText: 'Ej. Juan Pérez',
                  isDense: true,
                ),
              ),
              if (_isWhatsApp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final buyerName = _buyerController.text.trim();
            if (buyerName.isEmpty) return;
            final localPhone = _phoneController.text.trim();
            final normalized = _isWhatsApp
                ? TicketShare.normalizeWhatsAppPhone(localPhone)
                : null;
            if (_isWhatsApp && normalized == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Ingresá un número válido (ej. 11 2345-6789).',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _SharePrintFormResult(
                buyerName: buyerName,
                phone: normalized == null
                    ? localPhone
                    : TicketShare.formatWhatsAppPhone(normalized),
              ),
            );
          },
          child: Text(
            _isWhatsApp ? 'Generar e ir a WhatsApp' : 'Continuar e imprimir',
          ),
        ),
      ],
    );
  }
}

class _SellerTicketCard extends StatelessWidget {
  const _SellerTicketCard({
    required this.ticket,
    required this.event,
    required this.selected,
    required this.selectionEnabled,
    required this.canCollect,
    required this.onMarkCollected,
    this.onToggleSelect,
  });

  final Ticket ticket;
  final Event event;
  final bool selected;
  final bool selectionEnabled;
  final bool canCollect;
  final VoidCallback? onToggleSelect;
  final VoidCallback onMarkCollected;

  @override
  Widget build(BuildContext context) {
    final buyer = ticket.buyerName.trim();
    final showStatus = ticket.status != TicketStatus.withSeller || buyer.isEmpty;

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
        padding: const EdgeInsets.fromLTRB(6, 12, 10, 12),
        child: Row(
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
                    if (showStatus || ticket.status.isAssignablePool) ...[
                      const SizedBox(height: 6),
                      StatusBadge(
                        label: ticket.status.label,
                        tone: ticketStatusTone(ticket.status),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (canCollect)
              FilledButton(
                onPressed: onMarkCollected,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Cobrar'),
              ),
          ],
        ),
      ),
    );
  }
}
