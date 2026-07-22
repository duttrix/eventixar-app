import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A titled card container reused across list/detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
