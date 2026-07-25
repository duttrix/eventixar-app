import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared loading / error / data shell for Firestore-backed screens.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.padding,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo cargar: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (data) {
        final child = builder(context, data);
        if (padding == null) return child;
        return Padding(padding: padding!, child: child);
      },
    );
  }
}
