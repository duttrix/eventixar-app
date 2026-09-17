import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Blocking progress dialog while an async write finishes.
///
/// Use for Firestore mutations so the UI does not look half-updated.
Future<T> runBusyDialog<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function(void Function(String label) setLabel) work,
}) async {
  var label = message;
  void Function(void Function())? setDialogState;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => StatefulBuilder(
      builder: (_, setState) {
        setDialogState = setState;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  try {
    return await work((next) {
      label = next;
      setDialogState?.call(() {});
    });
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// Opaque full-screen loader. Blocks back and taps until [work] finishes.
Future<T> runBusyFullscreen<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() work,
}) async {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.background,
    useRootNavigator: true,
    pageBuilder: (dialogContext, _, _) {
      return PopScope(
        canPop: false,
        child: Material(
          color: AppColors.background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  try {
    return await work();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
