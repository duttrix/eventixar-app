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

/// Entry via deeplink. Routes seller → ticket portal, validator → scan portal.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final collab = ref.read(repositoryProvider).collaboratorByToken(widget.token);
      if (collab == null) return;
      ref.read(sessionProvider.notifier).enterAsCollaborator(widget.token);
      if (collab.role == CollaboratorRole.seller) {
        context.go('/seller/${widget.token}');
      } else {
        context.go('/validator/${widget.token}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collab = ref.watch(repositoryProvider).collaboratorByToken(widget.token);
    if (collab == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Link inválido')),
        body: const Center(child: Text('Este deeplink no existe o ya no es válido.')),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Seller portal: digital tickets ready to print, sell and share one by one.
class SellerPortalScreen extends ConsumerWidget {
  const SellerPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorByToken(token);
    if (seller == null || seller.role != CollaboratorRole.seller) {
      return const Scaffold(body: Center(child: Text('Vendedor no encontrado.')));
    }
    final event = repo.eventById(seller.eventId);
    final tickets = repo.ticketsForSeller(seller.id)..sort((a, b) => a.number.compareTo(b.number));

    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
              context.go('/login');
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
                  'Tocá Cobrar a la derecha. Cuando esté cobrado, aparece Compartir.',
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
          OutlinedButton.icon(
            onPressed: tickets.isEmpty
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF de tickets listo para imprimir (simulado).')),
                    );
                  },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir lote'),
          ),
          const SizedBox(height: 20),
          Text('Tickets (${tickets.length})', style: Theme.of(context).textTheme.titleMedium),
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
                  onShare: () => TicketShare.share(
                    ticket: ticket,
                    event: event,
                    sellerName: seller.name,
                  ),
                  onMarkCollected: () =>
                      ref.read(repositoryProvider).updateTicketStatus(ticket.id, TicketStatus.collected),
                ),
              ),
        ],
      ),
    );
  }
}

class _SellerTicketCard extends StatelessWidget {
  const _SellerTicketCard({
    required this.ticket,
    required this.event,
    required this.onShare,
    required this.onMarkCollected,
  });

  final Ticket ticket;
  final Event event;
  final VoidCallback onShare;
  final VoidCallback onMarkCollected;

  @override
  Widget build(BuildContext context) {
    final isPending = ticket.status == TicketStatus.withSeller;
    final isCollected = ticket.status == TicketStatus.collected;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ticketStatusBg(ticket.status),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.confirmation_number_outlined, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
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
                if (!isPending) ...[
                  const SizedBox(height: 6),
                  StatusBadge(label: ticket.status.label, tone: ticketStatusTone(ticket.status)),
                ],
              ],
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
            )
          else if (isCollected)
            FilledButton.tonalIcon(
              onPressed: onShare,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                minimumSize: const Size(0, 40),
              ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Compartir'),
            ),
        ],
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
    if (ticket.status != TicketStatus.collected) {
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
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
              context.go('/login');
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
