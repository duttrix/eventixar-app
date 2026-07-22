import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/coupon.dart';
import '../../data/mock/providers.dart';

/// Organizer roster of sellers for an event + deeplink sharing.
class VendedoresTab extends ConsumerWidget {
  const VendedoresTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final event = repo.eventById(eventId);
    final sellers = repo.sellersForEvent(eventId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sellers.length >= event.sellersCount
            ? null
            : () => _showAddDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text('Agregar (${sellers.length}/${event.sellersCount})'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Asigná rangos de cupones y compartí el deeplink. El vendedor entra sin registrarse y ve sus cupones listos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (sellers.isEmpty)
            const Text('Todavía no hay vendedores.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final seller in sellers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(seller.name),
                  subtitle: Text(
                    seller.ranges.isEmpty
                        ? 'Sin rangos · ${seller.phone}'
                        : '${seller.ranges.map((r) => r.label).join(', ')} · ${_pendingCount(repo.couponsForSeller(seller.id))} pendientes',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Copiar deeplink',
                        icon: const Icon(Icons.link),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: seller.shareUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Link de ${seller.name} copiado.')),
                          );
                        },
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/event/$eventId/vendedores/${seller.id}'),
                ),
              ),
        ],
      ),
    );
  }

  int _pendingCount(List<Coupon> coupons) {
    return coupons.where((c) => c.status == CouponStatus.withSeller).length;
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo vendedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular (WhatsApp)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final seller = ref.read(repositoryProvider).addCollaborator(
                      eventId: eventId,
                      role: CollaboratorRole.seller,
                      name: name,
                      phone: phoneController.text.trim(),
                    );
                Navigator.pop(dialogContext);
                Clipboard.setData(ClipboardData(text: seller.shareUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Vendedor creado. Link copiado: ${seller.shareUrl}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Crear y copiar link'),
          ),
        ],
      ),
    );
  }
}
