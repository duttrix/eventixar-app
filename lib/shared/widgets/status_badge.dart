import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Semantic tone for pills/badges. Colors live in [TicketStatusStyle.fromTone]
/// and are mirrored here for [StatusBadge] (avoids circular imports).
enum BadgeTone { success, danger, warn, info, settle, delivered, accent, neutral }

/// Shared (bg, fg) for a [BadgeTone]. Keep in sync with [StatusBadge].
(Color, Color) badgeToneColors(BadgeTone tone) => switch (tone) {
      BadgeTone.success => (AppColors.successBg, AppColors.successText),
      BadgeTone.danger => (AppColors.dangerBg, AppColors.dangerText),
      BadgeTone.warn => (AppColors.warnBg, AppColors.warnText),
      BadgeTone.info => (AppColors.infoBg, AppColors.infoText),
      BadgeTone.settle => (AppColors.settleBg, AppColors.settleText),
      BadgeTone.delivered => (AppColors.deliveredBg, AppColors.deliveredText),
      BadgeTone.accent => (AppColors.accentBg, AppColors.accentText),
      BadgeTone.neutral => (AppColors.border, AppColors.textSecondary),
    };

/// Small colored pill used to show a status (event state, ticket state, etc.).
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
    final (bg, fg) = badgeToneColors(tone);

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
