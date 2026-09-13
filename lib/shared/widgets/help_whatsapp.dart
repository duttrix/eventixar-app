import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import 'app_snackbar.dart';

/// Opens a WhatsApp chat with [digits] (`https://wa.me/{digits}`).
Future<void> openWhatsApp(
  BuildContext context,
  String digits, {
  String? text,
}) async {
  final uri = Uri.https('wa.me', '/$digits', {
    if (text != null && text.isNotEmpty) 'text': text,
  });
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackBar.error(context, 'No se pudo abrir WhatsApp.');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.error(context, 'No se pudo abrir WhatsApp.', cause: e);
    }
  }
}

String? _helpPhone(WidgetRef ref) {
  final phone = ref.watch(helpConfigProvider).asData?.value?.phoneNumber;
  if (phone == null || phone.isEmpty) return null;
  return phone;
}

/// AppBar action. Hidden until `config/help.phoneNumber` is set.
class HelpWhatsAppIconButton extends ConsumerWidget {
  const HelpWhatsAppIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = _helpPhone(ref);
    if (phone == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Ayuda',
      onPressed: () => openWhatsApp(context, phone),
      icon: const Icon(Icons.help_outline),
    );
  }
}

/// Login / footer text action. Hidden until the number is set.
class HelpWhatsAppTextButton extends ConsumerWidget {
  const HelpWhatsAppTextButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = _helpPhone(ref);
    if (phone == null) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => openWhatsApp(context, phone),
      icon: const Icon(Icons.help_outline, size: 18),
      label: const Text('Ayuda'),
      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
    );
  }
}
