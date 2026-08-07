import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/section_card.dart';

/// Multi-step create-event flow: datos → equipo → cotización → pago.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  int _step = 0;
  bool _submitting = false;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '2000');
  final _profitController = TextEditingController(text: '500');
  final _countController = TextEditingController(text: '100');
  final _placeController = TextEditingController();
  final _notesController = TextEditingController();

  String _product = kEventProducts.first;
  DateTime? _eventDate;
  TimeOfDay _pickupFrom = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _pickupTo = const TimeOfDay(hour: 15, minute: 0);
  int _sellersCount = 2;
  int _validatorsCount = 1;
  int _collectorsCount = 0;
  int _coordinatorsCount = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _profitController.dispose();
    _countController.dispose();
    _placeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  EventQuote get _quote => EventQuote.calculate(
        ticketCount: int.tryParse(_countController.text) ?? 0,
      );

  bool get _step0Valid =>
      _nameController.text.trim().isNotEmpty &&
      _eventDate != null &&
      (int.tryParse(_countController.text) ?? 0) > 0;

  void _next() {
    if (_step == 0 && !_step0Valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá nombre, fecha y cantidad de tickets.'),
        ),
      );
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
  }

  Future<void> _submitAndPay() async {
    final session = ref.read(sessionProvider);
    final uid = session.userUid;
    if (uid == null || _eventDate == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      final event = await ref.read(eventRepositoryProvider).createEvent(
            ownerId: uid,
            ownerEmail: session.userEmail ?? '',
            name: _nameController.text.trim(),
            product: _product,
            ticketPrice: double.tryParse(_priceController.text) ?? 0,
            ticketProfit: double.tryParse(_profitController.text) ?? 0,
            ticketCount: int.tryParse(_countController.text) ?? 0,
            eventDate: _eventDate!,
            pickupFrom: _pickupFrom,
            pickupTo: _pickupTo,
            pickupPlace: _placeController.text.trim(),
            sellersCount: _sellersCount,
            validatorsCount: _validatorsCount,
            collectorsCount: _collectorsCount,
            coordinatorsCount: _coordinatorsCount,
            notes: _notesController.text.trim(),
          );

      if (!mounted) return;
      context.go('/create-event/pay/${event.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el evento: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : _back,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StepIndicator(step: _step),
          const SizedBox(height: 20),
          if (_step == 0) _buildDatos(),
          if (_step == 1) _buildEquipo(),
          if (_step == 2) _buildCotizacion(),
          const SizedBox(height: 24),
          if (_step < 2)
            ElevatedButton(
              onPressed: _next,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Continuar'),
              ),
            )
          else
            ElevatedButton(
              onPressed: _submitting ? null : _submitAndPay,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ir a pagar y habilitar'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String get _stepTitle => switch (_step) {
        0 => 'Nuevo evento · Datos',
        1 => 'Nuevo evento · Equipo',
        _ => 'Nuevo evento · Cotización',
      };

  Widget _buildDatos() {
    return SectionCard(
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
          DropdownButtonFormField<String>(
            initialValue: _product,
            decoration: const InputDecoration(labelText: 'Qué se vende'),
            items: kEventProducts
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (value) => setState(() => _product = value ?? _product),
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
                initialDate: _eventDate ?? now.add(const Duration(days: 14)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _eventDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Fecha del evento'),
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
                    if (picked != null) setState(() => _pickupFrom = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hora desde'),
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
                    if (picked != null) setState(() => _pickupTo = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hora hasta'),
                    child: Text(_pickupTo.format(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _placeController,
            decoration: const InputDecoration(labelText: 'Lugar de retiro'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipo() {
    return Column(
      children: [
        SectionCard(
          title: '¿Cuántos vendedores?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cupos sugeridos. Después vas a invitar a cada persona con un link (token).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _CountStepper(
                value: _sellersCount,
                onChanged: (v) => setState(() => _sellersCount = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '¿Cuántos validadores?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quienes validan el ticket en el retiro o en la entrada.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _CountStepper(
                value: _validatorsCount,
                onChanged: (v) => setState(() => _validatorsCount = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '¿Cuántos coordinadores?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opcional. Gestionan vendedores y les asignan tickets.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _CountStepper(
                value: _coordinatorsCount,
                onChanged: (v) => setState(() => _coordinatorsCount = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '¿Cuántos recaudadores?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opcional. Reciben las rendiciones de los vendedores.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _CountStepper(
                value: _collectorsCount,
                onChanged: (v) => setState(() => _collectorsCount = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCotizacion() {
    final quote = _quote;
    return SectionCard(
      title: quote.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            quote.priceLabel,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          for (final line in quote.breakdown) ...[
            Text(
              line,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          const Text(
            'Al confirmar el pago, el evento queda habilitado y se generan los tickets. '
            'Los colaboradores se invitan después, cada uno con su link.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Datos', 'Equipo', 'Cotización'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const Expanded(child: Divider()),
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= step ? AppColors.accent : AppColors.border,
                foregroundColor: i <= step ? Colors.white : AppColors.textMuted,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                  color: i <= step ? AppColors.text : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
