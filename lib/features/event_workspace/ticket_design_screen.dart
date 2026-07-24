import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ticket.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/ticket_share.dart';

/// Demo screen: customize ticket look (templates, colors, background, type).
/// Changes are local to this screen and are not persisted.
class TicketDesignScreen extends ConsumerStatefulWidget {
  const TicketDesignScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketDesignScreen> createState() => _TicketDesignScreenState();
}

class _TicketDesignScreenState extends ConsumerState<TicketDesignScreen> {
  TicketVisualStyle _style = TicketVisualStyle.classic;
  String _templateId = 'classic';

  static const _primarySwatches = <Color>[
    Color(0xFF1B3A5F),
    Color(0xFF7A1F2B),
    Color(0xFF111827),
    Color(0xFF14532D),
    Color(0xFF5B21B6),
    Color(0xFF9A3412),
  ];

  static const _accentSwatches = <Color>[
    Color(0xFF378ADD),
    Color(0xFFE8A838),
    Color(0xFF6B7280),
    Color(0xFF86EFAC),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
  ];

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(repositoryProvider).eventById(widget.eventId);
    final previewTicket = Ticket(
      id: 'preview_${widget.eventId}',
      eventId: widget.eventId,
      number: 1,
      status: TicketStatus.collected,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diseño del ticket'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diseño guardado.')),
              );
              Navigator.of(context).maybePop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TicketSharePreview(ticket: previewTicket, event: event, style: _style),
          const SizedBox(height: 24),
          Text('Personalizar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Demo: probá plantillas y colores. Guardar es simulado.',
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
              _templateChip('institutional', 'Institucional', TicketVisualStyle.institutional),
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
              ChoiceChip(
                label: const Text('Sólido'),
                selected: _style.backgroundMode == TicketBackgroundMode.solid,
                onSelected: (_) => setState(() {
                  _templateId = 'custom';
                  _style = _style.copyWith(backgroundMode: TicketBackgroundMode.solid);
                }),
              ),
              ChoiceChip(
                label: const Text('Gradiente'),
                selected: _style.backgroundMode == TicketBackgroundMode.gradient,
                onSelected: (_) => setState(() {
                  _templateId = 'custom';
                  _style = _style.copyWith(backgroundMode: TicketBackgroundMode.gradient);
                }),
              ),
              ChoiceChip(
                label: const Text('Imagen'),
                selected: _style.backgroundMode == TicketBackgroundMode.image,
                onSelected: (_) {
                  setState(() {
                    _templateId = 'custom';
                    _style = _style.copyWith(backgroundMode: TicketBackgroundMode.image);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Imagen de fondo: próximamente vas a poder subir la tuya.'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Tipografía'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sistema'),
                selected: _style.typography == TicketTypographyStyle.system,
                onSelected: (_) => setState(() {
                  _templateId = 'custom';
                  _style = _style.copyWith(typography: TicketTypographyStyle.system);
                }),
              ),
              ChoiceChip(
                label: const Text('Destacada'),
                selected: _style.typography == TicketTypographyStyle.featured,
                onSelected: (_) => setState(() {
                  _templateId = 'custom';
                  _style = _style.copyWith(typography: TicketTypographyStyle.featured);
                }),
              ),
              ChoiceChip(
                label: const Text('Compacta'),
                selected: _style.typography == TicketTypographyStyle.compact,
                onSelected: (_) => setState(() {
                  _templateId = 'custom';
                  _style = _style.copyWith(typography: TicketTypographyStyle.compact);
                }),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'En la versión final acá vas a subir logo, fondo y guardar el diseño para todos los tickets del evento.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: AppColors.textSecondary,
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
    return Row(
      children: [
        for (final color in colors) ...[
          GestureDetector(
            onTap: () => onPick(color),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected.toARGB32() == color.toARGB32()
                      ? AppColors.accent
                      : AppColors.border,
                  width: selected.toARGB32() == color.toARGB32() ? 3 : 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
