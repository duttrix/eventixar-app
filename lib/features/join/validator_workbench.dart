import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/qr_scan_screen.dart';
import '../../shared/widgets/section_card.dart';

/// Shared validate UI for the collaborator portal and the organizer workspace.
///
/// Flow: scan QR → if eligible, auto-validate → ready for the next scan.
class ValidatorWorkbench extends ConsumerStatefulWidget {
  const ValidatorWorkbench({
    super.key,
    required this.eventId,
    required this.actorId,
    required this.actorLabel,
    this.actorRole = 'validator',
    this.showLogout = false,
    this.embedded = false,
  });

  final String eventId;
  final String actorId;
  final String actorLabel;

  /// Stored on ticket history: `validator` | `organizer`.
  final String actorRole;
  final bool showLogout;

  /// When true, renders without its own [Scaffold]/[AppBar] (workspace tab).
  final bool embedded;

  @override
  ConsumerState<ValidatorWorkbench> createState() => _ValidatorWorkbenchState();
}

class _ValidatorWorkbenchState extends ConsumerState<ValidatorWorkbench> {
  String? _message;
  bool _success = false;
  int? _lastValidatedNumber;
  bool _busy = false;

  Future<void> _scanAndValidate() async {
    if (_busy) return;

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || raw == null) return;

    final parsed = ScannedTicketRef.parse(raw);
    if (parsed == null) {
      setState(() {
        _success = false;
        _lastValidatedNumber = null;
        _message = 'No reconocí ese QR. Probá de nuevo.';
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
          _success = false;
          _lastValidatedNumber = null;
          _message = 'Ese ticket es de otro evento.';
        });
        return;
      }
      ticket = tickets.where((t) => t.id == parsed.ticketId).firstOrNull;
    } else if (parsed.number != null) {
      ticket = tickets.where((t) => t.number == parsed.number).firstOrNull;
    }

    if (ticket == null) {
      setState(() {
        _success = false;
        _lastValidatedNumber = null;
        _message = 'Ticket no encontrado en este evento.';
      });
      return;
    }

    if (ticket.status == TicketStatus.delivered) {
      setState(() {
        _success = false;
        _lastValidatedNumber = ticket!.number;
        _message = 'Ticket #${ticket.number} ya estaba validado.';
      });
      return;
    }

    if (ticket.status != TicketStatus.collected &&
        ticket.status != TicketStatus.settled) {
      setState(() {
        _success = false;
        _lastValidatedNumber = ticket!.number;
        _message =
            'Ticket #${ticket.number} no figura como cobrado. Revisá con el organizador.';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      await deliverTicketAction(
        ref,
        eventId: ticket.eventId,
        ticketId: ticket.id,
        validatorId: widget.actorId,
        actorRole: widget.actorRole,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = true;
        _lastValidatedNumber = ticket!.number;
        _message = 'Ticket #${ticket.number} validado.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = false;
        _lastValidatedNumber = ticket!.number;
        _message = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(eventTicketsProvider(widget.eventId));
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    if (eventAsync.isLoading) {
      return _wrap(const Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || !eventAsync.hasValue) {
      return _wrap(
        Center(
          child: Text('${eventAsync.error ?? 'Evento no encontrado'}'),
        ),
      );
    }

    final event = eventAsync.requireValue;
    final hasResult = _message != null;
    final scanLabel = hasResult ? 'Escanear otro' : 'Escanear QR';

    return _wrap(
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: widget.embedded ? 'Validación' : event.name,
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
                      ? 'Escaneá el QR del ticket. Si está ok, se valida solo.'
                      : 'Escaneá el QR en el retiro o en la entrada. Si está ok, se valida solo.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _scanAndValidate,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_scanner),
            label: Text(_busy ? 'Validando…' : scanLabel),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _success ? AppColors.successBg : AppColors.warnBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _success ? AppColors.successText.withValues(alpha: 0.25) : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: _success
                            ? AppColors.successText
                            : AppColors.warnText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _success
                                ? AppColors.successText
                                : AppColors.warnText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_lastValidatedNumber != null && _success) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Listo para el siguiente QR.',
                      style: TextStyle(
                        color: AppColors.successText.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
    );
  }

  Widget _wrap(Widget body, {PreferredSizeWidget? appBar}) {
    if (widget.embedded) return body;
    return Scaffold(appBar: appBar, body: body);
  }
}
