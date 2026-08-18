import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/models/event.dart';
import '../data/models/ticket.dart';
import '../data/models/ticket_design.dart';

typedef TicketPdfProgress = void Function(int done, int total);

/// A4 PDFs with the shared ticket look, drawn as vectors (no screenshots).
class TicketPdf {
  TicketPdf._();

  static const ticketsPerPage = 6;
  static const _columns = 2;

  static Future<Uint8List> build({
    required Event event,
    required List<Ticket> tickets,
    TicketVisualStyle style = TicketVisualStyle.classic,
    TicketPdfProgress? onProgress,
    Map<String, String> sellerNames = const {},
  }) async {
    final sorted = [...tickets]..sort((a, b) => a.number.compareTo(b.number));
    final doc = pw.Document();

    if (sorted.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Text('Sin tickets para imprimir.')),
        ),
      );
      return doc.save();
    }

    for (var i = 0; i < sorted.length; i += ticketsPerPage) {
      final pageTickets =
          sorted.skip(i).take(ticketsPerPage).toList(growable: false);
      final firstNumber = pageTickets.first.number;
      final lastNumber = pageTickets.last.number;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  event.name,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  pageTickets.length == 1
                      ? 'Ticket #${pageTickets.first.number}'
                      : 'Tickets #$firstNumber-#$lastNumber - '
                          '${sorted.length} en total',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: _columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.08,
                    children: [
                      for (final ticket in pageTickets)
                        _ticketCard(event, ticket, style, sellerNames),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      onProgress?.call(
        (i + pageTickets.length).clamp(0, sorted.length),
        sorted.length,
      );
      await Future<void>.delayed(Duration.zero);
    }

    return doc.save();
  }

  static pw.Widget _ticketCard(
    Event event,
    Ticket ticket,
    TicketVisualStyle style,
    Map<String, String> sellerNames,
  ) {
    final primary = _pdfColor(style.primary);
    final accent = _pdfColor(style.accent);
    final buyer = ticket.buyerName.trim();
    final sellerId = ticket.sellerId?.trim();
    final seller = (sellerId == null || sellerId.isEmpty)
        ? ''
        : (sellerNames[sellerId]?.trim() ?? '');
    final useGradient = style.backgroundMode != TicketBackgroundMode.solid;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: useGradient ? null : primary,
        gradient: useGradient
            ? pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: [primary, accent],
              )
            : null,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DUTTRIX',
            style: pw.TextStyle(
              color: _white(0.72),
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing:
                  style.typography == TicketTypographyStyle.compact ? 0.6 : 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            event.name,
            maxLines: 2,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: _printTitleSize(style),
              fontWeight: pw.FontWeight.bold,
              letterSpacing: style.titleLetterSpacing,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${event.product} - \$${event.ticketPrice.toStringAsFixed(0)}',
            maxLines: 1,
            style: pw.TextStyle(color: _white(0.72), fontSize: 9),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TICKET',
                        style: pw.TextStyle(
                          color: _white(0.55),
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.Text(
                        '#${ticket.number}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: _printNumberSize(style),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (buyer.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Para: $buyer',
                          maxLines: 2,
                          style: pw.TextStyle(
                            color: _white(0.72),
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                      if (seller.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Vendedor: $seller',
                          maxLines: 2,
                          style: pw.TextStyle(
                            color: _white(0.72),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Container(
                  width: 82,
                  height: 82,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: accent, width: 1.6),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: pw.BarcodeQRCorrectionLevel.quartile,
                    ),
                    data: ticket.qrPayload,
                    color: PdfColors.black,
                    backgroundColor: PdfColors.white,
                    width: 72,
                    height: 72,
                    drawText: false,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'Fecha: ${event.eventWhenLabel}',
            maxLines: 1,
            style: pw.TextStyle(color: _white(0.6), fontSize: 8),
          ),
          if (event.pickupPlace.trim().isNotEmpty)
            pw.Text(
              'Lugar: ${event.pickupPlace.trim()}',
              maxLines: 2,
              style: pw.TextStyle(color: _white(0.6), fontSize: 8),
            ),
        ],
      ),
    );
  }

  static double _printTitleSize(TicketVisualStyle style) =>
      switch (style.typography) {
        TicketTypographyStyle.system => 13,
        TicketTypographyStyle.featured => 14,
        TicketTypographyStyle.compact => 12,
      };

  static double _printNumberSize(TicketVisualStyle style) =>
      switch (style.typography) {
        TicketTypographyStyle.system => 22,
        TicketTypographyStyle.featured => 24,
        TicketTypographyStyle.compact => 20,
      };

  static PdfColor _pdfColor(Color color) =>
      PdfColor(color.r, color.g, color.b, color.a);

  static PdfColor _white(double opacity) => PdfColor(1, 1, 1, opacity);

  /// Generates the PDF and opens the system sheet to save or share it.
  static Future<void> downloadTickets({
    required Event event,
    required List<Ticket> tickets,
    TicketVisualStyle style = TicketVisualStyle.classic,
    TicketPdfProgress? onProgress,
    Map<String, String> sellerNames = const {},
  }) async {
    if (tickets.isEmpty) return;

    final bytes = await build(
      event: event,
      tickets: tickets,
      style: style,
      onProgress: onProgress,
      sellerNames: sellerNames,
    );

    final dir = await getTemporaryDirectory();
    final fileName = _pdfFileName(event, tickets);
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf', name: fileName)],
      subject: 'Tickets - ${event.name}',
    );
  }

  static String _pdfFileName(Event event, List<Ticket> tickets) {
    final slug = event.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]', unicode: true), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final safeSlug = slug.isEmpty ? 'evento' : slug;
    if (tickets.length == 1) {
      return 'duttrix_${safeSlug}_ticket_${tickets.first.number}.pdf';
    }
    return 'duttrix_${safeSlug}_${tickets.length}_tickets.pdf';
  }
}
