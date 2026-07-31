import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/ticket_pdf.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/qr_scan_screen.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/ticket_share.dart';

/// Entry via deeplink. Routes seller / validator / collector portals.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  bool _resolving = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      final collab = await ref
          .read(collaboratorRepositoryProvider)
          .findByToken(widget.token);
      if (!mounted) return;
      if (collab == null) {
        setState(() {
          _resolving = false;
          _error = 'Este deeplink no existe o ya no es válido.';
        });
        return;
      }
      await ref
          .read(sessionProvider.notifier)
          .enterAsCollaborator(widget.token, role: collab.role);
      if (!mounted) return;
      final path = switch (collab.role) {
        CollaboratorRole.seller => '/seller/${widget.token}',
        CollaboratorRole.validator => '/validator/${widget.token}',
        CollaboratorRole.collector => '/collector/${widget.token}',
        CollaboratorRole.coordinator => '/coordinator/${widget.token}',
      };
      context.go(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'No se pudo validar el link: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Link inválido')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      body: Center(
        child: _resolving
            ? const CircularProgressIndicator()
            : const Text('Redirigiendo…'),
      ),
    );
  }
}

/// Seller portal: digital tickets ready to print, sell and share (one or many).
class SellerPortalScreen extends ConsumerStatefulWidget {
  const SellerPortalScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<SellerPortalScreen> createState() => _SellerPortalScreenState();
}

class _SellerPortalScreenState extends ConsumerState<SellerPortalScreen> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(collaboratorByTokenProvider(widget.token));
    if (sellerAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final seller = sellerAsync.valueOrNull;
    if (seller == null || seller.role != CollaboratorRole.seller) {
      return const Scaffold(
        body: Center(child: Text('Vendedor no encontrado.')),
      );
    }

    final eventAsync = ref.watch(eventProvider(seller.eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(seller.eventId));

    if (eventAsync.isLoading || ticketsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || ticketsAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Text('${eventAsync.error ?? ticketsAsync.error}'),
        ),
      );
    }

    final event = eventAsync.requireValue;
    final tickets = ticketsAsync.requireValue
        .where((t) => t.sellerId == seller.id)
        .toList()
      ..sort((a, b) {
        final byStatus = _sellerTicketSortRank(
          a.status,
        ).compareTo(_sellerTicketSortRank(b.status));
        if (byStatus != 0) return byStatus;
        return a.number.compareTo(b.number);
      });
    final selectableTickets = tickets
        .where((t) => t.status == TicketStatus.withSeller)
        .toList(growable: false);
    final selectedTickets = selectableTickets
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final hasSelection = selectedTickets.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        actions: [
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
                  'Tus tickets para vender',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  seller.ranges.isEmpty
                      ? 'Todavía no te asignaron rangos.'
                      : 'Rangos: ${seller.ranges.map((r) => r.label).join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                  const Text(
                  'Seleccioná tickets sin cobrar. Compartir pide destinatario y '
                  'WhatsApp, genera una imagen por ticket y abre el envío. '
                  'Imprimir lote arma el PDF.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                if (tickets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TicketStatusSummary(tickets: tickets),
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
                          sellerId: seller.id,
                          sellerName: seller.name,
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
                          sellerId: seller.id,
                          sellerName: seller.name,
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
                  'Tickets (${tickets.length})',
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
          if (tickets.isEmpty)
            const Text(
              'Cuando el organizador te asigne un rango, van a aparecer acá.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final ticket in tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SellerTicketCard(
                  ticket: ticket,
                  event: event,
                  selected:
                      ticket.status == TicketStatus.withSeller &&
                      _selectedIds.contains(ticket.id),
                  selectionEnabled: ticket.status == TicketStatus.withSeller,
                  onToggleSelect: ticket.status == TicketStatus.withSeller
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
                      await collectTicketsAction(
                        ref,
                        eventId: event.id,
                        ticketIds: [ticket.id],
                        actorId: seller.id,
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

  /// Order: para cobrar → cobrados → devueltos → validados.
  static int _sellerTicketSortRank(TicketStatus status) {
    return switch (status) {
      TicketStatus.withSeller => 0,
      TicketStatus.unassigned => 1,
      TicketStatus.collected => 2,
      TicketStatus.settled => 3,
      TicketStatus.returned => 4,
      TicketStatus.delivered => 5,
    };
  }

  Future<void> _prepareAndContinue(
    BuildContext context, {
    required List<Ticket> tickets,
    required Event event,
    required String sellerId,
    required String sellerName,
    required _SharePrintAction action,
  }) async {
    final result = await showDialog<_SharePrintFormResult>(
      context: context,
      builder: (dialogContext) =>
          _SharePrintFormDialog(tickets: tickets, action: action),
    );

    if (result == null || !context.mounted) return;

    try {
      await setTicketsBuyerAction(
        ref,
        eventId: event.id,
        ticketIds: tickets.map((t) => t.id),
        buyerName: result.buyerName,
        actorId: sellerId,
        actorRole: 'seller',
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

  /// WhatsApp number (share flow only). Not sent to the buyer.
  final String phone;
}

/// Owns text controllers so dispose is safe when the dialog closes.
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
                    hintText: 'Ej. 11 2345-6789',
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
            final phone = _phoneController.text.trim();
            if (_isWhatsApp &&
                TicketShare.normalizeWhatsAppPhone(phone) == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ingresá un número de WhatsApp válido.'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _SharePrintFormResult(buyerName: buyerName, phone: phone),
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
    required this.onMarkCollected,
    this.onToggleSelect,
  });

  final Ticket ticket;
  final Event event;
  final bool selected;
  final bool selectionEnabled;
  final VoidCallback? onToggleSelect;
  final VoidCallback onMarkCollected;

  @override
  Widget build(BuildContext context) {
    final isPending = ticket.status == TicketStatus.withSeller;
    final buyer = ticket.buyerName.trim();

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
              onChanged: selectionEnabled
                  ? (_) => onToggleSelect?.call()
                  : null,
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
                    if (buyer.isNotEmpty || !isPending) ...[
                      const SizedBox(height: 6),
                      Text(
                        buyer.isEmpty ? 'Sin destinatario' : 'Para: $buyer',
                        style: TextStyle(
                          color: buyer.isEmpty
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (!isPending) ...[
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
            if (isPending)
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

/// Validator portal: scan / look up tickets and mark as delivered (pickup or entrance).
class ValidatorPortalScreen extends ConsumerStatefulWidget {
  const ValidatorPortalScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ValidatorPortalScreen> createState() =>
      _ValidatorPortalScreenState();
}

class _ValidatorPortalScreenState extends ConsumerState<ValidatorPortalScreen> {
  final _numberController = TextEditingController();
  String? _message;
  Ticket? _lastTicket;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _lookup([int? forcedNumber]) {
    final validator =
        ref.read(collaboratorByTokenProvider(widget.token)).valueOrNull;
    if (validator == null) return;
    final number = forcedNumber ?? int.tryParse(_numberController.text.trim());
    if (number == null) {
      setState(() {
        _message = 'Ingresá un número de ticket válido.';
        _lastTicket = null;
      });
      return;
    }
    _numberController.text = '$number';
    final tickets =
        ref.read(eventTicketsProvider(validator.eventId)).valueOrNull ??
            const <Ticket>[];
    final ticket = tickets.where((t) => t.number == number).firstOrNull;
    if (ticket == null) {
      setState(() {
        _message = 'Ticket #$number no encontrado en este evento.';
        _lastTicket = null;
      });
      return;
    }
    setState(() {
      _lastTicket = ticket;
      _message = null;
    });
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || raw == null) return;

    final parsed = ScannedTicketRef.parse(raw);
    if (parsed == null) {
      setState(() {
        _message = 'No reconocí ese QR. Probá de nuevo o ingresá el número.';
        _lastTicket = null;
      });
      return;
    }

    final validator =
        ref.read(collaboratorByTokenProvider(widget.token)).valueOrNull;
    if (validator == null) return;
    final tickets =
        ref.read(eventTicketsProvider(validator.eventId)).valueOrNull ??
            const <Ticket>[];

    Ticket? ticket;
    if (parsed.ticketId != null) {
      if (parsed.eventId != null && parsed.eventId != validator.eventId) {
        setState(() {
          _message = 'Ese ticket es de otro evento.';
          _lastTicket = null;
        });
        return;
      }
      ticket = tickets.where((t) => t.id == parsed.ticketId).firstOrNull;
    } else if (parsed.number != null) {
      ticket = tickets.where((t) => t.number == parsed.number).firstOrNull;
    }

    if (ticket == null) {
      setState(() {
        _message = 'Ticket no encontrado en este evento.';
        _lastTicket = null;
      });
      return;
    }

    _numberController.text = '${ticket.number}';
    setState(() {
      _lastTicket = ticket;
      _message = null;
    });
  }

  Future<void> _deliver() async {
    final ticket = _lastTicket;
    if (ticket == null) return;
    if (ticket.status == TicketStatus.delivered) {
      setState(() => _message = 'Este ticket ya fue validado.');
      return;
    }
    if (ticket.status != TicketStatus.collected &&
        ticket.status != TicketStatus.settled) {
      setState(
        () => _message =
            'El ticket no figura como cobrado. Revisá con el organizador.',
      );
      return;
    }
    final validator =
        ref.read(collaboratorByTokenProvider(widget.token)).valueOrNull;
    if (validator == null) return;
    try {
      await deliverTicketAction(
        ref,
        eventId: ticket.eventId,
        ticketId: ticket.id,
        validatorId: validator.id,
      );
      if (!mounted) return;
      final refreshed = ref
          .read(eventTicketsProvider(ticket.eventId))
          .valueOrNull
          ?.where((t) => t.id == ticket.id)
          .firstOrNull;
      setState(() {
        _message = 'Ticket #${ticket.number} validado.';
        _lastTicket = refreshed ??
            (ticket
              ..status = TicketStatus.delivered
              ..validatorId = validator.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final validatorAsync = ref.watch(collaboratorByTokenProvider(widget.token));
    if (validatorAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final validator = validatorAsync.valueOrNull;
    if (validator == null || validator.role != CollaboratorRole.validator) {
      return const Scaffold(
        body: Center(child: Text('Validador no encontrado.')),
      );
    }

    ref.watch(eventTicketsProvider(validator.eventId));
    final eventAsync = ref.watch(eventProvider(validator.eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(validator.eventId));
    if (eventAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || !eventAsync.hasValue) {
      return Scaffold(
        body: Center(child: Text('${eventAsync.error ?? 'Evento no encontrado'}')),
      );
    }
    final event = eventAsync.requireValue;
    final collaborators =
        collabsAsync.valueOrNull ?? const <Collaborator>[];
    final lastTicket = _lastTicket;
    Collaborator? seller;
    if (lastTicket?.sellerId != null) {
      for (final c in collaborators) {
        if (c.id == lastTicket!.sellerId) {
          seller = c;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(validator.name),
        actions: [
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
                  'Validación · ${event.pickupPlace}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.pickupFrom.format(context)} – ${event.pickupTo.format(context)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usá este acceso en el retiro del producto o en la entrada del evento.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Lectura de ticket',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear QR'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de ticket',
                    hintText: 'Ej. 18',
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _lookup, child: const Text('Buscar')),
              ],
            ),
          ),
          if (lastTicket != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Ticket #${lastTicket.number}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusBadge(
                    label: lastTicket.status.label,
                    tone: ticketStatusTone(lastTicket.status),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Destinatario',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastTicket.buyerName.trim().isEmpty
                        ? 'Sin destinatario cargado'
                        : lastTicket.buyerName.trim(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: lastTicket.buyerName.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vendedor',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seller?.name ??
                        (lastTicket.sellerId == null
                            ? 'Sin vendedor'
                            : 'Vendedor no encontrado'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: seller == null
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: lastTicket.status == TicketStatus.delivered
                        ? null
                        : _deliver,
                    icon: Icon(
                      lastTicket.status == TicketStatus.delivered
                          ? Icons.check_circle_outline
                          : Icons.verified_outlined,
                    ),
                    label: Text(
                      lastTicket.status == TicketStatus.delivered
                          ? 'Ya validado'
                          : 'Validar',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(
              _message!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Portal del recaudador: elige vendedor y cobra (rinde) tickets ya cobrados.
class CollectorPortalScreen extends ConsumerStatefulWidget {
  const CollectorPortalScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<CollectorPortalScreen> createState() =>
      _CollectorPortalScreenState();
}

class _CollectorPortalScreenState extends ConsumerState<CollectorPortalScreen> {
  Collaborator? _selectedSeller;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final collectorAsync = ref.watch(collaboratorByTokenProvider(widget.token));
    if (collectorAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final collector = collectorAsync.valueOrNull;
    if (collector == null || collector.role != CollaboratorRole.collector) {
      return const Scaffold(
        body: Center(child: Text('Recaudador no encontrado.')),
      );
    }

    final eventAsync = ref.watch(eventProvider(collector.eventId));
    final sellersAsync = ref.watch(eventSellersProvider(collector.eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(collector.eventId));

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
        collector: collector,
        event: event,
        seller: _selectedSeller!,
        tickets: allTickets
            .where((t) => t.sellerId == _selectedSeller!.id)
            .toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(collector.name),
        actions: [
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
            child: const Text(
              'Elegí un vendedor para rendir lo cobrado o devolver tickets '
              'al pool (para que un coordinador los reasigne).',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
    required Collaborator collector,
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
              t.status == TicketStatus.withSeller,
        )
        .toList(growable: false);
    final selectedTickets = selectable
        .where((t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final selectedCollected = selectedTickets
        .where((t) => t.status == TicketStatus.collected)
        .toList(growable: false);
    final currency = event.ticketPrice;

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
                          try {
                            await settleTicketsAction(
                              ref,
                              eventId: event.id,
                              ticketIds: selectedCollected.map((t) => t.id),
                              collectorId: collector.id,
                            );
                            if (!context.mounted) return;
                            setState(() {
                              _selectedIds.removeWhere(
                                (id) => selectedCollected.any((t) => t.id == id),
                              );
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Rendiste ${selectedCollected.length} tickets '
                                  '(\$${(selectedCollected.length * currency).toStringAsFixed(0)}).',
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
                              actorId: collector.id,
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
                    ticket.status == TicketStatus.withSeller,
                collectorName: ticket.collectorId == null
                    ? null
                    : (ticket.collectorId == collector.id
                        ? collector.name
                        : null),
                onToggle: ticket.status == TicketStatus.collected ||
                        ticket.status == TicketStatus.withSeller
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

  /// Order: cobrados → en poder → rendidos → devueltos → validados.
  static int _collectorTicketSortRank(TicketStatus status) {
    return switch (status) {
      TicketStatus.collected => 0,
      TicketStatus.withSeller => 1,
      TicketStatus.unassigned => 2,
      TicketStatus.settled => 3,
      TicketStatus.returned => 4,
      TicketStatus.delivered => 5,
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
