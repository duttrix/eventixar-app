import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import 'access_share.dart';
import 'ticket_status_style.dart';

/// Ticket row used by organizer and seller lists.
class TicketListCard extends StatelessWidget {
  const TicketListCard({
    super.key,
    required this.ticket,
    required this.event,
    required this.readOnly,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    this.onLongPress,
    this.sellerLabel,
    this.onCollect,
    this.onReserve,
    this.onSetBuyer,
    this.onAssignSeller,
    this.onClearReservation,
    this.onReturnToPool,
    this.clearReservationLabel = 'Liberar reserva',
    this.onPrint,
    this.onShare,
  });

  final Ticket ticket;
  final Event event;
  final bool readOnly;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback? onLongPress;
  final String? sellerLabel;
  final VoidCallback? onCollect;
  final VoidCallback? onReserve;
  final VoidCallback? onSetBuyer;
  final VoidCallback? onAssignSeller;
  final VoidCallback? onClearReservation;
  final VoidCallback? onReturnToPool;
  final String clearReservationLabel;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  bool get _canCollect =>
      onCollect != null && !readOnly && ticket.status.isSellable;

  bool get _canReserve =>
      onReserve != null &&
      !readOnly &&
      ticket.status.isSellable &&
      ticket.status != TicketStatus.reserved;

  bool get _canSetBuyer =>
      onSetBuyer != null &&
      !readOnly &&
      (ticket.status == TicketStatus.reserved ||
          ticket.status == TicketStatus.collected ||
          ticket.status == TicketStatus.settled ||
          ticket.status == TicketStatus.delivered ||
          ticket.status == TicketStatus.withSeller);

  bool get _canAssignSeller =>
      onAssignSeller != null && !readOnly && ticket.status.canAssignToSeller;

  bool get _canClearReservation =>
      onClearReservation != null &&
      !readOnly &&
      ticket.status == TicketStatus.reserved;

  bool get _canReturnToPool =>
      onReturnToPool != null &&
      !readOnly &&
      (ticket.status == TicketStatus.withSeller ||
          ticket.status == TicketStatus.reserved);

  bool get _canExport =>
      !readOnly && (onPrint != null || onShare != null);

  @override
  Widget build(BuildContext context) {
    final buyer = ticket.buyerName.trim();
    final seller = sellerLabel?.trim() ?? '';
    final style = ticketStyle(ticket);
    final bg = selected
        ? Color.alphaBlend(
            AppColors.accent.withValues(alpha: 0.12),
            style.background,
          )
        : style.background;
    final borderColor = selected
        ? AppColors.accent
        : Color.alphaBlend(
            style.foreground.withValues(alpha: 0.22),
            style.background,
          );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selectionMode ? onToggleSelect : null,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          padding: EdgeInsets.fromLTRB(selectionMode ? 6 : 14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect(),
                      visualDensity: VisualDensity.compact,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Ticket #${ticket.number}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TicketStatusPill.forTicket(ticket),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${event.ticketPrice.toStringAsFixed(0)} · ${event.product}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (buyer.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Para: $buyer',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (seller.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Vendedor: $seller',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!readOnly && !selectionMode)
                    IconButton(
                      tooltip: 'Más acciones',
                      onPressed: () => _openActions(context),
                      icon: const Icon(Icons.more_horiz),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (_canCollect && !selectionMode) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton(
                    onPressed: onCollect,
                    child: const Text('Cobrar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    final buyer = ticket.buyerName.trim();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ticket #${ticket.number}',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (_canCollect)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Cobrar'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onCollect?.call();
                    },
                  ),
                if (_canReserve)
                  ListTile(
                    leading: const Icon(Icons.bookmark_add_outlined),
                    title: const Text('Reservar'),
                    subtitle: const Text('Pide destinatario y marca reservado'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReserve?.call();
                    },
                  ),
                if (_canSetBuyer)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      buyer.isEmpty ? 'Destinatario' : 'Editar destinatario',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSetBuyer?.call();
                    },
                  ),
                if (_canAssignSeller)
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(
                      ticket.status.isAssignablePool
                          ? 'Asignar vendedor'
                          : 'Cambiar vendedor',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onAssignSeller?.call();
                    },
                  ),
                if (_canClearReservation)
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(clearReservationLabel),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onClearReservation?.call();
                    },
                  ),
                if (_canReturnToPool)
                  ListTile(
                    leading: const Icon(Icons.undo),
                    title: const Text('Devolver al pool'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReturnToPool?.call();
                    },
                  ),
                if (_canExport) ...[
                  if (onPrint != null)
                    ListTile(
                      leading: const Icon(Icons.print_outlined),
                      title: const Text('Imprimir'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onPrint?.call();
                      },
                    ),
                  if (onShare != null)
                    ListTile(
                      leading: const Icon(AccessShare.shareIcon),
                      title: const Text('Compartir'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onShare?.call();
                      },
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
