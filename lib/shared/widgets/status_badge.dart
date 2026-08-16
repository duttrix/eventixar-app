import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Semantic tone for pills/badges. Colors live in [TicketStatusStyle.fromTone].
enum BadgeTone { success, danger, warn, info, neutral }

/// Small colored pill used to show a status (event state, ticket state, etc.).
///
/// Colors come from [TicketStatusStyle.fromTone] so badges match ticket chips/rows.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    // Inline map kept here to avoid circular imports with ticket_status_style.
    // Must match TicketStatusStyle.fromTone.
    final (Color bg, Color fg) = switch (tone) {
      BadgeTone.success => (AppColors.successBg, AppColors.successText),
      BadgeTone.danger => (AppColors.dangerBg, AppColors.dangerText),
      BadgeTone.warn => (AppColors.warnBg, AppColors.warnText),
      BadgeTone.info => (AppColors.accentBg, AppColors.accentText),
      BadgeTone.neutral => (AppColors.border, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
