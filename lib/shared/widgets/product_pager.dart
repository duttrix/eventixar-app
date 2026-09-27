import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event_product.dart';

/// Compact variant or product label that sits under the "Tickets" heading.
class ProductPager extends StatelessWidget {
  const ProductPager({
    super.key,
    required this.slices,
    required this.productCount,
    required this.index,
    required this.onChanged,
  });

  final List<TicketListSlice> slices;
  final int productCount;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (slices.length < 2) return const SizedBox.shrink();
    final current = index.clamp(0, slices.length - 1);
    final slice = slices[current];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              slice.title(productCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          for (var i = 0; i < slices.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: i == current ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == current
                        ? AppColors.emerald
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal flick over a ticket list. Vertical scrolling stays on the list.
class ProductSliceSwipe extends StatelessWidget {
  const ProductSliceSwipe({
    super.key,
    required this.index,
    required this.count,
    required this.onChanged,
    required this.child,
  });

  final int index;
  final int count;
  final ValueChanged<int> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250 && index < count - 1) onChanged(index + 1);
        if (velocity > 250 && index > 0) onChanged(index - 1);
      },
      child: child,
    );
  }
}
