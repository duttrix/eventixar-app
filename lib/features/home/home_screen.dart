import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Organizer home: activos arriba, pasados con buscador. Sin menú lateral.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pastSearchController = TextEditingController();
  String _pastQuery = '';

  @override
  void dispose() {
    _pastSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    final filteredPast = _filterPast(past);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user?.name ?? email,
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
          if (past.isNotEmpty) ...[
            TextField(
              controller: _pastSearchController,
              onChanged: (value) => setState(() => _pastQuery = value.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _pastQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _pastSearchController.clear();
                          setState(() => _pastQuery = '');
                        },
                        icon: const Icon(Icons.clear, size: 18),
                      ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (past.isEmpty)
            const _EmptyHint(text: 'Acá van a aparecer tus eventos finalizados.')
          else if (filteredPast.isEmpty)
            const _EmptyHint(text: 'Ningún evento pasado coincide.')
          else
            for (final event in filteredPast)
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

  List<Event> _filterPast(List<Event> past) {
    if (_pastQuery.isEmpty) return past;
    final q = _pastQuery.toLowerCase();
    return past
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.product.toLowerCase().contains(q),
        )
        .toList();
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
                    '$dateLabel · ${event.ticketCount} tickets · ${event.sellersCount} vend. · ${event.validatorsCount} val.',
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
