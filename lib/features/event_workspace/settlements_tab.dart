import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/status_badge.dart';

/// Settlements roster: clear per-seller cards + finalize event (last step).
class SettlementsTab extends ConsumerWidget {
  const SettlementsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final finished = event.status == EventStatus.finished;
    final sellers = repo
        .sellersForEvent(eventId)
        .where((s) => repo.ticketsForSeller(s.id).isNotEmpty)
        .toList();

    if (sellers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ningún vendedor tiene tickets asignados todavía.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final pendingTickets = repo.hasPendingSettlementTickets(eventId);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              if (finished)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Evento finalizado. Las rendiciones quedan en solo consulta.',
                    style: TextStyle(
                      color: AppColors.successText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Cuadrá cada vendedor. Cuando esté todo, finalizá el evento: es el último paso.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              for (final seller in sellers)
                _SellerSettlementCard(
                  name: seller.name,
                  notes: seller.notes,
                  assigned: repo.ticketsForSeller(seller.id).length,
                  collected: repo
                      .ticketsForSeller(seller.id)
                      .where((t) => t.status == TicketStatus.collected || t.status == TicketStatus.delivered)
                      .length,
                  withSeller: repo
                      .ticketsForSeller(seller.id)
                      .where((t) => t.status == TicketStatus.withSeller)
                      .length,
                  returned: repo
                      .ticketsForSeller(seller.id)
                      .where((t) => t.status == TicketStatus.returned)
                      .length,
                  onTap: () => context.push('/event/$eventId/settlements/${seller.id}'),
                ),
            ],
          ),
        ),
        if (!finished)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _confirmFinish(
                    context,
                    ref,
                    hasPending: pendingTickets,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Finalizar evento'),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmFinish(
    BuildContext context,
    WidgetRef ref, {
    required bool hasPending,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar evento'),
        content: Text(
          hasPending
              ? 'Todavía hay tickets en poder de vendedores. Si finalizás igual, el evento queda cerrado y la operación pasa a solo consulta.'
              : 'Vas a marcar el evento como finalizado. Es el último paso: no vas a poder seguir editando la operación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(hasPending ? 'Finalizar igual' : 'Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ref.read(repositoryProvider).finishEvent(eventId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evento finalizado. Pasó a solo consulta.')),
    );
  }
}

class _SellerSettlementCard extends StatelessWidget {
  const _SellerSettlementCard({
    required this.name,
    required this.notes,
    required this.assigned,
    required this.collected,
    required this.withSeller,
    required this.returned,
    required this.onTap,
  });

  final String name;
  final String notes;
  final int assigned;
  final int collected;
  final int withSeller;
  final int returned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = withSeller == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  StatusBadge(
                    label: ready ? 'Lista' : 'Pendiente',
                    tone: ready ? BadgeTone.success : BadgeTone.warn,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(notes, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatChip(label: 'Asignados', value: '$assigned'),
                  _StatChip(label: 'Cobrados', value: '$collected'),
                  _StatChip(label: 'En poder', value: '$withSeller'),
                  _StatChip(label: 'Devueltos', value: '$returned'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

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
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
