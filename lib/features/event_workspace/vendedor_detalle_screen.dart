import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';

/// Seller detail: assign coupon ranges + share deeplink.
class VendedorDetalleScreen extends ConsumerWidget {
  const VendedorDetalleScreen({super.key, required this.eventId, required this.sellerId});

  final String eventId;
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorById(sellerId);
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
            title: 'Datos y acceso',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Celular: ${seller.phone}'),
                if (seller.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(seller.notes, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 12),
                SelectableText(seller.shareUrl, style: const TextStyle(fontSize: 13, color: AppColors.accent)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: seller.shareUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deeplink copiado. Envíalo por WhatsApp.')),
                    );
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Copiar deeplink'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Rangos de cupones',
            child: seller.ranges.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Asigná un rango (ej. 1 a 50). El vendedor los ve al instante en su link.',
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
        ],
      ),
    );
  }

  void _showAddAssignmentDialog(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final nextNumber = repo.nextAvailableCouponNumber(eventId);
    final fromController = TextEditingController(text: '$nextNumber');
    final toController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar cupones'),
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
              ref.read(repositoryProvider).assignCouponRange(sellerId: sellerId, from: from, to: to);
              Navigator.pop(dialogContext);
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }
}
