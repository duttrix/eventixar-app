import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/ticket.dart';
import '../../shared/ticket_pdf.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/ticket_share.dart';

/// Tickets by status + PDF print action + visual preview of one ticket.
class TicketsTab extends ConsumerWidget {
  const TicketsTab({super.key, required this.eventId});

  final String eventId;

  void _openDesign(BuildContext context) {
    context.push('/event/$eventId/ticket-design');
  }

  Future<void> _printPdf(BuildContext context, WidgetRef ref) async {
    final event = ref.read(eventProvider(eventId)).valueOrNull;
    final tickets = ref.read(eventTicketsProvider(eventId)).valueOrNull;
    if (event == null || tickets == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todavía se están cargando los tickets.')),
      );
      return;
    }
    try {
      await TicketPdf.printTickets(event: event, tickets: tickets);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody(
      value: ref.watch(eventProvider(eventId)),
      builder: (context, event) {
        return AsyncBody(
          value: ref.watch(eventTicketAggregateProvider(eventId)),
          builder: (context, aggregate) {
            final sellers =
                ref.watch(eventSellersProvider(eventId)).valueOrNull ??
                    const [];
            final total = aggregate.values.fold(0, (sum, n) => sum + n);
            final issued = total == 0 ? event.ticketCount : total;

            final previewTicket = Ticket(
              id: 'preview_$eventId',
              eventId: eventId,
              number: 1,
              status: TicketStatus.collected,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Tickets por estado',
                  child: Column(
                    children: [
                      for (final status in TicketStatus.values)
                        if (status != TicketStatus.unassigned ||
                            sellers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(status.label)),
                                Text(
                                  '${aggregate[status] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '$issued',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _printPdf(context, ref),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      'Generar PDF para imprimir'
                      '${issued > 0 ? ' ($issued)' : ''}',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Vista previa',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tocá el ticket para editar el diseño.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openDesign(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        TicketSharePreview(
                          ticket: previewTicket,
                          event: event,
                          style: event.ticketDesign,
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Editar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
