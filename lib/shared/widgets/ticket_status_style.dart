import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import 'status_badge.dart';

/// Single source of truth for ticket status colors (rows, chips, badges).
class TicketStatusStyle {
  const TicketStatusStyle({
    required this.tone,
    required this.background,
    required this.foreground,
  });

  final BadgeTone tone;
  final Color background;
  final Color foreground;

  factory TicketStatusStyle.fromTone(BadgeTone tone) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.successBg, AppColors.successText),
      BadgeTone.danger => (AppColors.dangerBg, AppColors.dangerText),
      BadgeTone.warn => (AppColors.warnBg, AppColors.warnText),
      BadgeTone.info => (AppColors.accentBg, AppColors.accentText),
      BadgeTone.neutral => (AppColors.border, AppColors.textSecondary),
    };
    return TicketStatusStyle(tone: tone, background: bg, foreground: fg);
  }
}

/// Visual style for a [TicketStatus] (no settle-mode nuance).
TicketStatusStyle ticketStatusStyle(TicketStatus status) {
  final tone = switch (status) {
    TicketStatus.unassigned => BadgeTone.neutral,
    TicketStatus.withSeller => BadgeTone.warn,
    TicketStatus.reserved => BadgeTone.info,
    TicketStatus.collected => BadgeTone.success,
    TicketStatus.settled => BadgeTone.success,
    TicketStatus.returned => BadgeTone.danger,
    TicketStatus.delivered => BadgeTone.info,
  };
  return TicketStatusStyle.fromTone(tone);
}

/// Visual style for a ticket, including settle-mode nuance.
///
/// `settled` + `Solo ganancia` → warn; `settled` full → success.
TicketStatusStyle ticketStyle(Ticket ticket) {
  if (ticket.status == TicketStatus.settled &&
      ticket.settleMode == TicketSettleMode.profit) {
    return TicketStatusStyle.fromTone(BadgeTone.warn);
  }
  return ticketStatusStyle(ticket.status);
}

/// Style for collector filters that are not plain [TicketStatus] values.
TicketStatusStyle collectorFilterStyle({
  required bool validated,
  required bool fullSettle,
  required bool profitSettle,
}) {
  if (profitSettle) return TicketStatusStyle.fromTone(BadgeTone.warn);
  if (fullSettle) return ticketStatusStyle(TicketStatus.settled);
  if (validated) return ticketStatusStyle(TicketStatus.delivered);
  return TicketStatusStyle.fromTone(BadgeTone.neutral);
}

// --- Compatibility helpers (prefer [ticketStatusStyle] / [ticketStyle]) ---

BadgeTone ticketStatusTone(TicketStatus status) =>
    ticketStatusStyle(status).tone;

BadgeTone ticketTone(Ticket ticket) => ticketStyle(ticket).tone;

Color ticketStatusBg(TicketStatus status) =>
    ticketStatusStyle(status).background;

Color ticketBg(Ticket ticket) => ticketStyle(ticket).background;
