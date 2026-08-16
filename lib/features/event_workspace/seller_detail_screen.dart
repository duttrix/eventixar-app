import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/collaborator_profile_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Seller detail: assign tickets by quantity, share access, return to pool.
class SellerDetailScreen extends ConsumerStatefulWidget {
  const SellerDetailScreen({
    super.key,
    required this.eventId,
    required this.sellerId,
    this.actingCoordinatorId,
  });

  final String eventId;
  final String sellerId;

  /// When set, assignments are attributed to this coordinator.
  final String? actingCoordinatorId;

  @override
  ConsumerState<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends ConsumerState<SellerDetailScreen> {
  final Set<String> _returnIds = {};
  final Set<TicketStatus> _statusFilters = {};
  bool _returning = false;

  String get eventId => widget.eventId;
  String get sellerId => widget.sellerId;

  Future<void> _returnSelected(Event event) async {
    final ids = _returnIds.toList(growable: false);
    if (ids.isEmpty || _returning) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Devolver tickets'),
        content: Text(
          'Vas a liberar ${ids.length} ticket${ids.length == 1 ? '' : 's'} '
          'sin vender. Vuelven a “Sin vendedor” y los podés dar a otro vendedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Devolver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _returning = true);
    try {
      await returnTicketsToPoolAction(
        ref,
        eventId: eventId,
        ticketIds: ids,
        actorId: widget.actingCoordinatorId,
        actorRole: widget.actingCoordinatorId != null
            ? 'coordinator'
            : 'organizer',
      );
      if (!mounted) return;
      setState(() => _returnIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} ticket${ids.length == 1 ? '' : 's'} '
            'vuelve${ids.length == 1 ? '' : 'n'} al pool sin vendedor.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo devolver: $e')));
    } finally {
      if (mounted) setState(() => _returning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));

    if (eventAsync.isLoading ||
        collabsAsync.isLoading ||
        ticketsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventAsync.hasError || collabsAsync.hasError || ticketsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendedor')),
        body: Center(
          child: Text(
            '${eventAsync.error ?? collabsAsync.error ?? ticketsAsync.error}',
          ),
        ),
      );
    }

    final event = eventAsync.requireValue;
    final finished = event.isReadOnly;
    Collaborator? match;
    for (final c in collabsAsync.requireValue) {
      if (c.id == sellerId) {
        match = c;
        break;
      }
    }
    if (match == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final seller = match;
    final tickets =
        ticketsAsync.requireValue.where((t) => t.sellerId == sellerId).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    final returnable = tickets
        .where(
          (t) =>
              t.status == TicketStatus.withSeller ||
              t.status == TicketStatus.reserved,
        )
        .toList(growable: false);
    final allTickets = ticketsAsync.requireValue;
    final selectedReturnable = _returnIds
        .where((id) => returnable.any((t) => t.id == id))
        .toSet();
    final visibleTickets = _statusFilters.isEmpty
        ? tickets
        : tickets
              .where((t) => _statusFilters.contains(t.status))
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(seller.name)),
      floatingActionButton: finished
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddAssignmentDialog(context, allTickets),
              icon: const Icon(Icons.add),
              label: const Text('Asignar tickets'),
            ),
      bottomNavigationBar: !finished && selectedReturnable.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _returning ? null : () => _returnSelected(event),
                  icon: _returning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo),
                  label: Text(
                    'Devolver al pool (${selectedReturnable.length})',
                  ),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          CollaboratorProfileCard(
            eventId: eventId,
            collaboratorId: sellerId,
            expectedRole: CollaboratorRole.seller,
          ),
          if (tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Este vendedor no tiene tickets ahora. Asigná tickets '
                'con el botón de abajo.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            TicketStatusCard.summary(
              tickets: tickets,
              selected: _statusFilters,
              onStatusTap: (status) => setState(() {
                if (_statusFilters.contains(status)) {
                  _statusFilters.remove(status);
                  if (status == TicketStatus.withSeller ||
                      status == TicketStatus.reserved) {
                    _returnIds.removeWhere(
                      (id) => tickets.any(
                        (t) => t.id == id && t.status == status,
                      ),
                    );
                  }
                } else {
                  _statusFilters.add(status);
                  if (!finished &&
                      (status == TicketStatus.withSeller ||
                          status == TicketStatus.reserved)) {
                    _returnIds.addAll(
                      tickets
                          .where((t) => t.status == status)
                          .map((t) => t.id),
                    );
                  }
                }
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusFilters.isEmpty
                        ? 'Tickets (${tickets.length})'
                        : 'Tickets (${visibleTickets.length} de ${tickets.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_statusFilters.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_statusFilters.clear),
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (visibleTickets.isEmpty)
              const Text(
                'Ningún ticket con esos estados.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (final ticket in visibleTickets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: ticketBg(ticket),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap:
                          finished ||
                              (ticket.status != TicketStatus.withSeller &&
                                  ticket.status != TicketStatus.reserved)
                          ? null
                          : () => setState(() {
                              if (_returnIds.contains(ticket.id)) {
                                _returnIds.remove(ticket.id);
                              } else {
                                _returnIds.add(ticket.id);
                              }
                            }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedReturnable.contains(ticket.id)
                                ? AppColors.accent
                                : AppColors.border,
                            width: selectedReturnable.contains(ticket.id)
                                ? 1.5
                                : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (!finished &&
                                (ticket.status == TicketStatus.withSeller ||
                                    ticket.status == TicketStatus.reserved))
                              Checkbox(
                                value: selectedReturnable.contains(ticket.id),
                                onChanged: (_) => setState(() {
                                  if (_returnIds.contains(ticket.id)) {
                                    _returnIds.remove(ticket.id);
                                  } else {
                                    _returnIds.add(ticket.id);
                                  }
                                }),
                                visualDensity: VisualDensity.compact,
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ticket #${ticket.number}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (ticket.buyerName.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Para: ${ticket.buyerName}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: ticket.status.label,
                              tone: ticketTone(ticket),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  void _showAddAssignmentDialog(BuildContext context, List<Ticket> allTickets) {
    final pool = allTickets.where((t) => t.status.isAssignablePool).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final countController = TextEditingController(
      text: pool.isEmpty ? '' : '1',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar tickets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pool.isEmpty
                  ? 'No hay tickets disponibles en el pool.'
                  : '${pool.length} disponibles en el pool (sin vendedor / '
                      'devueltos). Se asignan los próximos en orden.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countController,
              enabled: pool.isNotEmpty,
              autofocus: pool.isNotEmpty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                hintText: pool.isEmpty ? null : 'Máx. ${pool.length}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: pool.isEmpty
                ? null
                : () async {
                    final count = int.tryParse(countController.text.trim());
                    if (count == null || count < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresá una cantidad válida.'),
                        ),
                      );
                      return;
                    }
                    if (count > pool.length) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Solo hay ${pool.length} tickets disponibles.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      final selected = pool.take(count).toList(growable: false);
                      final ranges = _contiguousRanges(
                        selected.map((t) => t.number),
                      );
                      for (final range in ranges) {
                        await assignTicketRangeAction(
                          ref,
                          eventId: eventId,
                          sellerId: sellerId,
                          from: range.$1,
                          to: range.$2,
                          assignedByCollaboratorId: widget.actingCoordinatorId,
                        );
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!context.mounted) return;
                      final from = selected.first.number;
                      final to = selected.last.number;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            count == 1
                                ? 'Asignado 1 ticket (#$from).'
                                : 'Asignados $count tickets (#$from–#$to).',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }

  /// Groups sorted ticket numbers into inclusive (from, to) contiguous ranges.
  List<(int, int)> _contiguousRanges(Iterable<int> numbers) {
    final sorted = numbers.toList()..sort();
    if (sorted.isEmpty) return const [];
    final ranges = <(int, int)>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final n = sorted[i];
      if (n == prev + 1) {
        prev = n;
        continue;
      }
      ranges.add((start, prev));
      start = n;
      prev = n;
    }
    ranges.add((start, prev));
    return ranges;
  }
}
