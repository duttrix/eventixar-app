import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/access_share.dart';
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
      final collab = await resolveCollaboratorToken(ref, widget.token);
      if (!mounted) return;
      if (collab == null) {
        setState(() {
          _resolving = false;
          _error = 'Este deeplink no existe o ya no es válido.';
        });
        return;
      }
      ref.read(sessionProvider.notifier).enterAsCollaborator(widget.token);
      final path = switch (collab.role) {
        CollaboratorRole.seller => '/seller/${widget.token}',
        CollaboratorRole.validator => '/validator/${widget.token}',
        CollaboratorRole.collector => '/collector/${widget.token}',
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
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorByToken(widget.token);
    if (seller == null || seller.role != CollaboratorRole.seller) {
      return const Scaffold(body: Center(child: Text('Vendedor no encontrado.')));
    }
    final event = repo.eventById(seller.eventId);
    final tickets = repo.ticketsForSeller(seller.id)
      ..sort((a, b) {
        final byStatus = _sellerTicketSortRank(a.status).compareTo(_sellerTicketSortRank(b.status));
        if (byStatus != 0) return byStatus;
        return a.number.compareTo(b.number);
      });
    final selectableTickets =
        tickets.where((t) => t.status == TicketStatus.withSeller).toList(growable: false);
    final selectedTickets =
        selectableTickets.where((t) => _selectedIds.contains(t.id)).toList(growable: false);
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
                Text('Tus tickets para vender', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  seller.ranges.isEmpty
                      ? 'Todavía no te asignaron rangos.'
                      : 'Rangos: ${seller.ranges.map((r) => r.label).join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seleccioná tickets sin cobrar. Al tocar Imprimir lote o Links se pide '
                  'destinatario / detalle y se comparte.',
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
                            sellerName: seller.name,
                            action: _SharePrintAction.printPdf,
                          ),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(
                    hasSelection ? 'Imprimir lote (${selectedTickets.length})' : 'Imprimir lote',
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
                            sellerName: seller.name,
                            action: _SharePrintAction.links,
                          ),
                  icon: const Icon(Icons.link),
                  label: Text(
                    hasSelection ? 'Links (${selectedTickets.length})' : 'Links',
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
                  onPressed: hasSelection ? () => setState(_selectedIds.clear) : null,
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
                  selected: ticket.status == TicketStatus.withSeller && _selectedIds.contains(ticket.id),
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
                  onMarkCollected: () {
                    ref.read(repositoryProvider).updateTicketStatus(
                          ticket.id,
                          TicketStatus.collected,
                        );
                    setState(() => _selectedIds.remove(ticket.id));
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
    required String sellerName,
    required _SharePrintAction action,
  }) async {
    final result = await showDialog<_SharePrintFormResult>(
      context: context,
      builder: (dialogContext) => _SharePrintFormDialog(
        tickets: tickets,
        action: action,
      ),
    );

    if (result == null || !context.mounted) return;

    final repo = ref.read(repositoryProvider);
    for (final ticket in tickets) {
      repo.updateTicketBuyer(ticket.id, buyerName: result.buyerName);
    }
    setState(() {
      _selectedIds.removeAll(tickets.map((ticket) => ticket.id));
    });

    final updated = tickets
        .map((ticket) => repo.tickets.firstWhere((x) => x.id == ticket.id))
        .toList(growable: false);
    final note = result.note;

    if (action == _SharePrintAction.links) {
      await TicketShare.shareMany(
        tickets: updated,
        event: event,
        sellerName: sellerName,
        note: note.isEmpty ? null : note,
      );
    } else if (context.mounted) {
      final lines = updated.map((t) => '#${t.number} (${t.buyerName})').join(', ');
      final notePart = note.isEmpty ? '' : ' Nota: $note.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF con ${updated.length} tickets ($lines) listo para imprimir (simulado).$notePart',
          ),
        ),
      );
    }
  }
}

enum _SharePrintAction { links, printPdf }

class _SharePrintFormResult {
  const _SharePrintFormResult({required this.buyerName, required this.note});

  final String buyerName;
  final String note;
}

/// Owns text controllers so dispose is safe when the dialog closes.
class _SharePrintFormDialog extends StatefulWidget {
  const _SharePrintFormDialog({
    required this.tickets,
    required this.action,
  });

  final List<Ticket> tickets;
  final _SharePrintAction action;

  @override
  State<_SharePrintFormDialog> createState() => _SharePrintFormDialogState();
}

class _SharePrintFormDialogState extends State<_SharePrintFormDialog> {
  late final TextEditingController _buyerController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _buyerController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _buyerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.action == _SharePrintAction.links ? 'Antes de enviar links' : 'Antes de imprimir',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ingresá el destinatario para todos los tickets seleccionados.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota / detalle (opcional)',
                  hintText: 'Ej. Entregar el sábado en la sede',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final buyerName = _buyerController.text.trim();
            if (buyerName.isEmpty) return;
            Navigator.pop(
              context,
              _SharePrintFormResult(
                buyerName: buyerName,
                note: _noteController.text.trim(),
              ),
            );
          },
          child: Text(
            widget.action == _SharePrintAction.links ? 'Continuar y enviar' : 'Continuar e imprimir',
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${event.ticketPrice.toStringAsFixed(0)} · ${event.product}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    if (buyer.isNotEmpty || !isPending) ...[
                      const SizedBox(height: 6),
                      Text(
                        buyer.isEmpty ? 'Sin destinatario' : 'Para: $buyer',
                        style: TextStyle(
                          color: buyer.isEmpty ? AppColors.textMuted : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (!isPending) ...[
                      const SizedBox(height: 6),
                      StatusBadge(label: ticket.status.label, tone: ticketStatusTone(ticket.status)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

/// Buyer-facing public ticket page (opened from share link). No login required.
class PublicTicketScreen extends ConsumerWidget {
  const PublicTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ticket = repo.ticketById(ticketId);
    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ticket')),
        body: const Center(child: Text('Este ticket no existe o el link no es válido.')),
      );
    }
    final event = repo.eventById(ticket.eventId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tu ticket')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TicketSharePreview(ticket: ticket, event: event),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Datos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evento: ${event.name}'),
                const SizedBox(height: 4),
                if (ticket.buyerName.trim().isNotEmpty) ...[
                  Text('Para: ${ticket.buyerName.trim()}'),
                  const SizedBox(height: 4),
                ],
                Text('Producto: ${event.product}'),
                const SizedBox(height: 4),
                Text('Lugar: ${event.pickupPlace}'),
                const SizedBox(height: 4),
                Text(
                  'Horario: ${event.pickupFrom.format(context)} – ${event.pickupTo.format(context)}',
                ),
                const SizedBox(height: 10),
                StatusBadge(label: ticket.status.label, tone: ticketStatusTone(ticket.status)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mostrá este ticket (o el QR) en el retiro o en la entrada. No necesitás crear una cuenta.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Validator portal: scan / look up tickets and mark as delivered (pickup or entrance).
class ValidatorPortalScreen extends ConsumerStatefulWidget {
  const ValidatorPortalScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ValidatorPortalScreen> createState() => _ValidatorPortalScreenState();
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

  void _lookup() {
    final repo = ref.read(repositoryProvider);
    final validator = repo.collaboratorByToken(widget.token);
    if (validator == null) return;
    final number = int.tryParse(_numberController.text.trim());
    if (number == null) {
      setState(() {
        _message = 'Ingresá un número de ticket válido.';
        _lastTicket = null;
      });
      return;
    }
    final ticket = repo.findTicketByNumber(validator.eventId, number);
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

  void _deliver() {
    final ticket = _lastTicket;
    if (ticket == null) return;
    if (ticket.status == TicketStatus.delivered) {
      setState(() => _message = 'Este ticket ya fue validado.');
      return;
    }
    if (ticket.status != TicketStatus.collected && ticket.status != TicketStatus.settled) {
      setState(() => _message = 'El ticket no figura como cobrado. Revisá con el organizador.');
      return;
    }
    ref.read(repositoryProvider).markDelivered(
          ticket.id,
          validatorId: ref.read(repositoryProvider).collaboratorByToken(widget.token)?.id,
        );
    setState(() {
      _message = 'Ticket #${ticket.number} validado.';
      _lastTicket = ref.read(repositoryProvider).findTicketByNumber(ticket.eventId, ticket.number);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final validator = repo.collaboratorByToken(widget.token);
    if (validator == null || validator.role != CollaboratorRole.validator) {
      return const Scaffold(body: Center(child: Text('Validador no encontrado.')));
    }
    final event = repo.eventById(validator.eventId);

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
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cámara QR simulada: ingresá el número manualmente.')),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear QR (simulado)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de ticket',
                    hintText: 'Ej. 18',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _lookup, child: const Text('Buscar')),
              ],
            ),
          ),
          if (_lastTicket != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Ticket #${_lastTicket!.number}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusBadge(label: _lastTicket!.status.label, tone: ticketStatusTone(_lastTicket!.status)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _lastTicket!.status == TicketStatus.delivered ? null : _deliver,
                    child: Text(
                      _lastTicket!.status == TicketStatus.delivered ? 'Ya validado' : 'Marcar validado',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: const TextStyle(color: AppColors.textSecondary)),
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
  ConsumerState<CollectorPortalScreen> createState() => _CollectorPortalScreenState();
}

class _CollectorPortalScreenState extends ConsumerState<CollectorPortalScreen> {
  Collaborator? _selectedSeller;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final collector = repo.collaboratorByToken(widget.token);
    if (collector == null || collector.role != CollaboratorRole.collector) {
      return const Scaffold(body: Center(child: Text('Recaudador no encontrado.')));
    }
    final event = repo.eventById(collector.eventId);
    final sellers = repo.sellersForEvent(collector.eventId);

    if (_selectedSeller != null) {
      return _buildSellerSettlement(
        context,
        collector: collector,
        event: event,
        seller: _selectedSeller!,
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
              'Elegí un vendedor para rendir lo que ya cobró. '
              'Por ahora ves a todos los vendedores del evento.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vendedores', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (sellers.isEmpty)
            const Text('Todavía no hay vendedores.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final seller in sellers)
              _CollectorSellerCard(
                seller: seller,
                pending: repo
                    .ticketsForSeller(seller.id)
                    .where((t) => t.status == TicketStatus.collected)
                    .length,
                settled: repo
                    .ticketsForSeller(seller.id)
                    .where((t) => t.status == TicketStatus.settled || t.status == TicketStatus.delivered)
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
  }) {
    final repo = ref.watch(repositoryProvider);
    final tickets = repo.ticketsForSeller(seller.id)
      ..sort((a, b) {
        final byStatus = _collectorTicketSortRank(a.status).compareTo(_collectorTicketSortRank(b.status));
        if (byStatus != 0) return byStatus;
        return a.number.compareTo(b.number);
      });
    final pending = tickets.where((t) => t.status == TicketStatus.collected).toList(growable: false);
    final selectedTickets = pending.where((t) => _selectedIds.contains(t.id)).toList(growable: false);
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
                Text(
                  'Solo podés rendir tickets ya cobrados por el vendedor. '
                  'Al confirmar quedan rendidos a tu nombre.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TicketStatusSummary(tickets: tickets),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: selectedTickets.isEmpty
                      ? null
                      : () {
                          ref.read(repositoryProvider).markTicketsSettled(
                                ticketIds: selectedTickets.map((t) => t.id),
                                collectorId: collector.id,
                              );
                          setState(_selectedIds.clear);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Rendiste ${selectedTickets.length} tickets '
                                '(\$${(selectedTickets.length * currency).toStringAsFixed(0)}).',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    selectedTickets.isEmpty
                        ? 'Rendir selección'
                        : 'Rendir (${selectedTickets.length})',
                  ),
                ),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _selectedIds
                      ..clear()
                      ..addAll(pending.map((t) => t.id));
                  }),
                  child: const Text('Todos pendientes'),
                ),
                TextButton(
                  onPressed: selectedTickets.isEmpty ? null : () => setState(_selectedIds.clear),
                  child: const Text('Ninguno'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text('Tickets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final ticket in tickets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CollectorTicketCard(
                ticket: ticket,
                event: event,
                selected: _selectedIds.contains(ticket.id),
                selectable: ticket.status == TicketStatus.collected,
                collectorName: ticket.collectorId == null
                    ? null
                    : repo.collaboratorById(ticket.collectorId!).name,
                onToggle: ticket.status == TicketStatus.collected
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

  /// Order: cobrados (seleccionables) → en poder → rendidos → devueltos → validados.
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${event.ticketPrice.toStringAsFixed(0)} · ${event.product}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    StatusBadge(label: ticket.status.label, tone: ticketStatusTone(ticket.status)),
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
