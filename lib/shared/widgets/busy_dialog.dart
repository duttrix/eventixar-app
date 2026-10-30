import 'dart:async';

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
///
/// When [messages] has more than one line, they rotate so a long wait
/// does not look frozen.
Future<T> runBusyFullscreen<T>(
  BuildContext context, {
  required String message,
  List<String> messages = const [],
  required Future<T> Function() work,
}) async {
  final lines = messages.isEmpty ? [message] : messages;
  var index = 0;
  Timer? timer;
  void Function(void Function())? setDialogState;

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
              child: StatefulBuilder(
                builder: (_, setState) {
                  setDialogState = setState;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        lines[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );

  if (lines.length > 1) {
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      index = (index + 1) % lines.length;
      setDialogState?.call(() {});
    });
  }

  try {
    return await work();
  } finally {
    timer?.cancel();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// Copy shown while a large event is being created.
List<String> longEventCreateMessages(int ticketCount) {
  if (ticketCount <= 5000) return const [];
  return const [
    'Estamos creando tu evento.',
    'Estamos generando tus tickets.',
    'Tickets listos para cobrar.',
    'Ya falta poco.',
    'No cierres la app. En un momento terminamos.',
  ];
}
