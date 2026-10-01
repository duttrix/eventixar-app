import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/event_product.dart';
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
  final _productCounts = <String, TextEditingController>{};
  final _variantCounts = <String, TextEditingController>{};
  DateTime? _eventDate;
  final _copyRoles = <CollaboratorRole>{};

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    for (final controller in _productCounts.values) {
      controller.dispose();
    }
    for (final controller in _variantCounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initEvent(Event event) {
    if (_eventInited) return;
    _eventInited = true;
    _nameController.text = event.name;
    _countController.text = '${event.products.first.ticketCount}';
    for (final product in event.products) {
      _productCounts[product.id] = TextEditingController(
        text: '${product.ticketCount}',
      );
      for (final variant in product.variants) {
        _variantCounts['${product.id}::${variant.id}'] = TextEditingController(
          text: variant.quota > 0 ? '${variant.quota}' : '',
        );
      }
    }
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
    if (name.isEmpty || _eventDate == null) {
      AppSnackBar.warning(context, 'Completá el nombre y la fecha.');
      return;
    }

    final clones = <EventProduct>[];
    var ticketTotal = 0;
    for (final product in source.products) {
      if (product.variants.isEmpty) {
        final raw = source.products.length == 1
            ? _countController.text
            : _productCounts[product.id]?.text ?? '';
        final count = int.tryParse(raw.trim()) ?? 0;
        if (count <= 0) {
          AppSnackBar.warning(
            context,
            'Ingresá la cantidad de tickets de ${product.name}.',
          );
          return;
        }
        clones.add(product.cloneForNewEvent().copyWith(ticketCount: count));
        ticketTotal += count;
        continue;
      }
      final clone = product.cloneForNewEvent();
      final variants = <EventProductVariant>[];
      var sum = 0;
      for (var i = 0; i < product.variants.length; i++) {
        final sourceVariant = product.variants[i];
        final raw =
            _variantCounts['${product.id}::${sourceVariant.id}']?.text ?? '';
        final qty = int.tryParse(raw.trim()) ?? 0;
        if (qty <= 0) {
          AppSnackBar.warning(
            context,
            'Ingresá la cantidad de ${sourceVariant.name} en ${product.name}.',
          );
          return;
        }
        variants.add(clone.variants[i].copyWith(quota: qty));
        sum += qty;
      }
      clones.add(clone.copyWith(variants: variants, ticketCount: sum));
      ticketTotal += sum;
    }

    setState(() => _submitting = true);
    try {
      final eventRepo = ref.read(eventRepositoryProvider);
      final created = await eventRepo.createEvent(
        ownerId: uid,
        ownerEmail: session.userEmail ?? '',
        name: name,
        products: clones,
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
      AppSnackBar.success(
        context,
        'Evento duplicado. Se generaron $ticketTotal tickets.',
      );
      context.go('/event/${created.event.id}');
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
                    FocusManager.instance.primaryFocus?.unfocus();
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? now.add(const Duration(days: 14)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (!context.mounted) return;
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
                for (var i = 0; i < event.products.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  if (event.products[i].variants.isEmpty)
                    TextField(
                      controller: event.products.length == 1
                          ? _countController
                          : _productCounts[event.products[i].id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Cantidad de tickets de ${event.products[i].name}',
                      ),
                    )
                  else
                    for (final variant in event.products[i].variants) ...[
                      TextField(
                        controller: _variantCounts[
                            '${event.products[i].id}::${variant.id}'],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              '${event.products[i].name} · ${variant.name}',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
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
                  : Text(
                      'Duplicar evento',
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
