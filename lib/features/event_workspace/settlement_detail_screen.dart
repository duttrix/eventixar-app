import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';

/// Per-seller settlement. Saving here does not finish the event.
class SettlementDetailScreen extends ConsumerWidget {
  const SettlementDetailScreen({super.key, required this.eventId, required this.sellerId});

  final String eventId;
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final seller = repo.collaboratorById(sellerId);
    final tickets = repo.ticketsForSeller(sellerId)..sort((a, b) => a.number.compareTo(b.number));
    final readOnly = event.status == EventStatus.finished;

    final collected = tickets
        .where((t) => t.status == TicketStatus.collected || t.status == TicketStatus.delivered)
        .length;
    final withSeller = tickets.where((t) => t.status == TicketStatus.withSeller).length;
    final returned = tickets.where((t) => t.status == TicketStatus.returned).length;
    final estimated = collected * event.ticketPrice;
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(readOnly ? 'Rendición (cerrada)' : 'Rendición · ${seller.name}'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seller.name, style: Theme.of(context).textTheme.titleMedium),
                if (seller.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(seller.notes, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _SummaryPill(label: 'Asignados', value: '${tickets.length}'),
                    _SummaryPill(label: 'Cobrados', value: '$collected'),
                    _SummaryPill(label: 'En poder', value: '$withSeller'),
                    _SummaryPill(label: 'Devueltos', value: '$returned'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Recaudación estimada: ${currency.format(estimated)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(repositoryProvider).markAllCollectedForSeller(sellerId),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Todos como cobrado'),
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: tickets.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final selected = ticket.status == TicketStatus.delivered
                    ? TicketStatus.collected
                    : (ticket.status == TicketStatus.unassigned
                        ? TicketStatus.withSeller
                        : ticket.status);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          '#${ticket.number}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: IgnorePointer(
                          ignoring: readOnly,
                          child: Opacity(
                            opacity: readOnly ? 0.55 : 1,
                            child: SegmentedButton<TicketStatus>(
                              segments: const [
                                ButtonSegment(
                                  value: TicketStatus.collected,
                                  label: Text('Cobrado'),
                                ),
                                ButtonSegment(
                                  value: TicketStatus.withSeller,
                                  label: Text('En poder'),
                                ),
                                ButtonSegment(
                                  value: TicketStatus.returned,
                                  label: Text('Devuelto'),
                                ),
                              ],
                              selected: {selected},
                              showSelectedIcon: false,
                              emptySelectionAllowed: false,
                              onSelectionChanged: (selection) {
                                ref
                                    .read(repositoryProvider)
                                    .updateTicketStatus(ticket.id, selection.first);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rendición guardada.')),
                    );
                    Navigator.of(context).maybePop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Guardar rendición'),
                  ),
                ),
              ),
            ),
      backgroundColor: AppColors.background,
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
