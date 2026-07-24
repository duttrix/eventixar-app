import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';

/// Admin-only: breakdown of tickets by status, plus a simulated
/// generate/reprint PDF action.
class TicketsTab extends ConsumerWidget {
  const TicketsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final aggregate = repo.aggregateForEvent(eventId);
    final total = repo.totalTicketsForEvent(eventId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Tickets por estado',
          child: Column(
            children: [
              for (final status in TicketStatus.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(status.label)),
                      Text(
                        '${aggregate[status] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text('$total', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final sheets = (total / 6).ceil();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Generando PDF de $total tickets, 6 por hoja A4 ($sheets hojas).'),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generar / reimprimir PDF'),
          ),
        ),
      ],
    );
  }
}
