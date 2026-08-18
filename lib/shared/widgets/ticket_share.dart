import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event.dart';
import '../../data/models/ticket.dart';
import '../../data/models/ticket_design.dart';

export '../../data/models/ticket_design.dart';

/// Share de tickets como **imágenes PNG** (sin texto/links al comprador).
class TicketShare {
  TicketShare._();

  /// Fixed Argentine mobile prefix for WhatsApp (`+54 9…`).
  static const whatsAppArPrefix = '549';

  /// Local AR mobile digits → full `wa.me` number (`549…`, no `+`).
  ///
  /// Expects the area + number only (e.g. `11 2345-6789`). Strips a leading
  /// `0` / `54` / `549` if the user pasted a full number by mistake.
  static String? normalizeWhatsAppPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith(whatsAppArPrefix)) {
      digits = digits.substring(whatsAppArPrefix.length);
    } else if (digits.startsWith('54')) {
      digits = digits.substring(2);
      if (digits.startsWith('9')) digits = digits.substring(1);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length < 8 || digits.length > 10) return null;
    return '$whatsAppArPrefix$digits';
  }

  /// Display form with `+`, e.g. `+5491123456789`.
  static String formatWhatsAppPhone(String normalizedDigits) =>
      normalizedDigits.startsWith('+') ? normalizedDigits : '+$normalizedDigits';

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

  /// Generates PNG(s) and opens the system share sheet (WhatsApp, etc.).
  ///
  /// No caption/text is attached: the buyer should receive only the images.
  static Future<void> shareImages(
    BuildContext context, {
    required List<Ticket> tickets,
    required Event event,
    TicketVisualStyle style = TicketVisualStyle.classic,
    Map<String, String> sellerNames = const {},
  }) async {
    if (tickets.isEmpty) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      throw StateError('No hay Overlay para renderizar el ticket.');
    }
    final files = await buildImageFiles(
      overlay,
      tickets: tickets,
      event: event,
      style: style,
      sellerNames: sellerNames,
    );
    await Share.shareXFiles(files);
  }

  static String _sellerNameFor(Ticket ticket, Map<String, String> sellerNames) {
    final id = ticket.sellerId?.trim();
    if (id == null || id.isEmpty) return '';
    return sellerNames[id]?.trim() ?? '';
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
            '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)}',
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
