import 'package:flutter/material.dart';

/// Duttrix palette — Esmeralda design tokens.
class AppColors {
  AppColors._();

  // Brand
  static const Color night = Color(0xFF0C1F1C);
  static const Color emerald = Color(0xFF0E9F8E);
  static const Color emerald500 = Color(0xFF16C79A);
  static const Color emerald200 = Color(0xFF7DE8CE);
  static const Color amber = Color(0xFFFFC24A);

  // Surfaces / neutrals
  static const Color background = Color(0xFFF4F6F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEEF1F0);
  static const Color border = Color(0xFFDDE3E1);
  static const Color borderStrong = Color(0xFFC5CEC9);

  // Text
  static const Color text = Color(0xFF14231F);
  static const Color textSecondary = Color(0xFF5B6B66);
  static const Color textMuted = Color(0xFF8A9793);

  // Primary accent (maps to emerald)
  static const Color accent = emerald;
  static const Color accentBg = Color(0xFFE6F7F2);
  static const Color accentText = Color(0xFF0A6B5F);

  // Semantic
  static const Color successText = Color(0xFF0A6B5F);
  static const Color successBg = Color(0xFFE6F7F2);

  static const Color dangerText = Color(0xFF9E2C2C);
  static const Color dangerBg = Color(0xFFFBE9E9);

  static const Color warnText = Color(0xFF8A6410);
  static const Color warnBg = Color(0xFFFEF3D9);
}
