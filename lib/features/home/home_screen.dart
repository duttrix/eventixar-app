import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Organizer home: Activos, Por pagar y Finalizados. Sin menú lateral.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final email = session.userEmail ?? '';

    if (session.userUid == null) {
      return const Scaffold(body: Center(child: Text('Sesión no iniciada.')));
    }

    final displayName = session.displayName;
    return ref.watch(organizerEventsProvider).when(
          loading: () => Scaffold(
            appBar: _appBar(context, ref, email, displayName: displayName),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: _appBar(context, ref, email, displayName: displayName),
            body: Center(child: Text('Error al cargar eventos: $e')),
          ),
          data: (events) => _buildScaffold(
            context,
            ref,
            email: email,
            displayName: displayName,
            all: events,
          ),
        );
  }

  PreferredSizeWidget _appBar(
    BuildContext context,
    WidgetRef ref,
    String email, {
    required String? displayName,
  }) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayName ?? email,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const Text('Mis eventos'),
        ],
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
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref, {
    required String email,
    required String? displayName,
    required List<Event> all,
  }) {
    final active =
        all.where((e) => e.status == EventStatus.active).toList();
    final awaitingPayment =
        all.where((e) => e.status == EventStatus.awaitingPayment).toList();
    final finished =
        all.where((e) => e.status == EventStatus.finished).toList();

    return Scaffold(
      appBar: _appBar(context, ref, email, displayName: displayName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/create-event'),
              icon: const Icon(Icons.add),
              label: const Text('Crear evento nuevo'),
            ),
          ),
          const SizedBox(height: 28),
          _EventSection(
            title: 'Activos',
            events: active,
            emptyText: 'Todavía no tenés eventos activos.',
            onTap: (event) {
              ref.read(sessionProvider.notifier).setCurrentEvent(event.id);
              context.push('/event/${event.id}');
            },
          ),
          const SizedBox(height: 24),
          _EventSection(
            title: 'Por pagar',
            events: awaitingPayment,
            emptyText: 'No hay eventos pendientes de pago.',
            onTap: (event) {
              ref.read(sessionProvider.notifier).setCurrentEvent(event.id);
              context.push('/create-event/pay/${event.id}');
            },
          ),
          const SizedBox(height: 24),
          _EventSection(
            title: 'Finalizados',
            events: finished,
            emptyText: 'Acá van a aparecer tus eventos finalizados.',
            onTap: (event) {
              ref.read(sessionProvider.notifier).setCurrentEvent(event.id);
              context.push('/event/${event.id}');
            },
          ),
        ],
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.title,
    required this.events,
    required this.emptyText,
    required this.onTap,
  });

  final String title;
  final List<Event> events;
  final String emptyText;
  final ValueChanged<Event> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (events.isEmpty)
          _EmptyHint(text: emptyText)
        else
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EventCard(
                event: event,
                onTap: () => onTap(event),
              ),
            ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(event.eventDate);
    final (label, tone) = switch (event.status) {
      EventStatus.active => ('Activo', BadgeTone.success),
      EventStatus.awaitingPayment => ('Pendiente de pago', BadgeTone.warn),
      EventStatus.finished => ('Finalizado', BadgeTone.neutral),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SectionCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateLabel · ${event.ticketCount} tickets · ${event.sellersCount} vend. · ${event.validatorsCount} val.',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(label: label, tone: tone),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.textMuted));
  }
}
