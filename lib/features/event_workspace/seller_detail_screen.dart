import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Seller detail: assign ticket ranges + share access + status breakdown.
class SellerDetailScreen extends ConsumerWidget {
  const SellerDetailScreen({super.key, required this.eventId, required this.sellerId});

  final String eventId;
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorById(sellerId);
    final event = repo.eventById(eventId);
    final tickets = repo.ticketsForSeller(sellerId)..sort((a, b) => a.number.compareTo(b.number));
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(seller.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAssignmentDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Asignar rango'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SectionCard(
            title: 'Acceso',
            trailing: IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, ref, seller),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(seller.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Celular: ${seller.phone.isEmpty ? 'Sin celular' : seller.phone}'),
                const SizedBox(height: 4),
                Text(
                  seller.notes.isEmpty ? 'Notas: sin cargar' : 'Notas: ${seller.notes}',
                  style: TextStyle(
                    color: seller.notes.isEmpty ? AppColors.textMuted : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'El vendedor abre el link y ve sus tickets. No necesita registrarse.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SelectableText(seller.shareUrl, style: const TextStyle(fontSize: 13, color: AppColors.accent)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => AccessShare.copy(context, seller, eventName: event.name),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Compartir acceso (WhatsApp)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Estado de sus tickets',
            child: TicketStatusSummary(tickets: tickets),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Rangos asignados',
            child: seller.ranges.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Asigná un rango (ej. 1 a 50). El vendedor los ve al instante en su acceso.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Rango')),
                        DataColumn(label: Text('Cantidad')),
                        DataColumn(label: Text('Fecha')),
                      ],
                      rows: [
                        for (final range in seller.ranges)
                          DataRow(cells: [
                            DataCell(Text(range.label)),
                            DataCell(Text('${range.count}')),
                            DataCell(Text(dateFormat.format(range.date))),
                          ]),
                      ],
                    ),
                  ),
          ),
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Detalle ticket por ticket', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final ticket in tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: ticketStatusBg(ticket.status),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket #${ticket.number}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (ticket.buyerName.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Para: ${ticket.buyerName}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (ticket.collectorId != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Recaudó: ${repo.collaboratorById(ticket.collectorId!).name}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: ticket.status.label,
                        tone: ticketStatusTone(ticket.status),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Collaborator seller) {
    final nameController = TextEditingController(text: seller.name);
    final phoneController = TextEditingController(text: seller.phone);
    final notesController = TextEditingController(text: seller.notes);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar vendedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Celular (WhatsApp)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Ej. Vende en el barrio Alberdi',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              ref.read(repositoryProvider).updateCollaborator(
                    seller.id,
                    name: name,
                    phone: phoneController.text.trim(),
                    notes: notesController.text.trim(),
                  );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vendedor actualizado.')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddAssignmentDialog(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final nextNumber = repo.nextAvailableTicketNumber(eventId);
    final fromController = TextEditingController(text: '$nextNumber');
    final toController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar tickets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Desde',
                hintText: 'Próximo disponible: $nextNumber',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hasta'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final from = int.tryParse(fromController.text.trim());
              final to = int.tryParse(toController.text.trim());
              if (from == null || to == null || to < from) return;
              ref.read(repositoryProvider).assignTicketRange(sellerId: sellerId, from: from, to: to);
              Navigator.pop(dialogContext);
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }
}
