import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../data/models/ticket.dart';
import '../../shared/widgets/ticket_share.dart';

/// Customize ticket look for an event. Saved on the event document.
class TicketDesignScreen extends ConsumerStatefulWidget {
  const TicketDesignScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketDesignScreen> createState() => _TicketDesignScreenState();
}

class _TicketDesignScreenState extends ConsumerState<TicketDesignScreen> {
  TicketVisualStyle _style = TicketVisualStyle.classic;
  String _templateId = 'custom';
  bool _hydrated = false;
  bool _saving = false;

  static const _primarySwatches = <Color>[
    Color(0xFF0C1F1C),
    Color(0xFF0E9F8E),
    Color(0xFF1B3A5F),
    Color(0xFF7A1F2B),
    Color(0xFF111827),
    Color(0xFF14532D),
  ];

  static const _accentSwatches = <Color>[
    Color(0xFF0E9F8E),
    Color(0xFFE8A838),
    Color(0xFF6B7280),
    Color(0xFF86EFAC),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
  ];

  void _hydrateFrom(TicketVisualStyle design) {
    if (_hydrated) return;
    _style = design;
    _templateId = _matchTemplate(design);
    _hydrated = true;
  }

  String _matchTemplate(TicketVisualStyle style) {
    if (_same(style, TicketVisualStyle.classic)) return 'classic';
    if (_same(style, TicketVisualStyle.festive)) return 'festive';
    if (_same(style, TicketVisualStyle.dark)) return 'dark';
    if (_same(style, TicketVisualStyle.institutional)) return 'institutional';
    return 'custom';
  }

  bool _same(TicketVisualStyle a, TicketVisualStyle b) {
    return a.primary.toARGB32() == b.primary.toARGB32() &&
        a.accent.toARGB32() == b.accent.toARGB32() &&
        a.backgroundMode == b.backgroundMode &&
        a.typography == b.typography;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(eventRepositoryProvider)
          .updateTicketDesign(widget.eventId, _style);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diseño guardado en el evento.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    final event = eventAsync.valueOrNull;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diseño del ticket')),
        body: Center(
          child: eventAsync.hasError
              ? Text('${eventAsync.error}')
              : const CircularProgressIndicator(),
        ),
      );
    }
    _hydrateFrom(event.ticketDesign);

    final previewTicket = Ticket(
      id: 'preview_${widget.eventId}',
      eventId: widget.eventId,
      number: 1,
      status: TicketStatus.collected,
      buyerName: 'Ejemplo',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diseño del ticket'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TicketSharePreview(
            ticket: previewTicket,
            event: event,
            style: _style,
          ),
          const SizedBox(height: 24),
          Text('Personalizar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Este diseño se aplica a las imágenes que comparte el vendedor.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Plantilla'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _templateChip('classic', 'Clásico', TicketVisualStyle.classic),
              _templateChip('festive', 'Festivo', TicketVisualStyle.festive),
              _templateChip('dark', 'Oscuro', TicketVisualStyle.dark),
              _templateChip(
                'institutional',
                'Institucional',
                TicketVisualStyle.institutional,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Color principal'),
          const SizedBox(height: 8),
          _swatchRow(
            colors: _primarySwatches,
            selected: _style.primary,
            onPick: (c) => setState(() {
              _templateId = 'custom';
              _style = _style.copyWith(primary: c);
            }),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Color acento'),
          const SizedBox(height: 8),
          _swatchRow(
            colors: _accentSwatches,
            selected: _style.accent,
            onPick: (c) => setState(() {
              _templateId = 'custom';
              _style = _style.copyWith(accent: c);
            }),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Fondo'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in TicketBackgroundMode.values)
                ChoiceChip(
                  label: Text(switch (mode) {
                    TicketBackgroundMode.solid => 'Sólido',
                    TicketBackgroundMode.gradient => 'Degradé',
                    TicketBackgroundMode.image => 'Imagen (demo)',
                  }),
                  selected: _style.backgroundMode == mode,
                  onSelected: (_) => setState(() {
                    _templateId = 'custom';
                    _style = _style.copyWith(backgroundMode: mode);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Tipografía'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in TicketTypographyStyle.values)
                ChoiceChip(
                  label: Text(switch (t) {
                    TicketTypographyStyle.system => 'Sistema',
                    TicketTypographyStyle.featured => 'Destacada',
                    TicketTypographyStyle.compact => 'Compacta',
                  }),
                  selected: _style.typography == t,
                  onSelected: (_) => setState(() {
                    _templateId = 'custom';
                    _style = _style.copyWith(typography: t);
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _templateChip(String id, String label, TicketVisualStyle style) {
    return ChoiceChip(
      label: Text(label),
      selected: _templateId == id,
      onSelected: (_) => setState(() {
        _templateId = id;
        _style = style;
      }),
    );
  }

  Widget _swatchRow({
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onPick,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          GestureDetector(
            onTap: () => onPick(color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected.toARGB32() == color.toARGB32()
                      ? AppColors.accent
                      : Colors.white,
                  width: selected.toARGB32() == color.toARGB32() ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
