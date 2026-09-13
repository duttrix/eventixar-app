import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/product_typeahead_field.dart';
import '../../shared/widgets/section_card.dart';

/// Create-event form. With a free slot the event is enabled immediately;
/// otherwise it stays in "Por pagar" until checkout.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  bool _submitting = false;

  final _nameController = TextEditingController();
  final _productController = TextEditingController();
  final _priceController = TextEditingController(text: '2000');
  final _profitController = TextEditingController(text: '500');
  final _countController = TextEditingController(text: '100');
  final _placeController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _eventDate;
  TimeOfDay _pickupFrom = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _pickupTo = const TimeOfDay(hour: 15, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _productController.dispose();
    _priceController.dispose();
    _profitController.dispose();
    _countController.dispose();
    _placeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _formValid =>
      _nameController.text.trim().isNotEmpty &&
      _productController.text.trim().isNotEmpty &&
      _eventDate != null &&
      (int.tryParse(_countController.text) ?? 0) > 0;

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    final uid = session.userUid;
    if (uid == null || _eventDate == null || _submitting) return;

    if (!_formValid) {
      AppSnackBar.warning(
        context,
        'Completá nombre, qué se vende, fecha y cantidad de tickets.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(eventRepositoryProvider);
      final created = await repo.createEvent(
        ownerId: uid,
        ownerEmail: session.userEmail ?? '',
        name: _nameController.text.trim(),
        product: _productController.text.trim(),
        ticketPrice: double.tryParse(_priceController.text) ?? 0,
        ticketProfit: double.tryParse(_profitController.text) ?? 0,
        ticketCount: int.tryParse(_countController.text) ?? 0,
        eventDate: _eventDate!,
        pickupFrom: _pickupFrom,
        pickupTo: _pickupTo,
        pickupPlace: _placeController.text.trim(),
        sellersCount: 2,
        validatorsCount: 1,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (created.usedFreeSlot) {
        if (!mounted) return;
        AppSnackBar.success(
          context,
          'Evento creado. Se generaron ${created.event.ticketCount} tickets.',
        );
        context.go('/event/${created.event.id}');
        return;
      }

      AppSnackBar.info(
        context,
        'Evento creado. Quedó pendiente de pago. Lo encontrás en Por pagar.',
      );
      context.go('/home');
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
    final products =
        ref.watch(eventProductsProvider).asData?.value ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo evento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Datos del evento',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del evento',
                    hintText: 'Ej. Pollo a beneficio',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                ProductTypeaheadField(
                  controller: _productController,
                  suggestions: products,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio del ticket',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _profitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ganancia',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de tickets',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _eventDate ?? now.add(const Duration(days: 14)),
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
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _pickupFrom,
                          );
                          if (picked != null) {
                            setState(() => _pickupFrom = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hora desde',
                          ),
                          child: Text(_pickupFrom.format(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _pickupTo,
                          );
                          if (picked != null) {
                            setState(() => _pickupTo = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hora hasta',
                          ),
                          child: Text(_pickupTo.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'Lugar de retiro',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
              ],
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
                  : Text(
                      organizer != null && organizer.canCreateFreeEvent
                          ? 'Crear evento (${organizer.freeEvents} gratis)'
                          : 'Crear evento',
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
