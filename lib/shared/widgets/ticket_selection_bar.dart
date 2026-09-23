import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Bottom bar while multi-selecting tickets.
class TicketSelectionBar extends StatelessWidget {
  const TicketSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    this.onMore,
    this.primaryLabel,
    this.onPrimary,
  });

  final int selectedCount;
  final VoidCallback? onMore;
  final VoidCallback onClear;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$selectedCount seleccionados',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (primaryLabel != null) ...[
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
                const SizedBox(width: 4),
              ],
              if (onMore != null)
                IconButton(
                  tooltip: 'Más acciones',
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz),
                ),
              IconButton(
                tooltip: 'Cancelar selección',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
