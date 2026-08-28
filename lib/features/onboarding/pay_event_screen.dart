import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/section_card.dart';

/// Checkout placeholder. Tapping a pending event lands here; Pay stays
/// disabled until a real provider is wired.
class PayEventScreen extends ConsumerWidget {
  const PayEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(eventProvider(eventId)).when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Pagar')),
            body: Center(child: Text('No se pudo cargar el evento: $e')),
          ),
          data: (event) => _buildBody(context, ref, event),
        );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Event event) {
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

    final pricing = ref.watch(eventPricingProvider).asData?.value;
    final quote = pricing == null
        ? null
        : EventQuote.calculate(
            ticketCount: event.ticketCount,
            pricing: pricing,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quote != null) ...[
                  Text(
                    quote.priceLabel,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'El precio se calcula solo por cantidad de tickets.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se van a generar ${event.ticketCount} tickets al pagar.',
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
            title: 'Pago',
            child: Text(
              'Todavía no hay checkout integrado. Cuando esté listo, '
              'este botón va a habilitar el evento y generar los tickets.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const ElevatedButton(
            onPressed: null,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Pagar'),
            ),
          ),
        ],
      ),
    );
  }
}
