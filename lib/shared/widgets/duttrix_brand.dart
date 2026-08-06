import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Brand asset paths for Duttrix logos.
abstract final class BrandAssets {
  static const simbolo = 'assets/brand/duttrix-simbolo.png';
  static const horizontalClaro = 'assets/brand/duttrix-horizontal-claro.png';
  static const horizontalOscuro = 'assets/brand/duttrix-horizontal-oscuro.png';
  static const appIcon = 'assets/brand/duttrix-app-icon.png';
}

/// Compact Duttrix mark (ticket stack + amber dot).
class DuttrixMark extends StatelessWidget {
  const DuttrixMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.simbolo,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Horizontal Duttrix logo for light backgrounds.
class DuttrixLogo extends StatelessWidget {
  const DuttrixLogo({
    super.key,
    this.height = 56,
    this.dark = false,
  });

  final double height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      dark ? BrandAssets.horizontalOscuro : BrandAssets.horizontalClaro,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Wordmark-style brand block used on login and drawer.
class DuttrixBrandHeader extends StatelessWidget {
  const DuttrixBrandHeader({
    super.key,
    this.compact = false,
    this.tagline = 'Gestión de eventos',
  });

  final bool compact;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          const DuttrixMark(size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Wordmark(fontSize: 18),
              Text(
                tagline,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Login / hero: símbolo oficial + wordmark (no el PNG horizontal).
    return Column(
      children: [
        const DuttrixMark(size: 88),
        const SizedBox(height: 18),
        const _Wordmark(fontSize: 32),
        if (tagline.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tagline.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
              letterSpacing: 2.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'D',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 0.5,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: 'uttrix',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: 0.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
