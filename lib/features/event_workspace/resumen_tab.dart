import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/coupon.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/stat_card.dart';

/// Overview visible to every role: 6 stat tiles plus an estimated revenue
/// note, all computed from the event's mock aggregate coupon counts.
class ResumenTab extends ConsumerWidget {
  const ResumenTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final aggregate = repo.aggregateForEvent(eventId);
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

    final issued = repo.totalCouponsForEvent(eventId);
    final assigned = aggregate.entries
        .where((e) => e.key != CouponStatus.unassigned)
        .fold(0, (sum, e) => sum + e.value);
    final unassigned = aggregate[CouponStatus.unassigned] ?? 0;
    final collected = aggregate[CouponStatus.collected] ?? 0;
    final withSeller = aggregate[CouponStatus.withSeller] ?? 0;
    final delivered = aggregate[CouponStatus.delivered] ?? 0;
    final estimatedRevenue = collected * event.couponPrice;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatCard(label: 'Cupones emitidos', value: '$issued'),
            StatCard(label: 'Asignados a vendedores', value: '$assigned'),
            StatCard(label: 'Sin asignar', value: '$unassigned'),
            StatCard(label: 'Cobrados', value: '$collected', accentColor: AppColors.successText),
            StatCard(label: 'En poder del vendedor', value: '$withSeller', accentColor: AppColors.warnText),
            StatCard(label: 'Entregados en retiro', value: '$delivered', accentColor: AppColors.accentText),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: AppColors.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recaudación estimada (según cupones cobrados): ${currency.format(estimatedRevenue)}',
                  style: const TextStyle(color: AppColors.accentText, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
