import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';

/// Payment screen. Confirming payment enables the event and generates tickets.
class PayEventScreen extends ConsumerStatefulWidget {
  const PayEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<PayEventScreen> createState() => _PayEventScreenState();
}

class _PayEventScreenState extends ConsumerState<PayEventScreen> {
  bool _confirming = false;

  Future<void> _confirm(Event event) async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final session = ref.read(sessionProvider);
      final Event updated;
      if (session.usesFirestore) {
        updated = await ref
            .read(eventRepositoryProvider)
            .confirmPaymentAndGenerateTickets(widget.eventId);
        final tickets =
            await ref.read(eventRepositoryProvider).listTickets(widget.eventId);
        final mock = ref.read(repositoryProvider);
        mock.upsertEvent(updated);
        mock.replaceTicketsForEvent(widget.eventId, tickets);
      } else {
        ref.read(repositoryProvider).confirmPayment(widget.eventId);
        updated = ref.read(repositoryProvider).eventById(widget.eventId);
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Evento habilitado'),
          content: Text(
            session.usesFirestore
                ? 'El pago fue aceptado (simulado). Se generaron ${updated.ticketCount} tickets. '
                    'Ya podés invitar colaboradores y asignar tickets.'
                : 'El pago fue aceptado (simulado). Ya podés asignar tickets a vendedores y compartirles el acceso.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/event/${widget.eventId}');
              },
              child: const Text('Ir al evento'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo habilitar el evento: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final Event? event;

    if (session.usesFirestore) {
      final async = ref.watch(ensureLocalEventProvider(widget.eventId));
      return async.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Pagar y habilitar')),
          body: Center(child: Text('No se pudo cargar el evento: $e')),
        ),
        data: (e) => _buildBody(e),
      );
    }

    event = ref.watch(repositoryProvider).tryEventById(widget.eventId);
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagar y habilitar')),
        body: const Center(child: Text('Evento no encontrado.')),
      );
    }
    return _buildBody(event);
  }

  Widget _buildBody(Event event) {
    final quote = event.quote;

    if (event.paid) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/event/${widget.eventId}'),
            child: const Text('Evento ya pagado · Ir al workspace'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar y habilitar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.priceLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                for (final line in quote.breakdown) ...[
                  Text(
                    line,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 8),
                Text(
                  'Se van a generar ${event.ticketCount} tickets al habilitar.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (quote.amount > 0)
            const SectionCard(
              title: 'Datos de pago (demo)',
              child: Column(
                children: [
                  _InfoRow(label: 'Alias', value: 'eventixar.mp'),
                  SizedBox(height: 6),
                  _InfoRow(label: 'CBU', value: '0000003100000012345678'),
                ],
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _confirming ? null : () => _confirm(event),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _confirming
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      quote.amount == 0
                          ? 'Habilitar gratis'
                          : 'Confirmar pago (simulado)',
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _confirming ? null : () => context.go('/home'),
            child: const Text('Pagar después'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
