import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock/providers.dart';
import '../../shared/widgets/app_shell.dart';
import 'cupones_tab.dart';
import 'datos_evento_tab.dart';
import 'entregadores_tab.dart';
import 'rendiciones_tab.dart';
import 'reportes_tab.dart';
import 'resumen_tab.dart';
import 'vendedores_tab.dart';

enum EventTab {
  resumen,
  cupones,
  vendedores,
  entregadores,
  rendiciones,
  reportes,
  datosEvento,
}

/// Organizer workspace for one paid/active event.
class EventWorkspaceScreen extends ConsumerStatefulWidget {
  const EventWorkspaceScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventWorkspaceScreen> createState() => _EventWorkspaceScreenState();
}

class _EventWorkspaceScreenState extends ConsumerState<EventWorkspaceScreen> {
  EventTab _selected = EventTab.resumen;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(widget.eventId);

    Widget body;
    switch (_selected) {
      case EventTab.resumen:
        body = ResumenTab(eventId: widget.eventId);
      case EventTab.cupones:
        body = CuponesTab(eventId: widget.eventId);
      case EventTab.vendedores:
        body = VendedoresTab(eventId: widget.eventId);
      case EventTab.entregadores:
        body = EntregadoresTab(eventId: widget.eventId);
      case EventTab.rendiciones:
        body = RendicionesTab(eventId: widget.eventId);
      case EventTab.reportes:
        body = ReportesTab(eventId: widget.eventId);
      case EventTab.datosEvento:
        body = DatosEventoTab(eventId: widget.eventId);
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
      EventTab.resumen => Icons.dashboard_outlined,
      EventTab.cupones => Icons.confirmation_number_outlined,
      EventTab.vendedores => Icons.groups_outlined,
      EventTab.entregadores => Icons.volunteer_activism_outlined,
      EventTab.rendiciones => Icons.fact_check_outlined,
      EventTab.reportes => Icons.bar_chart_outlined,
      EventTab.datosEvento => Icons.event_note_outlined,
    };
  }

  String _labelFor(EventTab tab) {
    return switch (tab) {
      EventTab.resumen => 'Resumen',
      EventTab.cupones => 'Cupones',
      EventTab.vendedores => 'Vendedores',
      EventTab.entregadores => 'Entregadores',
      EventTab.rendiciones => 'Rendiciones',
      EventTab.reportes => 'Reportes',
      EventTab.datosEvento => 'Datos del evento',
    };
  }
}
