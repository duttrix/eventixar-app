import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';

/// Rendición (accountability) screen for a single seller: mark each
/// individual ticket as Cobrado / En poder / Devuelto.
class SettlementDetailScreen extends ConsumerWidget {
  const SettlementDetailScreen({super.key, required this.eventId, required this.sellerId});

  final String eventId;
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorById(sellerId);
    final tickets = repo.ticketsForSeller(sellerId)..sort((a, b) => a.number.compareTo(b.number));

    return Scaffold(
      appBar: AppBar(title: Text('Rendición · ${seller.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(repositoryProvider).markAllCollectedForSeller(sellerId),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Todos como cobrado'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: tickets.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text('#${ticket.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: SegmentedButton<TicketStatus>(
                          segments: const [
                            ButtonSegment(
                              value: TicketStatus.collected,
                              label: Text('Cobrado'),
                              icon: Text('✅'),
                            ),
                            ButtonSegment(
                              value: TicketStatus.withSeller,
                              label: Text('En poder'),
                              icon: Text('🔄'),
                            ),
                            ButtonSegment(
                              value: TicketStatus.returned,
                              label: Text('Devuelto'),
                              icon: Text('↩️'),
                            ),
                          ],
                          selected: {ticket.status},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) {
                            ref.read(repositoryProvider).updateTicketStatus(ticket.id, selection.first);
                          },
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
      bottomNavigationBar: SafeArea(
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
