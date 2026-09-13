import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/payment_config.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/help_whatsapp.dart';
import '../../shared/widgets/section_card.dart';

/// Checkout via bank transfer. Details come from Firestore `config/payment`.
class PayEventScreen extends ConsumerStatefulWidget {
  const PayEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<PayEventScreen> createState() => _PayEventScreenState();
}

class _PayEventScreenState extends ConsumerState<PayEventScreen> {
  bool _notifying = false;
  bool _applyingCoupon = false;
  final _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(eventProvider(widget.eventId)).when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Pagar')),
            body: Center(child: Text('No se pudo cargar el evento: $e')),
          ),
          data: _buildBody,
        );
  }

  Widget _buildBody(Event event) {
    if (event.status == EventStatus.active) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/event/${widget.eventId}'),
            child: const Text('Evento activo · Ir al workspace'),
          ),
        ),
      );
    }

    final pricing = ref.watch(eventPricingProvider).asData?.value;
    final paymentAsync = ref.watch(paymentConfigProvider);
    final payment = paymentAsync.asData?.value;
    final notifyPhone = payment?.notifyPhone;
    final configLoading = paymentAsync.isLoading;
    final baseQuote = pricing == null
        ? null
        : EventQuote.calculate(
            ticketCount: event.ticketCount,
            pricing: pricing,
          );
    final quote = baseQuote == null
        ? null
        : (event.couponPercent != null && event.couponPercent! > 0)
            ? baseQuote.withDiscount(event.couponPercent!)
            : baseQuote;
    final canNotify = notifyPhone != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _notifying ? null : () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: event.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quote != null) ...[
                  if (event.couponPercent != null &&
                      event.couponPercent! > 0 &&
                      baseQuote != null) ...[
                    Text(
                      baseQuote.priceLabel,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    quote.priceLabel,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.couponCode != null
                        ? 'Cupón ${event.couponCode} · ${event.couponPercent}% off'
                        : quote.breakdown.first,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (event.couponCode == null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          textCapitalization: TextCapitalization.characters,
                          enabled: !_applyingCoupon,
                          decoration: const InputDecoration(
                            labelText: 'Cupón de descuento',
                            hintText: 'Ej. K7M2PQ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: _applyingCoupon
                              ? null
                              : () => _applyCoupon(event),
                          child: _applyingCoupon
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'El evento queda pendiente hasta que acreditemos la transferencia. '
                  'Ahí pasa a Activos y podés entrar.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Transferencia bancaria',
            child: payment == null
                ? const Text(
                    'Todavía no están cargados los datos de la cuenta. '
                    'Probá más tarde o escribí a Ayuda.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  )
                : _TransferDetails(payment: payment),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _notifying || configLoading || notifyPhone == null
                ? null
                : () => _notifyTransfer(event, quote, notifyPhone),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _notifying || configLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      event.transferNotifiedAt == null
                          ? 'Ya transferí'
                          : 'Avisar de nuevo por WhatsApp',
                    ),
            ),
          ),
          if (!configLoading && !canNotify) ...[
            const SizedBox(height: 8),
            const Text(
              'Falta el teléfono de aviso. En Firestore, config/payment, '
              'campo notifyPhone (ej. 5491123456789).',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _applyCoupon(Event event) async {
    setState(() => _applyingCoupon = true);
    try {
      await ref.read(couponRepositoryProvider).applyToEvent(
            eventId: event.id,
            eventName: event.name,
            code: _couponController.text,
          );
      if (!mounted) return;
      _couponController.clear();
      AppSnackBar.info(context, 'Cupón aplicado.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        e is StateError ? e.message : 'No se pudo aplicar el cupón.',
        cause: e,
      );
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  Future<void> _notifyTransfer(
    Event event,
    EventQuote? quote,
    String phone,
  ) async {

    final amountLabel = quote?.priceLabel ?? '—';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Ya hiciste la transferencia?'),
        content: Text(
          'Vamos a abrir WhatsApp para avisarnos. '
          'El evento sigue pendiente hasta que acreditemos los $amountLabel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Avisar por WhatsApp'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _notifying = true);
    try {
      await ref.read(eventRepositoryProvider).recordTransferNotice(event.id);
      if (!mounted) return;

      final session = ref.read(sessionProvider);
      final who = (session.displayName ?? '').trim().isEmpty
          ? (session.userEmail ?? '')
          : session.displayName!;
      final text = [
        'Hola, ya transferí para habilitar un evento en Duttrix.',
        '',
        'Evento: ${event.name}',
        'Tickets: ${event.ticketCount}',
        'Monto: $amountLabel',
        if (event.couponCode != null)
          'Cupón: ${event.couponCode} (${event.couponPercent}%)',
        if (event.couponDiscountAmount != null &&
            event.couponDiscountAmount! > 0)
          'Descuento: \$${EventQuote.formatAmount(event.couponDiscountAmount!)}',
        if (who.isNotEmpty) 'Organizador: $who',
      ].join('\n');
      await openWhatsApp(context, phone, text: text);
      if (!mounted) return;
      AppSnackBar.info(
        context,
        'Aviso enviado. El evento se habilita cuando acreditemos la transferencia.',
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'No se pudo enviar el aviso. Probá de nuevo.',
        cause: e,
      );
    } finally {
      if (mounted) setState(() => _notifying = false);
    }
  }
}

class _TransferDetails extends StatelessWidget {
  const _TransferDetails({required this.payment});

  final PaymentConfig payment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transferí el monto de la cotización a esta cuenta. '
          'Después tocá Ya transferí para avisarnos. El evento queda pendiente hasta que acreditemos.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (payment.holderName != null)
          _CopyRow(label: 'Titular', value: payment.holderName!),
        if (payment.bankName != null)
          _CopyRow(label: 'Banco', value: payment.bankName!),
        if (payment.alias != null) _CopyRow(label: 'Alias', value: payment.alias!),
        if (payment.cbu != null) _CopyRow(label: 'CBU / CVU', value: payment.cbu!),
        if (payment.cuit != null) _CopyRow(label: 'CUIT', value: payment.cuit!),
        if (payment.instructions != null) ...[
          const SizedBox(height: 8),
          Text(
            payment.instructions!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar $label',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                AppSnackBar.info(context, '$label copiado');
              }
            },
            icon: const Icon(Icons.copy_outlined, size: 20),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
