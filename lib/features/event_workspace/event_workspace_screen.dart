import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/status_badge.dart';
import 'event_data_tab.dart';
import 'validators_tab.dart';
import 'collectors_tab.dart';
import 'coordinators_tab.dart';
import 'organizer_validate_screen.dart';
import 'summary_tab.dart';
import 'tickets_tab.dart';
import 'ticket_design_screen.dart';
import 'ticket_tracker_tab.dart';
import 'sellers_tab.dart';

enum EventTab {
  summary,
  tickets,
  validate,
  design,
  eventData,
  tracker,
  sellers,
  validators,
  coordinators,
  collectors,
}

/// Organizer workspace for one paid/active event.
class EventWorkspaceScreen extends ConsumerStatefulWidget {
  const EventWorkspaceScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventWorkspaceScreen> createState() =>
      _EventWorkspaceScreenState();
}

class _EventWorkspaceScreenState extends ConsumerState<EventWorkspaceScreen> {
  EventTab _selected = EventTab.summary;

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      value: ref.watch(eventProvider(widget.eventId)),
      builder: (context, event) => _buildWorkspace(context, event),
    );
  }

  Widget _buildWorkspace(BuildContext context, Event event) {
    final Widget body = switch (_selected) {
      EventTab.summary => SummaryTab(eventId: widget.eventId),
      EventTab.tickets => TicketsTab(eventId: widget.eventId),
      EventTab.validate => OrganizerValidateScreen(
          eventId: widget.eventId,
          embedded: true,
        ),
      EventTab.design => TicketDesignScreen(
          eventId: widget.eventId,
          embedded: true,
        ),
      EventTab.eventData => EventDataTab(eventId: widget.eventId),
      EventTab.tracker => TicketTrackerTab(eventId: widget.eventId),
      EventTab.sellers => SellersTab(eventId: widget.eventId),
      EventTab.validators => ValidatorsTab(eventId: widget.eventId),
      EventTab.coordinators => CoordinatorsTab(eventId: widget.eventId),
      EventTab.collectors => CollectorsTab(eventId: widget.eventId),
    };

    final (statusLabel, statusTone) = switch (event.status) {
      EventStatus.finished => ('Finalizado', BadgeTone.neutral),
      EventStatus.awaitingPayment => ('Pendiente de pago', BadgeTone.warn),
      EventStatus.active => ('Habilitado', BadgeTone.success),
    };

    return AppShell(
      title: _labelFor(_selected),
      onHome: () => context.go('/home'),
      header: _EventHeader(
        name: event.name,
        statusLabel: statusLabel,
        statusTone: statusTone,
      ),
      navItems: _navItems(),
      body: body,
    );
  }

  List<ShellNavItem> _navItems() {
    ShellNavItem item(EventTab tab) => ShellNavItem(
          icon: _iconFor(tab),
          label: _labelFor(tab),
          selected: tab == _selected,
          onTap: () => setState(() => _selected = tab),
        );

    return [
      item(EventTab.summary),
      item(EventTab.tickets),
      item(EventTab.validate),
      item(EventTab.design),
      item(EventTab.eventData),
      item(EventTab.tracker),
      const ShellNavItem.section('Colaboradores'),
      item(EventTab.sellers),
      item(EventTab.validators),
      item(EventTab.coordinators),
      item(EventTab.collectors),
    ];
  }

  IconData _iconFor(EventTab tab) {
    return switch (tab) {
      EventTab.summary => Icons.bar_chart_outlined,
      EventTab.tickets => Icons.confirmation_number_outlined,
      EventTab.validate => Icons.qr_code_scanner,
      EventTab.design => Icons.palette_outlined,
      EventTab.eventData => Icons.event_note_outlined,
      EventTab.tracker => Icons.timeline_outlined,
      EventTab.sellers => Icons.groups_outlined,
      EventTab.validators => Icons.how_to_reg_outlined,
      EventTab.coordinators => Icons.supervisor_account_outlined,
      EventTab.collectors => Icons.account_balance_wallet_outlined,
    };
  }

  String _labelFor(EventTab tab) {
    return switch (tab) {
      EventTab.summary => 'Resumen',
      EventTab.tickets => 'Tickets',
      EventTab.validate => 'Validar',
      EventTab.design => 'Diseño',
      EventTab.eventData => 'Datos del evento',
      EventTab.tracker => 'Rastreador',
      EventTab.sellers => 'Vendedores',
      EventTab.validators => 'Validadores',
      EventTab.coordinators => 'Coordinadores',
      EventTab.collectors => 'Recaudadores',
    };
  }
}

/// Full-width event name under the AppBar so long titles don't fight the actions.
class _EventHeader extends StatelessWidget {
  const _EventHeader({
    required this.name,
    required this.statusLabel,
    required this.statusTone,
  });

  final String name;
  final String statusLabel;
  final BadgeTone statusTone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            StatusBadge(label: statusLabel, tone: statusTone),
          ],
        ),
      ),
    );
  }
}
