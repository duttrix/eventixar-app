import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';

/// Mock payment screen. Confirming payment enables the event.
class PayEventScreen extends ConsumerWidget {
  const PayEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final quote = event.quote;

    if (event.paid) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/event/$eventId'),
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
                  Text(line, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (quote.amount > 0)
            SectionCard(
              title: 'Datos de pago (demo)',
              child: const Column(
                children: [
                  _InfoRow(label: 'Alias', value: 'eventixar.mp'),
                  SizedBox(height: 6),
                  _InfoRow(label: 'CBU', value: '0000003100000012345678'),
                ],
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.read(repositoryProvider).confirmPayment(eventId);
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Evento habilitado'),
                  content: const Text(
                    'El pago fue aceptado (simulado). Ya podés asignar tickets a vendedores y compartirles el acceso.',
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.go('/event/$eventId');
                      },
                      child: const Text('Ir al evento'),
                    ),
                  ],
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(quote.amount == 0 ? 'Habilitar gratis' : 'Confirmar pago (simulado)'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/home'),
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
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
