import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/coupon.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Entry via deeplink. Routes seller → coupon portal, deliverer → QR portal.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final collab = ref.read(repositoryProvider).collaboratorByToken(widget.token);
      if (collab == null) return;
      ref.read(sessionProvider.notifier).enterAsCollaborator(widget.token);
      if (collab.role == CollaboratorRole.seller) {
        context.go('/seller/${widget.token}');
      } else {
        context.go('/deliverer/${widget.token}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collab = ref.watch(repositoryProvider).collaboratorByToken(widget.token);
    if (collab == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Link inválido')),
        body: const Center(child: Text('Este deeplink no existe o ya no es válido.')),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Seller portal: digital coupons ready to print or hand out one by one.
class SellerPortalScreen extends ConsumerWidget {
  const SellerPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final seller = repo.collaboratorByToken(token);
    if (seller == null || seller.role != CollaboratorRole.seller) {
      return const Scaffold(body: Center(child: Text('Vendedor no encontrado.')));
    }
    final event = repo.eventById(seller.eventId);
    final coupons = repo.couponsForSeller(seller.id)..sort((a, b) => a.number.compareTo(b.number));

    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tus cupones para vender', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  seller.ranges.isEmpty
                      ? 'Todavía no te asignaron rangos.'
                      : 'Rangos: ${seller.ranges.map((r) => r.label).join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: coupons.isEmpty
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PDF de cupones listo para imprimir (simulado).')),
                          );
                        },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: seller.shareUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado.')),
                    );
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Mi link'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Cupones (${coupons.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (coupons.isEmpty)
            const Text('Cuando el organizador te asigne un rango, van a aparecer acá.', style: TextStyle(color: AppColors.textMuted))
          else
            for (final coupon in coupons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cupón #${coupon.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('\$${event.couponPrice.toStringAsFixed(0)} · ${event.product}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: coupon.status.label,
                        tone: switch (coupon.status) {
                          CouponStatus.collected => BadgeTone.success,
                          CouponStatus.returned => BadgeTone.danger,
                          CouponStatus.delivered => BadgeTone.info,
                          _ => BadgeTone.warn,
                        },
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<CouponStatus>(
                        onSelected: (status) =>
                            ref.read(repositoryProvider).updateCouponStatus(coupon.id, status),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: CouponStatus.withSeller, child: Text('En mi poder')),
                          PopupMenuItem(value: CouponStatus.collected, child: Text('Marcar cobrado')),
                          PopupMenuItem(value: CouponStatus.returned, child: Text('Devuelto')),
                        ],
                        child: const Icon(Icons.more_vert, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Deliverer portal: scan / look up coupons and mark as delivered.
class DelivererPortalScreen extends ConsumerStatefulWidget {
  const DelivererPortalScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<DelivererPortalScreen> createState() => _DelivererPortalScreenState();
}

class _DelivererPortalScreenState extends ConsumerState<DelivererPortalScreen> {
  final _numberController = TextEditingController();
  String? _message;
  Coupon? _lastCoupon;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _lookup() {
    final repo = ref.read(repositoryProvider);
    final deliverer = repo.collaboratorByToken(widget.token);
    if (deliverer == null) return;
    final number = int.tryParse(_numberController.text.trim());
    if (number == null) {
      setState(() {
        _message = 'Ingresá un número de cupón válido.';
        _lastCoupon = null;
      });
      return;
    }
    final coupon = repo.findCouponByNumber(deliverer.eventId, number);
    if (coupon == null) {
      setState(() {
        _message = 'Cupón #$number no encontrado en este evento.';
        _lastCoupon = null;
      });
      return;
    }
    setState(() {
      _lastCoupon = coupon;
      _message = null;
    });
  }

  void _deliver() {
    final coupon = _lastCoupon;
    if (coupon == null) return;
    if (coupon.status == CouponStatus.delivered) {
      setState(() => _message = 'Este cupón ya fue entregado.');
      return;
    }
    if (coupon.status != CouponStatus.collected) {
      setState(() => _message = 'El cupón no figura como cobrado. Revisá con el organizador.');
      return;
    }
    ref.read(repositoryProvider).markDelivered(coupon.id);
    setState(() {
      _message = 'Cupón #${coupon.number} entregado.';
      _lastCoupon = ref.read(repositoryProvider).findCouponByNumber(coupon.eventId, coupon.number);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final deliverer = repo.collaboratorByToken(widget.token);
    if (deliverer == null || deliverer.role != CollaboratorRole.deliverer) {
      return const Scaffold(body: Center(child: Text('Entregador no encontrado.')));
    }
    final event = repo.eventById(deliverer.eventId);

    return Scaffold(
      appBar: AppBar(
        title: Text(deliverer.name),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Retiro · ${event.pickupPlace}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '${event.pickupFrom.format(context)} – ${event.pickupTo.format(context)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Lectura de cupón',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cámara QR simulada: ingresá el número manualmente.')),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear QR (simulado)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de cupón',
                    hintText: 'Ej. 18',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _lookup, child: const Text('Buscar')),
              ],
            ),
          ),
          if (_lastCoupon != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Cupón #${_lastCoupon!.number}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusBadge(label: _lastCoupon!.status.label),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _lastCoupon!.status == CouponStatus.delivered ? null : _deliver,
                    child: Text(
                      _lastCoupon!.status == CouponStatus.delivered ? 'Ya entregado' : 'Marcar entregado',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
