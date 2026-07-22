import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Organizer home: past events + create new. Nothing else.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final session = ref.watch(sessionProvider);
    final email = session.userEmail;

    if (email == null) {
      return const Scaffold(body: Center(child: Text('Sesión no iniciada.')));
    }

    final user = repo.userByEmail(email);
    final all = repo.eventsForOwner(email);
    final upcoming = all.where((e) => !e.isPast).toList();
    final past = all.where((e) => e.isPast).toList();

    return AppShell(
      title: 'Mis eventos',
      subtitle: user?.name ?? email,
      navItems: [
        ShellNavItem(icon: Icons.home_outlined, label: 'Mis eventos', selected: true, onTap: () {}),
        ShellNavItem(
          icon: Icons.add_circle_outline,
          label: 'Crear evento',
          selected: false,
          onTap: () => context.push('/create-event'),
        ),
      ],
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
          Text('Activos y por pagar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const _EmptyHint(text: 'Todavía no tenés eventos. Creá el primero.')
          else
            for (final event in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventCard(
                  event: event,
                  onTap: () {
                    ref.read(sessionProvider.notifier).setCurrentEvent(event.id);
                    if (event.status == EventStatus.awaitingPayment) {
                      context.push('/create-event/pay/${event.id}');
                    } else {
                      context.push('/event/${event.id}');
                    }
                  },
                ),
              ),
          const SizedBox(height: 24),
          Text('Eventos pasados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (past.isEmpty)
            const _EmptyHint(text: 'Acá van a aparecer tus eventos finalizados.')
          else
            for (final event in past)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventCard(
                  event: event,
                  onTap: () {
                    ref.read(sessionProvider.notifier).setCurrentEvent(event.id);
                    context.push('/event/${event.id}');
                  },
                ),
              ),
        ],
      ),
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
                  Text(event.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$dateLabel · ${event.couponCount} cupones · ${event.sellersCount} vend. · ${event.deliverersCount} ent.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
