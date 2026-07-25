import 'package:flutter/material.dart';

enum TicketBackgroundMode { solid, gradient, image }

enum TicketTypographyStyle { system, featured, compact }

/// Visual knobs for the ticket card.
class TicketVisualStyle {
  const TicketVisualStyle({
    this.primary = const Color(0xFF1B3A5F),
    this.accent = const Color(0xFF378ADD),
    this.backgroundMode = TicketBackgroundMode.gradient,
    this.typography = TicketTypographyStyle.system,
  });

  final Color primary;
  final Color accent;
  final TicketBackgroundMode backgroundMode;
  final TicketTypographyStyle typography;

  static const classic = TicketVisualStyle();

  static const festive = TicketVisualStyle(
    primary: Color(0xFF7A1F2B),
    accent: Color(0xFFE8A838),
    backgroundMode: TicketBackgroundMode.gradient,
    typography: TicketTypographyStyle.featured,
  );

  static const dark = TicketVisualStyle(
    primary: Color(0xFF111827),
    accent: Color(0xFF6B7280),
    backgroundMode: TicketBackgroundMode.solid,
    typography: TicketTypographyStyle.compact,
  );

  static const institutional = TicketVisualStyle(
    primary: Color(0xFF14532D),
    accent: Color(0xFF86EFAC),
    backgroundMode: TicketBackgroundMode.gradient,
    typography: TicketTypographyStyle.system,
  );

  TicketVisualStyle copyWith({
    Color? primary,
    Color? accent,
    TicketBackgroundMode? backgroundMode,
    TicketTypographyStyle? typography,
  }) {
    return TicketVisualStyle(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      typography: typography ?? this.typography,
    );
  }

  FontWeight get titleWeight => switch (typography) {
        TicketTypographyStyle.system => FontWeight.w800,
        TicketTypographyStyle.featured => FontWeight.w900,
        TicketTypographyStyle.compact => FontWeight.w700,
      };

  double get titleSize => switch (typography) {
        TicketTypographyStyle.system => 18,
        TicketTypographyStyle.featured => 20,
        TicketTypographyStyle.compact => 16,
      };

  double get numberSize => switch (typography) {
        TicketTypographyStyle.system => 28,
        TicketTypographyStyle.featured => 32,
        TicketTypographyStyle.compact => 24,
      };

  double get titleLetterSpacing => switch (typography) {
        TicketTypographyStyle.system => 0,
        TicketTypographyStyle.featured => 0.4,
        TicketTypographyStyle.compact => -0.2,
      };

  factory TicketVisualStyle.fromFirestore(Object? raw) {
    if (raw is! Map) return TicketVisualStyle.classic;
    final data = Map<String, dynamic>.from(raw);
    return TicketVisualStyle(
      primary: _colorFrom(data['primary']) ?? classic.primary,
      accent: _colorFrom(data['accent']) ?? classic.accent,
      backgroundMode: TicketBackgroundMode.values.firstWhere(
        (m) => m.name == data['backgroundMode'],
        orElse: () => TicketBackgroundMode.gradient,
      ),
      typography: TicketTypographyStyle.values.firstWhere(
        (t) => t.name == data['typography'],
        orElse: () => TicketTypographyStyle.system,
      ),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
        'primary': primary.toARGB32(),
        'accent': accent.toARGB32(),
        'backgroundMode': backgroundMode.name,
        'typography': typography.name,
      };

  static Color? _colorFrom(Object? value) {
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    return null;
  }
}

