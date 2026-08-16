import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import 'section_card.dart';

/// Shared event summary for collaborator portals (seller, validator, etc.).
class EventDetailsCard extends StatelessWidget {
  const EventDetailsCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(event.eventDate);
    final from = event.pickupFrom.format(context);
    final to = event.pickupTo.format(context);
    final place = event.pickupPlace.trim();
    final notes = event.notes.trim();

    return SectionCard(
      title: event.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Fecha y horario', '$dateLabel · $from – $to'),
          if (event.ticketProfit > 0) ...[
            const SizedBox(height: 8),
            _row('Ganancia', formatMoney(event.ticketProfit)),
          ],
          if (place.isNotEmpty) ...[
            const SizedBox(height: 8),
            _row('Retiro', place),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _row('Notas', notes),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
