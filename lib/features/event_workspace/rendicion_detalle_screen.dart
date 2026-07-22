import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/coupon.dart';
import '../../data/mock/providers.dart';

/// Rendición (accountability) screen for a single seller: mark each
/// individual coupon as Cobrado / En poder / Devuelto.
class RendicionDetalleScreen extends ConsumerWidget {
  const RendicionDetalleScreen({super.key, required this.eventId, required this.sellerId});

  final String eventId;
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorById(sellerId);
    final coupons = repo.couponsForSeller(sellerId)..sort((a, b) => a.number.compareTo(b.number));

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
              itemCount: coupons.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final coupon = coupons[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text('#${coupon.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: SegmentedButton<CouponStatus>(
                          segments: const [
                            ButtonSegment(
                              value: CouponStatus.collected,
                              label: Text('Cobrado'),
                              icon: Text('✅'),
                            ),
                            ButtonSegment(
                              value: CouponStatus.withSeller,
                              label: Text('En poder'),
                              icon: Text('🔄'),
                            ),
                            ButtonSegment(
                              value: CouponStatus.returned,
                              label: Text('Devuelto'),
                              icon: Text('↩️'),
                            ),
                          ],
                          selected: {coupon.status},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) {
                            ref.read(repositoryProvider).updateCouponStatus(coupon.id, selection.first);
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
