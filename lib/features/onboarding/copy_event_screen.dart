import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_card.dart';

/// Duplicate a finished event: new date + ticket count, optional team copy.
class CopyEventScreen extends ConsumerStatefulWidget {
  const CopyEventScreen({super.key, required this.sourceEventId});

  final String sourceEventId;

  @override
  ConsumerState<CopyEventScreen> createState() => _CopyEventScreenState();
}

class _CopyEventScreenState extends ConsumerState<CopyEventScreen> {
  bool _submitting = false;
  bool _eventInited = false;
  bool _rolesInited = false;

  final _nameController = TextEditingController();
  final _countController = TextEditingController();
  DateTime? _eventDate;
  final _copyRoles = <CollaboratorRole>{};

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _initEvent(Event event) {
    if (_eventInited) return;
    _eventInited = true;
    _nameController.text = event.name;
    _countController.text = '${event.ticketCount}';
    _eventDate = DateTime.now().add(const Duration(days: 14));
  }

  void _initRoles(List<Collaborator> team, {required bool teamLoading}) {
    if (_rolesInited || teamLoading) return;
    _rolesInited = true;
    for (final role in CollaboratorRole.values) {
      if (team.any((c) => c.role == role)) {
        _copyRoles.add(role);
      }
    }
  }

  Future<void> _submit(Event source, List<Collaborator> team) async {
    final session = ref.read(sessionProvider);
    final uid = session.userUid;
    if (uid == null || _eventDate == null || _submitting) return;

    final name = _nameController.text.trim();
    final ticketCount = int.tryParse(_countController.text) ?? 0;
    if (name.isEmpty || ticketCount <= 0) {
      AppSnackBar.warning(
        context,
        'Completá el nombre, la fecha y la cantidad de tickets.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final eventRepo = ref.read(eventRepositoryProvider);
      final created = await eventRepo.createEvent(
        ownerId: uid,
        ownerEmail: session.userEmail ?? '',
        name: name,
        product: source.product,
        ticketPrice: source.ticketPrice,
        ticketProfit: source.ticketProfit,
        ticketCount: ticketCount,
        eventDate: _eventDate!,
        pickupFrom: source.pickupFrom,
        pickupTo: source.pickupTo,
        pickupPlace: source.pickupPlace,
        sellersCount: source.sellersCount,
        validatorsCount: source.validatorsCount,
        collectorsCount: source.collectorsCount,
        coordinatorsCount: source.coordinatorsCount,
        notes: source.notes,
        ticketDesign: source.ticketDesign,
      );

      final rolesToCopy = {
        for (final role in _copyRoles)
          if (team.any((c) => c.role == role)) role,
      };
      if (rolesToCopy.isNotEmpty) {
        await ref.read(collaboratorRepositoryProvider).copyRolesToEvent(
              fromEventId: source.id,
              toEventId: created.event.id,
              roles: rolesToCopy,
            );
      }

      if (!mounted) return;

      if (created.usedFreeSlot) {
        await eventRepo.confirmPaymentAndGenerateTickets(created.event.id);
        if (!mounted) return;
        AppSnackBar.success(
          context,
          'Evento duplicado. Se generaron $ticketCount tickets.',
        );
        context.go('/event/${created.event.id}');
        return;
      }

      AppSnackBar.info(
        context,
        'Evento duplicado. Quedó pendiente de pago.',
      );
      context.go('/home');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No se pudo duplicar: $e', cause: e);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No se pudo duplicar: $e', cause: e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.sourceEventId));
    final teamAsync = ref.watch(eventCollaboratorsProvider(widget.sourceEventId));

    return eventAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Duplicar evento')),
        body: Center(child: Text('No se pudo cargar: $e')),
      ),
      data: (event) {
        final team = teamAsync.asData?.value ?? const <Collaborator>[];
        _initEvent(event);
        _initRoles(team, teamLoading: teamAsync.isLoading);
        return _buildForm(event, team, teamAsync.isLoading);
      },
    );
  }

  Widget _buildForm(
    Event event,
    List<Collaborator> team,
    bool teamLoading,
  ) {
    int countFor(CollaboratorRole role) =>
        team.where((c) => c.role == role).length;

    String roleLabel(CollaboratorRole role, int count) => switch (role) {
      CollaboratorRole.seller => 'Vendedores ($count)',
      CollaboratorRole.validator => 'Validadores ($count)',
      CollaboratorRole.collector => 'Recaudadores ($count)',
      CollaboratorRole.coordinator => 'Coordinadores ($count)',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicar evento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Se copian datos, diseño y precios. Los tickets y los links '
            'de acceso se generan de nuevo.',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Nuevo evento',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del evento',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? now.add(const Duration(days: 14)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha del evento',
                    ),
                    child: Text(
                      _eventDate == null
                          ? 'Seleccionar fecha'
                          : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de tickets',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Copiar colaboradores',
            child: teamLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      for (final role in CollaboratorRole.values)
                        if (countFor(role) > 0)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _copyRoles.contains(role),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _copyRoles.add(role);
                                } else {
                                  _copyRoles.remove(role);
                                }
                              });
                            },
                            title: Text(roleLabel(role, countFor(role))),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      if (team.isEmpty)
                        const Text(
                          'Este evento no tiene colaboradores para copiar.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : () => _submit(event, team),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Duplicar evento'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
