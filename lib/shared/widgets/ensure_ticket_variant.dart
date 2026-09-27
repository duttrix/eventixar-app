import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../data/models/event.dart';
import '../../data/models/event_product.dart';
import '../../data/models/ticket.dart';
import 'app_snackbar.dart';

/// Asks for a variant when the product has options and the tickets lack one.
///
/// Returns false when the user cancels or the selection mixes products.
Future<bool> ensureTicketVariants({
  required BuildContext context,
  required WidgetRef ref,
  required Event event,
  required List<Ticket> tickets,
  required String actorId,
  required String actorRole,
}) async {
  final pending = tickets.where((ticket) {
    final product = event.productFor(ticket);
    if (product.variants.isEmpty) return false;
    return product.variantById(ticket.variantId) == null;
  }).toList(growable: false);
  if (pending.isEmpty) return true;

  final productIds = pending.map((ticket) => event.productFor(ticket).id).toSet();
  if (productIds.length != 1) {
    AppSnackBar.warning(
      context,
      'Elegí la opción de a un producto.',
    );
    return false;
  }

  final product = event.productFor(pending.first);
  final allTickets =
      ref.read(eventTicketsProvider(event.id)).asData?.value ?? tickets;
  final variant = await showDialog<EventProductVariant>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pending.length == 1
                  ? 'Elegí la opción del ticket #${pending.first.number}.'
                  : 'Elegí la opción para ${pending.length} tickets.',
            ),
            const SizedBox(height: 12),
            for (final option in product.variants)
              _VariantTile(
                product: product,
                variant: option,
                used: _usedQuota(allTickets, option.id),
                adding: pending.length,
                onTap: () => Navigator.pop(dialogContext, option),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );
  if (variant == null || !context.mounted) return false;

  try {
    await setTicketsVariantAction(
      ref,
      eventId: event.id,
      ticketIds: pending.map((ticket) => ticket.id),
      variantId: variant.id,
      actorId: actorId,
      actorRole: actorRole,
    );
    for (final ticket in pending) {
      ticket.variantId = variant.id;
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.error(context, '$e', cause: e);
    }
    return false;
  }
}

int _usedQuota(List<Ticket> tickets, String variantId) {
  var used = 0;
  for (final ticket in tickets) {
    if (ticket.variantId == variantId) used++;
  }
  return used;
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.product,
    required this.variant,
    required this.used,
    required this.adding,
    required this.onTap,
  });

  final EventProduct product;
  final EventProductVariant variant;
  final int used;
  final int adding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final capped = variant.quota > 0;
    final left = variant.quota - used;
    final blocked = capped && left < adding;
    final price = product.priceOnVariant
        ? ' · \$${variant.price.toStringAsFixed(0)}'
        : '';
    final cupo = !capped
        ? ''
        : left <= 0
            ? ' · sin cupo'
            : ' · quedan $left';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !blocked,
      title: Text('${variant.name}$price'),
      subtitle: cupo.isEmpty ? null : Text(cupo.trim()),
      onTap: blocked ? null : onTap,
    );
  }
}
