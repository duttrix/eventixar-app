import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/event.dart';
import '../../data/models/ticket.dart';

/// Builds printable A4 PDFs with up to 6 ticket cards per page.
class TicketPdf {
  TicketPdf._();

  static Future<Uint8List> build({
    required Event event,
    required List<Ticket> tickets,
  }) async {
    final sorted = [...tickets]..sort((a, b) => a.number.compareTo(b.number));
    final doc = pw.Document();

    for (var i = 0; i < sorted.length; i += 6) {
      final pageTickets = sorted.skip(i).take(6).toList(growable: false);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  event.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)} · '
                  '${sorted.length} tickets',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      for (final ticket in pageTickets)
                        _ticketCard(event, ticket),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    if (sorted.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Text('Sin tickets para imprimir.')),
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _ticketCard(Event event, Ticket ticket) {
    final buyer = ticket.buyerName.trim();
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.2),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.blueGrey50,
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DUTTRIX',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blueGrey600,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  event.name,
                  maxLines: 2,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${event.product} · \$${event.ticketPrice.toStringAsFixed(0)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'TICKET #${ticket.number}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (buyer.isNotEmpty)
                  pw.Text(
                    'Para: $buyer',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  event.pickupPlace,
                  maxLines: 1,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: ticket.qrPayload,
            width: 64,
            height: 64,
          ),
        ],
      ),
    );
  }

  /// Opens the system print / share PDF sheet.
  static Future<void> printTickets({
    required Event event,
    required List<Ticket> tickets,
  }) async {
    final bytes = await build(event: event, tickets: tickets);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'duttrix_${event.name}_tickets',
    );
  }
}
