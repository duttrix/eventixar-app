import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock/providers.dart';
import '../../shared/widgets/app_shell.dart';
import 'event_data_tab.dart';
import 'validators_tab.dart';
import 'settlements_tab.dart';
import 'reports_tab.dart';
import 'summary_tab.dart';
import 'tickets_tab.dart';
import 'sellers_tab.dart';

enum EventTab {
  summary,
  tickets,
  sellers,
  validators,
  settlements,
  reports,
  eventData,
}

/// Organizer workspace for one paid/active event.
class EventWorkspaceScreen extends ConsumerStatefulWidget {
  const EventWorkspaceScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventWorkspaceScreen> createState() => _EventWorkspaceScreenState();
}

class _EventWorkspaceScreenState extends ConsumerState<EventWorkspaceScreen> {
  EventTab _selected = EventTab.summary;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(widget.eventId);

    Widget body;
    switch (_selected) {
      case EventTab.summary:
        body = SummaryTab(eventId: widget.eventId);
      case EventTab.tickets:
        body = TicketsTab(eventId: widget.eventId);
      case EventTab.sellers:
        body = SellersTab(eventId: widget.eventId);
      case EventTab.validators:
        body = ValidatorsTab(eventId: widget.eventId);
      case EventTab.settlements:
        body = SettlementsTab(eventId: widget.eventId);
      case EventTab.reports:
        body = ReportsTab(eventId: widget.eventId);
      case EventTab.eventData:
        body = EventDataTab(eventId: widget.eventId);
    }

    return AppShell(
      title: event.name,
      subtitle: event.paid ? 'Evento habilitado' : 'Pendiente de pago',
      onHome: () => context.go('/home'),
      navItems: [
        for (final tab in EventTab.values)
          ShellNavItem(
            icon: _iconFor(tab),
            label: _labelFor(tab),
            selected: tab == _selected,
            onTap: () => setState(() => _selected = tab),
          ),
      ],
      body: body,
    );
  }

  IconData _iconFor(EventTab tab) {
    return switch (tab) {
      EventTab.summary => Icons.dashboard_outlined,
      EventTab.tickets => Icons.confirmation_number_outlined,
      EventTab.sellers => Icons.groups_outlined,
      EventTab.validators => Icons.qr_code_scanner_outlined,
      EventTab.settlements => Icons.fact_check_outlined,
      EventTab.reports => Icons.bar_chart_outlined,
      EventTab.eventData => Icons.event_note_outlined,
    };
  }

  String _labelFor(EventTab tab) {
    return switch (tab) {
      EventTab.summary => 'Resumen',
      EventTab.tickets => 'Tickets',
      EventTab.sellers => 'Vendedores',
      EventTab.validators => 'Validadores',
      EventTab.settlements => 'Rendiciones',
      EventTab.reports => 'Reportes',
      EventTab.eventData => 'Datos del evento',
    };
  }
}
