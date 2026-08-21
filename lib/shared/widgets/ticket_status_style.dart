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
    final (bg, fg) = badgeToneColors(tone);
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
    TicketStatus.settled => BadgeTone.settle,
    TicketStatus.returned => BadgeTone.danger,
    TicketStatus.delivered => BadgeTone.delivered,
  };
  return TicketStatusStyle.fromTone(tone);
}

/// Visual style for a ticket, including settle-mode nuance.
///
/// `settled` + `Solo ganancia` → warn; `settled` full → settle indigo.
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

/// Pill used in status summaries and ticket cards.
class TicketStatusPill extends StatelessWidget {
  const TicketStatusPill({
    super.key,
    required this.label,
    required this.style,
    this.count,
    this.selected = false,
    this.onTap,
    this.onWhite = false,
  });

  factory TicketStatusPill.forTicket(
    Ticket ticket, {
    Key? key,
    bool onWhite = true,
  }) {
    return TicketStatusPill(
      key: key,
      label: ticket.statusDisplayLabel,
      style: ticketStyle(ticket),
      onWhite: onWhite,
    );
  }

  final String label;
  final TicketStatusStyle style;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;

  /// When true (e.g. on a tinted ticket card), uses a white fill so the pill pops.
  final bool onWhite;

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label: $count';
    final bg = onWhite ? AppColors.card : style.background;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.accent
              : style.foreground.withValues(alpha: onWhite ? 0.35 : 0.0),
          width: selected ? 2 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style.foreground,
        ),
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

