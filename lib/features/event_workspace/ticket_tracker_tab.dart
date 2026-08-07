import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/access_share.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Organizer tool: look up a ticket by number and show its movement history.
class TicketTrackerTab extends ConsumerStatefulWidget {
  const TicketTrackerTab({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketTrackerTab> createState() => _TicketTrackerTabState();
}

class _TicketTrackerTabState extends ConsumerState<TicketTrackerTab> {
  final _controller = TextEditingController();
  int? _searchedNumber;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final raw = _controller.text.trim();
    final number = int.tryParse(raw);
    if (number == null || number <= 0) {
      setState(() {
        _error = 'Ingresá un número de ticket válido.';
        _searchedNumber = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _searchedNumber = number;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(eventTicketsProvider(widget.eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(widget.eventId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        SectionCard(
          title: 'Rastrear ticket',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Buscá por número y ves el historial de movimientos: '
                'quién lo asignó, cobró, rindió, validó o devolvió.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Número de ticket',
                        hintText: 'Ej. 18',
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.dangerText),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_searchedNumber != null)
          ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('No se pudieron cargar tickets: $e'),
            data: (tickets) {
              Ticket? ticket;
              for (final t in tickets) {
                if (t.number == _searchedNumber) {
                  ticket = t;
                  break;
                }
              }
              if (ticket == null) {
                return SectionCard(
                  title: 'Resultado',
                  child: Text(
                    'No hay ticket #$_searchedNumber en este evento.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              final collaborators =
                  collabsAsync.valueOrNull ?? const <Collaborator>[];
              return _TicketTrackerResult(
                ticket: ticket,
                collaborators: collaborators,
              );
            },
          ),
      ],
    );
  }
}

class _TicketTrackerResult extends StatelessWidget {
  const _TicketTrackerResult({
    required this.ticket,
    required this.collaborators,
  });

  final Ticket ticket;
  final List<Collaborator> collaborators;

  Collaborator? _byId(String? id) {
    if (id == null) return null;
    for (final c in collaborators) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _actorLabel(TicketHistoryEntry entry) {
    final person = _byId(entry.actorId);
    final role = entry.actorRoleLabel;
    if (person != null) return '$role · ${person.name}';
    if (entry.actorId != null && entry.actorId!.isNotEmpty) {
      return '$role · ${entry.actorId}';
    }
    return role;
  }

  /// Replaces collaborator ids in free-text notes with their names.
  String _resolveNote(String? note) {
    if (note == null || note.trim().isEmpty) return '';
    var text = note;
    for (final c in collaborators) {
      if (c.id.isNotEmpty && text.contains(c.id)) {
        text = text.replaceAll(c.id, c.name);
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final seller = _byId(ticket.sellerId);
    final validator = _byId(ticket.validatorId);
    final collector = _byId(ticket.collectorId);
    final assignedBy = _byId(ticket.assignedByCollaboratorId);
    final history = [...ticket.history]
      ..sort((a, b) => b.at.compareTo(a.at));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Ticket #${ticket.number}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                label: ticket.status.label,
                tone: ticketStatusTone(ticket.status),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Vendedor actual',
                value: seller?.name ??
                    (ticket.sellerId == null ? '—' : ticket.sellerId!),
              ),
              _InfoRow(
                label: 'Asignado por',
                value: assignedBy?.name ??
                    (ticket.assignedByCollaboratorId == null
                        ? 'Organizador / sin dato'
                        : ticket.assignedByCollaboratorId!),
              ),
              _InfoRow(
                label: 'Comprador',
                value: ticket.buyerName.trim().isEmpty
                    ? '—'
                    : ticket.buyerName.trim(),
              ),
              _InfoRow(
                label: 'Recaudador',
                value: collector?.name ??
                    (ticket.collectorId == null ? '—' : ticket.collectorId!),
              ),
              _InfoRow(
                label: 'Validador',
                value: validator?.name ??
                    (ticket.validatorId == null ? '—' : ticket.validatorId!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Historial',
          child: history.isEmpty
              ? const Text(
                  'Todavía no hay movimientos registrados en este ticket. '
                  'Los nuevos cambios se van a ir guardando acá.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              : Column(
                  children: [
                    for (var i = 0; i < history.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      _HistoryTile(
                        entry: history[i],
                        actorLabel: _actorLabel(history[i]),
                        dateLabel: dateFormat.format(history[i].at),
                        noteLabel: _resolveNote(history[i].note),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.actorLabel,
    required this.dateLabel,
    required this.noteLabel,
  });

  final TicketHistoryEntry entry;
  final String actorLabel;
  final String dateLabel;
  final String noteLabel;

  @override
  Widget build(BuildContext context) {
    final statusLine = [
      if (entry.fromStatus != null) entry.fromStatus!.label,
      if (entry.toStatus != null) entry.toStatus!.label,
    ].join(' → ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.action.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                actorLabel,
                style: const TextStyle(fontSize: 13),
              ),
              if (statusLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  statusLine,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (noteLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  noteLabel,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
