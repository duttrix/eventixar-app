import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/coupon.dart';
import '../../data/mock/providers.dart';

/// Visible to Administrador and Vendedor: pick which seller to render
/// accounts for (only sellers that actually have coupons assigned).
class RendicionesTab extends ConsumerWidget {
  const RendicionesTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final sellers = repo
        .sellersForEvent(eventId)
        .where((s) => repo.couponsForSeller(s.id).isNotEmpty)
        .toList();

    if (sellers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Ningún vendedor tiene cupones asignados todavía.'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Asignados')),
              DataColumn(label: Text('Cobrados')),
              DataColumn(label: Text('Devueltos')),
              DataColumn(label: Text('Pendiente')),
            ],
            rows: [
              for (final seller in sellers)
                DataRow(
                  onSelectChanged: (_) => context.push('/event/$eventId/rendiciones/${seller.id}'),
                  cells: [
                    DataCell(Text(seller.name)),
                    DataCell(Text('${repo.couponsForSeller(seller.id).length}')),
                    DataCell(Text(
                        '${repo.couponsForSeller(seller.id).where((c) => c.status == CouponStatus.collected).length}')),
                    DataCell(Text(
                        '${repo.couponsForSeller(seller.id).where((c) => c.status == CouponStatus.returned).length}')),
                    DataCell(Text('${repo.couponsForSeller(seller.id).where((c) => c.status == CouponStatus.withSeller).length}')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}