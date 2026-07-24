import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import 'access_share.dart';
import 'status_badge.dart';

/// Share de un ticket individual.
///
/// Producto: el default es una **imagen** (PNG/JPG) del ticket vía share sheet.
/// El **PDF** queda para imprimir lotes, no para este flujo.
/// Demo actual: comparte texto + link (aún no genera la imagen).
class TicketShare {
  TicketShare._();

  static String messageFor({
    required Ticket ticket,
    required Event event,
    String? sellerName,
  }) {
    final from = sellerName == null ? '' : ' (de $sellerName)';
    final para = ticket.buyerName.trim().isEmpty ? '' : 'Para: ${ticket.buyerName.trim()}\n';
    return '¡Hola! Te comparto tu ticket #${ticket.number} de "${event.name}"$from.\n'
        '$para'
        '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)}\n'
        'Abrí el link para verlo (no necesitás registrarte):\n'
        '${ticket.shareUrl}';
  }

  static Future<void> share({
    required Ticket ticket,
    required Event event,
    String? sellerName,
  }) {
    return Share.share(
      messageFor(ticket: ticket, event: event, sellerName: sellerName),
      subject: 'Ticket #${ticket.number} · ${event.name}',
    );
  }

  /// Share several tickets as a list of links (demo / WhatsApp text).
  static Future<void> shareMany({
    required List<Ticket> tickets,
    required Event event,
    String? sellerName,
    String? note,
  }) {
    if (tickets.isEmpty) return Future.value();
    if (tickets.length == 1) {
      final t = tickets.first;
      final from = sellerName == null ? '' : ' (de $sellerName)';
      final para = t.buyerName.trim().isEmpty ? '' : 'Para: ${t.buyerName.trim()}\n';
      final noteLine = (note == null || note.trim().isEmpty) ? '' : '\nDetalle: ${note.trim()}\n';
      return Share.share(
        '¡Hola! Te comparto tu ticket #${t.number} de "${event.name}"$from.\n'
        '$para'
        '$noteLine'
        '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)}\n'
        'Abrí el link para verlo (no necesitás registrarte):\n'
        '${t.shareUrl}',
        subject: 'Ticket #${t.number} · ${event.name}',
      );
    }
    final from = sellerName == null ? '' : ' (de $sellerName)';
    final lines = tickets.map((t) {
      final para = t.buyerName.trim().isEmpty ? '' : ' · ${t.buyerName.trim()}';
      return '• Ticket #${t.number}$para: ${t.shareUrl}';
    }).join('\n');
    final noteLine = (note == null || note.trim().isEmpty) ? '' : '\n\nDetalle: ${note.trim()}';
    return Share.share(
      '¡Hola! Te comparto ${tickets.length} tickets de "${event.name}"$from.\n'
      '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)} c/u\n\n'
      '$lines$noteLine',
      subject: '${tickets.length} tickets · ${event.name}',
    );
  }
}

enum TicketBackgroundMode { solid, gradient, image }

enum TicketTypographyStyle { system, featured, compact }

/// Visual knobs for the ticket card (demo design editor).
class TicketVisualStyle {
  const TicketVisualStyle({
    this.primary = const Color(0xFF1B3A5F),
    this.accent = const Color(0xFF378ADD),
    this.backgroundMode = TicketBackgroundMode.gradient,
    this.typography = TicketTypographyStyle.system,
  });

  final Color primary;
  final Color accent;
  final TicketBackgroundMode backgroundMode;
  final TicketTypographyStyle typography;

  static const classic = TicketVisualStyle();

  static const festive = TicketVisualStyle(
    primary: Color(0xFF7A1F2B),
    accent: Color(0xFFE8A838),
    backgroundMode: TicketBackgroundMode.gradient,
    typography: TicketTypographyStyle.featured,
  );

  static const dark = TicketVisualStyle(
    primary: Color(0xFF111827),
    accent: Color(0xFF6B7280),
    backgroundMode: TicketBackgroundMode.solid,
    typography: TicketTypographyStyle.compact,
  );

  static const institutional = TicketVisualStyle(
    primary: Color(0xFF14532D),
    accent: Color(0xFF86EFAC),
    backgroundMode: TicketBackgroundMode.gradient,
    typography: TicketTypographyStyle.system,
  );

  TicketVisualStyle copyWith({
    Color? primary,
    Color? accent,
    TicketBackgroundMode? backgroundMode,
    TicketTypographyStyle? typography,
  }) {
    return TicketVisualStyle(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      typography: typography ?? this.typography,
    );
  }

  FontWeight get titleWeight => switch (typography) {
        TicketTypographyStyle.system => FontWeight.w800,
        TicketTypographyStyle.featured => FontWeight.w900,
        TicketTypographyStyle.compact => FontWeight.w700,
      };

  double get titleSize => switch (typography) {
        TicketTypographyStyle.system => 18,
        TicketTypographyStyle.featured => 20,
        TicketTypographyStyle.compact => 16,
      };

  double get numberSize => switch (typography) {
        TicketTypographyStyle.system => 28,
        TicketTypographyStyle.featured => 32,
        TicketTypographyStyle.compact => 24,
      };

  double get titleLetterSpacing => switch (typography) {
        TicketTypographyStyle.system => 0,
        TicketTypographyStyle.featured => 0.4,
        TicketTypographyStyle.compact => -0.2,
      };
}

/// Visual preview of the ticket (buyer view / mock image).
class TicketSharePreview extends StatelessWidget {
  const TicketSharePreview({
    super.key,
    required this.ticket,
    required this.event,
    this.style = TicketVisualStyle.classic,
  });

  final Ticket ticket;
  final Event event;
  final TicketVisualStyle style;

  @override
  Widget build(BuildContext context) {
    final decoration = switch (style.backgroundMode) {
      TicketBackgroundMode.solid => BoxDecoration(
          color: style.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _shadow,
        ),
      TicketBackgroundMode.gradient => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [style.primary, style.accent],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _shadow,
        ),
      TicketBackgroundMode.image => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              style.primary.withValues(alpha: 0.92),
              style.accent.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: _shadow,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'EVENTIXAR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: style.typography == TicketTypographyStyle.compact ? 0.6 : 1.2,
                ),
              ),
              if (style.backgroundMode == TicketBackgroundMode.image) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'FONDO EJEMPLO',
                    style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const Spacer(),
              StatusBadge(label: ticket.status.label, tone: ticketStatusTone(ticket.status)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            event.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: style.titleSize,
              fontWeight: style.titleWeight,
              letterSpacing: style.titleLetterSpacing,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TICKET',
                      style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1),
                    ),
                    Text(
                      '#${ticket.number}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: style.numberSize,
                        fontWeight: style.titleWeight,
                      ),
                    ),
                    if (ticket.buyerName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Para: ${ticket.buyerName.trim()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: style.accent, width: 2),
                ),
                child: const Icon(Icons.qr_code_2, size: 56, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Retiro / entrada · ${event.pickupPlace}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static final List<BoxShadow> _shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
