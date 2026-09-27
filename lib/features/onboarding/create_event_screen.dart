import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/event_products_editor.dart';
import '../../shared/widgets/section_card.dart';

/// Create-event form. A free slot opens the workspace; otherwise checkout.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  bool _submitting = false;
  bool _attempted = false;
  int _step = 0;
  final _productsKey = GlobalKey<EventProductsEditorState>();

  final _nameController = TextEditingController();
  final _placeController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _eventDate;
  TimeOfDay _pickupFrom = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _pickupTo = const TimeOfDay(hour: 15, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _formValid =>
      _nameController.text.trim().isNotEmpty && _eventDate != null;

  String? get _nameError =>
      _attempted && _nameController.text.trim().isEmpty ? 'Obligatorio' : null;

  String? get _dateError =>
      _attempted && _eventDate == null ? 'Obligatorio' : null;

  void _goBack() {
    if (_submitting) return;
    if (_step > 0) {
      setState(() => _step = 0);
      return;
    }
    context.pop();
  }

  void _next() {
    if (!_formValid) {
      setState(() => _attempted = true);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    final uid = session.userUid;
    if (uid == null || _submitting) return;

    final productsError = _productsKey.currentState?.validate();
    if (productsError != null) {
      setState(() => _attempted = true);
      AppSnackBar.warning(context, productsError);
      return;
    }
    final products = _productsKey.currentState?.products() ?? const [];

    _submitting = true;
    setState(() {});
    try {
      final repo = ref.read(eventRepositoryProvider);
      final created = await repo.createEvent(
        ownerId: uid,
        ownerEmail: session.userEmail ?? '',
        name: _nameController.text.trim(),
        products: products,
        eventDate: _eventDate!,
        pickupFrom: _pickupFrom,
        pickupTo: _pickupTo,
        pickupPlace: _placeController.text.trim(),
        sellersCount: 2,
        validatorsCount: 1,
        notes: _notesController.text.trim(),
      );

      try {
        await ref.read(productCatalogRepositoryProvider).upsertAll(uid, products);
      } catch (e) {
        debugPrint('No se pudo guardar el catálogo de productos: $e');
      }

      if (!mounted) return;
      AppSnackBar.success(
        context,
        created.usedFreeSlot
            ? 'Evento creado. Se generaron ${created.event.ticketCount} tickets.'
            : 'Evento creado. Se generaron ${created.event.ticketCount} tickets. Completá el pago para activarlo.',
      );
      if (created.usedFreeSlot) {
        context.go('/event/${created.event.id}');
      } else {
        context.go('/create-event/pay/${created.event.id}');
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No se pudo crear el evento: $e', cause: e);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No se pudo crear el evento: $e', cause: e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizer = ref.watch(currentOrganizerProvider).asData?.value;
    final catalog =
        ref.watch(organizerProductCatalogProvider).asData?.value ?? const [];

    final createLabel = organizer != null && organizer.canCreateFreeEvent
        ? 'Crear evento (${organizer.freeEvents} gratis)'
        : 'Crear evento';

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Datos del evento' : 'Qué se vende'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : _goBack,
        ),
      ),
      body: IndexedStack(
        index: _step,
        sizing: StackFit.expand,
        children: [
          _EventDataStep(
            nameController: _nameController,
            placeController: _placeController,
            notesController: _notesController,
            eventDate: _eventDate,
            pickupFrom: _pickupFrom,
            pickupTo: _pickupTo,
            nameError: _nameError,
            dateError: _dateError,
            onChanged: () => setState(() {}),
            onDate: (date) => setState(() => _eventDate = date),
            onFrom: (time) => setState(() => _pickupFrom = time),
            onTo: (time) => setState(() => _pickupTo = time),
            onNext: _next,
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Paso 2 de 2',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Qué se vende',
                child: EventProductsEditor(
                  key: _productsKey,
                  initialProducts: const [],
                  catalog: catalog,
                  enabled: !_submitting,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(createLabel),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventDataStep extends StatelessWidget {
  const _EventDataStep({
    required this.nameController,
    required this.placeController,
    required this.notesController,
    required this.eventDate,
    required this.pickupFrom,
    required this.pickupTo,
    required this.nameError,
    required this.dateError,
    required this.onChanged,
    required this.onDate,
    required this.onFrom,
    required this.onTo,
    required this.onNext,
  });

  final TextEditingController nameController;
  final TextEditingController placeController;
  final TextEditingController notesController;
  final DateTime? eventDate;
  final TimeOfDay pickupFrom;
  final TimeOfDay pickupTo;
  final String? nameError;
  final String? dateError;
  final VoidCallback onChanged;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<TimeOfDay> onFrom;
  final ValueChanged<TimeOfDay> onTo;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Paso 1 de 2',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Datos del evento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del evento *',
                  hintText: 'Ej. Pollo a beneficio',
                  errorText: nameError,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: eventDate ?? now.add(const Duration(days: 14)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (!context.mounted) return;
                  if (picked != null) onDate(picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha del evento *',
                    errorText: dateError,
                  ),
                  child: Text(
                    eventDate == null
                        ? 'Seleccionar fecha'
                        : '${eventDate!.day}/${eventDate!.month}/${eventDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: pickupFrom,
                        );
                        if (!context.mounted) return;
                        if (picked != null) onFrom(picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Hora desde'),
                        child: Text(pickupFrom.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: pickupTo,
                        );
                        if (!context.mounted) return;
                        if (picked != null) onTo(picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Hora hasta'),
                        child: Text(pickupTo.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: placeController,
                decoration: const InputDecoration(labelText: 'Lugar de retiro'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onNext,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Siguiente'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
