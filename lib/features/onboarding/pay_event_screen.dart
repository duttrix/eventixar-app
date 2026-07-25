import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/app_providers.dart';
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
      final updated = await ref
          .read(eventRepositoryProvider)
          .confirmPaymentAndGenerateTickets(widget.eventId);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Evento habilitado'),
          content: Text(
            'Evento habilitado. Se generaron ${updated.ticketCount} tickets. '
            'Ya podés invitar colaboradores y asignar tickets.',
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
    return ref.watch(eventProvider(widget.eventId)).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Pagar y habilitar')),
            body: Center(child: Text('No se pudo cargar el evento: $e')),
          ),
          data: _buildBody,
        );
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
          const SectionCard(
            title: 'Habilitación (provisorio)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todavía no hay checkout integrado. Al confirmar se habilita '
                  'el evento y se generan los tickets.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
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
                          : 'Confirmar y habilitar',
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _confirming ? null : () => context.go('/home'),
            child: const Text('Habilitar después'),
          ),
        ],
      ),
    );
  }
}
