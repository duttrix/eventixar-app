import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/event.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/event_products_editor.dart';
import '../../shared/widgets/section_card.dart';

/// Create-event form. The event is created already active.
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
      setState(() => _step -= 1);
      return;
    }
    context.pop();
  }

  void _selectStep(int next) {
    if (_submitting || next == _step) return;
    if (next < _step) {
      setState(() => _step = next);
      return;
    }
    if (next == _step + 1) {
      if (_step == 0) _next();
      if (_step == 1) _nextFromProducts();
    }
  }

  void _next() {
    if (!_formValid) {
      setState(() => _attempted = true);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = 1);
  }

  void _nextFromProducts() {
    final productsError = _productsKey.currentState?.validate();
    if (productsError != null) {
      setState(() => _attempted = true);
      AppSnackBar.warning(context, productsError);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = 2);
  }

  int get _ticketCount {
    final products = _productsKey.currentState?.products() ?? const [];
    return products.fold<int>(0, (total, product) => total + product.ticketCount);
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
        'Evento creado. Se generaron ${created.event.ticketCount} tickets.',
      );
      context.go('/event/${created.event.id}');
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
    final catalog =
        ref.watch(organizerProductCatalogProvider).asData?.value ?? const [];
    final pricing = ref.watch(eventPricingProvider).asData?.value;
    final quote = pricing == null
        ? null
        : EventQuote.calculate(ticketCount: _ticketCount, pricing: pricing);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear evento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : _goBack,
        ),
      ),
      body: Column(
        children: [
          _CreateStepBar(step: _step, onStep: _selectStep),
          Expanded(
            child: IndexedStack(
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
                onPressed: _nextFromProducts,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Siguiente'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          _PaymentStep(
            quote: quote,
            ticketCount: _ticketCount,
            submitting: _submitting,
            onCreate: _submit,
          ),
        ],
            ),
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

class _CreateStepBar extends StatelessWidget {
  const _CreateStepBar({required this.step, required this.onStep});

  final int step;
  final ValueChanged<int> onStep;

  static const _labels = ['Datos', 'Qué se vende', 'Pago'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Positioned(
                  left: width / 6,
                  width: width / 3,
                  top: 10,
                  child: _StepLine(active: step >= 1),
                ),
                Positioned(
                  left: width / 2,
                  width: width / 3,
                  top: 10,
                  child: _StepLine(active: step >= 2),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _labels.length; i++)
                      Expanded(
                        child: _StepNode(
                          number: i + 1,
                          label: _labels[i],
                          done: step > i,
                          current: step == i,
                          onTap: () => onStep(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(height: 2),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final int number;
  final String label;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = current || done;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.accent : AppColors.surface2,
              border: active ? null : Border.all(color: AppColors.borderStrong),
            ),
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: current ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: current
                  ? AppColors.text
                  : done
                  ? AppColors.accentText
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    required this.quote,
    required this.ticketCount,
    required this.submitting,
    required this.onCreate,
  });

  final EventQuote? quote;
  final int ticketCount;
  final bool submitting;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final showPrice = quote != null && quote!.amount > 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Pago',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$ticketCount tickets',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (showPrice) ...[
                Text(
                  quote!.priceLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
                if (quote!.breakdown.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    quote!.breakdown.first,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
              Text(
                'Gratis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hoy lo creás sin costo. Estamos preparando la gestión de pago, para que puedas abonarlo directamente desde la app.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: submitting ? null : onCreate,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear Evento'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
