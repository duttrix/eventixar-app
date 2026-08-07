import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/qr_scan_screen.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Shared validate UI for the collaborator portal and the organizer workspace.
class ValidatorWorkbench extends ConsumerStatefulWidget {
  const ValidatorWorkbench({
    super.key,
    required this.eventId,
    required this.actorId,
    required this.actorLabel,
    this.actorRole = 'validator',
    this.showLogout = false,
  });

  final String eventId;
  final String actorId;
  final String actorLabel;

  /// Stored on ticket history: `validator` | `organizer`.
  final String actorRole;

  final bool showLogout;

  @override
  ConsumerState<ValidatorWorkbench> createState() => _ValidatorWorkbenchState();
}

class _ValidatorWorkbenchState extends ConsumerState<ValidatorWorkbench> {
  final _numberController = TextEditingController();
  String? _message;
  Ticket? _lastTicket;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _lookup([int? forcedNumber]) {
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
        ref.read(eventTicketsProvider(widget.eventId)).valueOrNull ??
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

    final tickets =
        ref.read(eventTicketsProvider(widget.eventId)).valueOrNull ??
            const <Ticket>[];

    Ticket? ticket;
    if (parsed.ticketId != null) {
      if (parsed.eventId != null && parsed.eventId != widget.eventId) {
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
    try {
      await deliverTicketAction(
        ref,
        eventId: ticket.eventId,
        ticketId: ticket.id,
        validatorId: widget.actorId,
        actorRole: widget.actorRole,
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
              ..validatorId = widget.actorId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(eventTicketsProvider(widget.eventId));
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(widget.eventId));

    if (eventAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || !eventAsync.hasValue) {
      return Scaffold(
        body: Center(
          child: Text('${eventAsync.error ?? 'Evento no encontrado'}'),
        ),
      );
    }

    final event = eventAsync.requireValue;
    final collaborators = collabsAsync.valueOrNull ?? const <Collaborator>[];
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
                Text(
                  widget.actorRole == 'organizer'
                      ? 'Estás validando como organizador.'
                      : 'Usá este acceso en el retiro del producto o en la entrada del evento.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
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
                ElevatedButton(
                  onPressed: _lookup,
                  child: const Text('Buscar'),
                ),
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
