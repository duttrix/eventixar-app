import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/event_products_editor.dart';
import '../../shared/widgets/section_card.dart';

/// Edit basic event data (organizer only).
class EventDataTab extends ConsumerStatefulWidget {
  const EventDataTab({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDataTab> createState() => _EventDataTabState();
}

class _EventDataTabState extends ConsumerState<EventDataTab> {
  final _productsKey = GlobalKey<EventProductsEditorState>();
  late final TextEditingController _nameController;
  late final TextEditingController _placeController;
  late final TextEditingController _notesController;

  DateTime? _eventDate;
  TimeOfDay? _pickupFrom;
  TimeOfDay? _pickupTo;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final productsError = _productsKey.currentState?.validate();
    if (productsError != null) {
      AppSnackBar.warning(context, productsError);
      return;
    }
    final products = _productsKey.currentState?.products() ?? const [];
    final eventDate = _eventDate ?? DateTime.now();
    final pickupFrom = _pickupFrom ?? const TimeOfDay(hour: 12, minute: 0);
    final pickupTo = _pickupTo ?? const TimeOfDay(hour: 15, minute: 0);
    final pickupPlace = _placeController.text.trim();
    final notes = _notesController.text.trim();

    try {
      await ref
          .read(eventRepositoryProvider)
          .updateEvent(
            widget.eventId,
            name: name,
            products: products,
            eventDate: eventDate,
            pickupFrom: pickupFrom,
            pickupTo: pickupTo,
            pickupPlace: pickupPlace,
            notes: notes,
          );
      if (!mounted) return;
      final uid = ref.read(sessionProvider).userUid;
      if (uid != null) {
        try {
          await ref
              .read(productCatalogRepositoryProvider)
              .upsertAll(uid, products);
        } catch (e) {
          debugPrint('No se pudo guardar el catálogo de productos: $e');
        }
      }
      if (!mounted) return;
      AppSnackBar.success(context, 'Cambios guardados.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No se pudo guardar: $e', cause: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    if (eventAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eventAsync.hasError || !eventAsync.hasValue) {
      return Center(
        child: Text('${eventAsync.error ?? 'Evento no encontrado'}'),
      );
    }
    final event = eventAsync.requireValue;
    final finished = event.isReadOnly;
    if (!_initialized) {
      _nameController = TextEditingController(text: event.name);
      _placeController = TextEditingController(text: event.pickupPlace);
      _notesController = TextEditingController(text: event.notes);
      _eventDate = event.eventDate;
      _pickupFrom = event.pickupFrom;
      _pickupTo = event.pickupTo;
      _initialized = true;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Datos del evento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                enabled: !finished,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              EventProductsEditor(
                key: _productsKey,
                initialProducts: event.products,
                lockTicketCounts: true,
                enabled: !finished,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: finished
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _eventDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) setState(() => _eventDate = picked);
                      },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha'),
                  child: Text(
                    _eventDate == null
                        ? '—'
                        : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: finished
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    _pickupFrom ??
                                    const TimeOfDay(hour: 12, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => _pickupFrom = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora desde',
                        ),
                        child: Text(
                          (_pickupFrom ?? const TimeOfDay(hour: 12, minute: 0))
                              .format(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: finished
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    _pickupTo ??
                                    const TimeOfDay(hour: 15, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => _pickupTo = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora hasta',
                        ),
                        child: Text(
                          (_pickupTo ?? const TimeOfDay(hour: 15, minute: 0))
                              .format(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _placeController,
                enabled: !finished,
                decoration: const InputDecoration(labelText: 'Lugar de retiro'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                enabled: !finished,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              const SizedBox(height: 8),
              Text(
                'Tickets: ${event.ticketCount} · Vendedores: ${event.sellersCount} · Coordinadores: ${event.coordinatorsCount} · Validadores: ${event.validatorsCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: finished ? null : _save,
          child: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
