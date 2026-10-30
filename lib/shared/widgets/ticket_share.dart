import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/phone/ar_whatsapp_phone.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/models/ticket_design.dart';

export '../../data/models/ticket_design.dart';

/// Share de tickets como **imágenes PNG** (sin texto/links al comprador).
class TicketShare {
  TicketShare._();

  static const _whatsAppChannel = MethodChannel('eventixar/whatsapp');

  /// Fixed Argentine mobile prefix for WhatsApp (`+54 9…`).
  static const whatsAppArPrefix = ArWhatsAppPhone.prefix;

  /// Local AR mobile digits → full `wa.me` number (`549…`, no `+`).
  static String? normalizeWhatsAppPhone(String raw) =>
      ArWhatsAppPhone.toWaMeDigits(raw);

  /// Display form with `+`, e.g. `+5491123456789`.
  static String formatWhatsAppPhone(String normalizedDigits) =>
      ArWhatsAppPhone.display(normalizedDigits);

  /// Renders [TicketSharePreview] off-screen and returns a PNG.
  static Future<Uint8List> renderPng(
    BuildContext context, {
    required Ticket ticket,
    required Event event,
    TicketVisualStyle style = TicketVisualStyle.classic,
    String sellerName = '',
  }) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      throw StateError('No hay Overlay para renderizar el ticket.');
    }
    return renderPngWithOverlay(
      overlay,
      ticket: ticket,
      event: event,
      style: style,
      sellerName: sellerName,
    );
  }

  static Future<Uint8List> renderPngWithOverlay(
    OverlayState overlay, {
    required Ticket ticket,
    required Event event,
    TicketVisualStyle style = TicketVisualStyle.classic,
    double pixelRatio = 3,
    String sellerName = '',
  }) async {
    final key = GlobalKey();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -5000,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 360,
            child: RepaintBoundary(
              key: key,
              child: TicketSharePreview(
                ticket: ticket,
                event: event,
                style: style,
                sellerName: sellerName,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    // One more frame so gradients / QR paint fully.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('No se pudo capturar el ticket.');
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('No se pudo codificar el PNG.');
        return bytes.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
    }
  }

  static Future<List<XFile>> buildImageFiles(
    OverlayState overlay, {
    required List<Ticket> tickets,
    required Event event,
    TicketVisualStyle style = TicketVisualStyle.classic,
    Map<String, String> sellerNames = const {},
  }) async {
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];
    for (final ticket in tickets) {
      final png = await renderPngWithOverlay(
        overlay,
        ticket: ticket,
        event: event,
        style: style,
        sellerName: _sellerNameFor(ticket, sellerNames),
      );
      final path = '${dir.path}/ticket_${event.id}_${ticket.id}.png';
      await File(path).writeAsBytes(png, flush: true);
      files.add(
        XFile(path, mimeType: 'image/png', name: 'ticket_${ticket.number}.png'),
      );
    }
    return files;
  }

  /// Asks for a mobile number and opens that WhatsApp chat.
  /// Android attaches the ticket images in the composer.
  /// iPhone opens the same chat and leaves the image on the clipboard,
  /// because WhatsApp there cannot receive the file and the number together.
  ///
  /// Returns false when the user dismisses the phone sheet.
  static Future<bool> shareImages(
    BuildContext context, {
    required List<Ticket> tickets,
    required Event event,
    TicketVisualStyle style = TicketVisualStyle.classic,
    Map<String, String> sellerNames = const {},
  }) async {
    if (tickets.isEmpty) return false;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      throw StateError('No hay Overlay para renderizar el ticket.');
    }

    final phone = await _askWhatsAppPhone(context, count: tickets.length);
    if (phone == null || !context.mounted) return false;

    final files = await buildImageFiles(
      overlay,
      tickets: tickets,
      event: event,
      style: style,
      sellerNames: sellerNames,
    );
    try {
      await _whatsAppChannel.invokeMethod<void>('shareImages', {
        'phone': phone,
        'paths': [for (final file in files) file.path],
      });
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'No se pudo abrir WhatsApp.');
    }
    return true;
  }

  static String _sellerNameFor(Ticket ticket, Map<String, String> sellerNames) {
    final id = ticket.sellerId?.trim();
    if (id == null || id.isEmpty) return '';
    return sellerNames[id]?.trim() ?? '';
  }

  static Future<String?> _askWhatsAppPhone(
    BuildContext context, {
    required int count,
  }) {
    final title = count == 1
        ? 'Compartir por WhatsApp'
        : 'Compartir $count tickets por WhatsApp';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _WhatsAppPhoneSheet(title: title),
    );
  }
}

/// Visual preview of the ticket (buyer view / shared image).
class TicketSharePreview extends StatelessWidget {
  const TicketSharePreview({
    super.key,
    required this.ticket,
    required this.event,
    this.style = TicketVisualStyle.classic,
    this.showQr = true,
    this.sellerName = '',
  });

  final Ticket ticket;
  final Event event;
  final TicketVisualStyle style;
  final bool showQr;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    final decoration = switch (style.backgroundMode) {
      TicketBackgroundMode.solid => BoxDecoration(
          color: style.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _shadow,
        ),
      TicketBackgroundMode.gradient => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [style.primary, style.accent],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _shadow,
        ),
      TicketBackgroundMode.image => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              style.primary.withValues(alpha: 0.92),
              style.accent.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: _shadow,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'DUTTRIX',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: style.typography == TicketTypographyStyle.compact
                      ? 0.6
                      : 1.2,
                ),
              ),
              if (style.backgroundMode == TicketBackgroundMode.image) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'FONDO EJEMPLO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            event.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: style.titleSize,
              fontWeight: style.titleWeight,
              letterSpacing: style.titleLetterSpacing,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.saleLabelFor(ticket),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TICKET',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '#${ticket.number}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: style.numberSize,
                        fontWeight: style.titleWeight,
                      ),
                    ),
                    if (ticket.buyerName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Para: ${ticket.buyerName.trim()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (sellerName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Vendedor: ${sellerName.trim()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showQr)
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: style.accent, width: 2),
                  ),
                  child: QrImageView(
                    data: ticket.qrPayload,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.text,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.text,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fecha: ${event.eventWhenLabel}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          if (event.pickupPlace.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Lugar: ${event.pickupPlace.trim()}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static final List<BoxShadow> _shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class _WhatsAppPhoneSheet extends StatefulWidget {
  const _WhatsAppPhoneSheet({required this.title});

  final String title;

  @override
  State<_WhatsAppPhoneSheet> createState() => _WhatsAppPhoneSheetState();
}

class _WhatsAppPhoneSheetState extends State<_WhatsAppPhoneSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final digits = ArWhatsAppPhone.toWaMeDigits(_controller.text);
    if (digits == null) {
      setState(() => _error = 'Ingresá un celular válido.');
      return;
    }
    Navigator.pop(context, digits);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            Platform.isIOS
                ? 'Se abre el chat de ese número, aunque no lo tengas agendado. '
                    'Ahí mantené apretado y pegá la imagen.'
                : 'Se abre el chat de ese número, aunque no lo tengas agendado.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Celular',
              hintText: '11 2345 6789',
              errorText: _error,
              isDense: true,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Abrir WhatsApp'),
          ),
        ],
      ),
    );
  }
}
