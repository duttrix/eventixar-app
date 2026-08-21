import 'package:flutter/material.dart';

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
