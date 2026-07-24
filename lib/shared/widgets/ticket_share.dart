import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import 'access_share.dart';
import 'status_badge.dart';

/// Opens the device's native share sheet (WhatsApp, mail, etc.).
class TicketShare {
  TicketShare._();

  static String messageFor({
    required Ticket ticket,
    required Event event,
    String? sellerName,
  }) {
    final from = sellerName == null ? '' : ' (de $sellerName)';
    return '¡Hola! Te comparto tu ticket #${ticket.number} de "${event.name}"$from.\n'
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
}

/// Visual preview of the ticket (buyer view / mock image).
class TicketSharePreview extends StatelessWidget {
  const TicketSharePreview({super.key, required this.ticket, required this.event});

  final Ticket ticket;
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A5F), Color(0xFF378ADD)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'EVENTIXAR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              StatusBadge(label: ticket.status.label, tone: ticketStatusTone(ticket.status)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            event.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
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
                    const Text('TICKET', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                    Text(
                      '#${ticket.number}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
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
}
