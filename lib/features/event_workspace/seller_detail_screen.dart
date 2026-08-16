import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/delete_collaborator_button.dart';
import '../../shared/widgets/regenerate_access_button.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Seller detail: assign ranges, share access, return unsold tickets to the pool.
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
    final finished = event.status == EventStatus.finished;
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
    final token =
        ref
            .watch(
              collaboratorAccessTokenProvider((
                eventId: eventId,
                collaboratorId: sellerId,
              )),
            )
            .valueOrNull ??
        '';

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
              label: const Text('Asignar rango'),
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
          SectionCard(
            title: seller.name,
            trailing: IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, seller),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Celular: ${seller.phone.isEmpty ? 'Sin celular' : seller.phone}',
                ),
                const SizedBox(height: 4),
                Text(
                  seller.notes.isEmpty
                      ? 'Notas: sin cargar'
                      : 'Notas: ${seller.notes}',
                  style: TextStyle(
                    color: seller.notes.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => AccessShare.share(
                    context,
                    seller,
                    eventName: event.name,
                    token: token,
                  ),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Compartir acceso'),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: RegenerateAccessButton(
                        collaborator: seller,
                        eventName: event.name,
                      ),
                    ),
                    Expanded(
                      child: DeleteCollaboratorButton(
                        collaborator: seller,
                        onDeleted: () {
                          if (context.mounted) {
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Este vendedor no tiene tickets ahora. Asigná un rango '
                'con el botón de abajo.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Estado de sus tickets',
              child: TicketStatusSummary(
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
                    color: ticketStatusBg(ticket.status),
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
                              tone: ticketStatusTone(ticket.status),
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

  void _showEditDialog(BuildContext context, Collaborator seller) {
    final nameController = TextEditingController(text: seller.name);
    final phoneController = TextEditingController(text: seller.phone);
    final notesController = TextEditingController(text: seller.notes);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar vendedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Ej. Vende en el barrio Alberdi',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                await saveCollaborator(
                  ref,
                  eventId: eventId,
                  collaboratorId: seller.id,
                  name: name,
                  phone: phoneController.text.trim(),
                  notes: notesController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vendedor actualizado.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddAssignmentDialog(BuildContext context, List<Ticket> allTickets) {
    final unassigned =
        allTickets
            .where((t) => t.status.isAssignablePool)
            .map((t) => t.number)
            .toList()
          ..sort();
    final nextNumber = unassigned.isEmpty ? 1 : unassigned.first;
    final fromController = TextEditingController(text: '$nextNumber');
    final toController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar tickets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unassigned.isEmpty
                  ? 'No hay tickets disponibles en el pool.'
                  : '${unassigned.length} disponibles (sin vendedor / devueltos) · próximo: #$nextNumber',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fromController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Desde',
                hintText: 'Próximo disponible: $nextNumber',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hasta'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: unassigned.isEmpty
                ? null
                : () async {
                    final from = int.tryParse(fromController.text.trim());
                    final to = int.tryParse(toController.text.trim());
                    if (from == null || to == null || to < from) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rango inválido. Revisá "desde" y "hasta".',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await assignTicketRangeAction(
                        ref,
                        eventId: eventId,
                        sellerId: sellerId,
                        from: from,
                        to: to,
                        assignedByCollaboratorId: widget.actingCoordinatorId,
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Asignados #$from a #$to.')),
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
}
