import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen QR scanner. Pops with the raw scanned string.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.title = 'Escanear QR'});

  final String title;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: const Text(
                'Apuntá al QR del ticket. También podés volver e ingresar el número a mano.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses a scanned value into a ticket number and optional ids.
class ScannedTicketRef {
  const ScannedTicketRef({
    this.eventId,
    this.ticketId,
    this.number,
  });

  final String? eventId;
  final String? ticketId;
  final int? number;

  /// Accepts:
  /// - `evx:{eventId}:{ticketId}` (QR printed on the ticket image)
  /// - plain ticket number (`18`)
  /// - legacy URL / scheme forms for older tickets
  static ScannedTicketRef? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final asNumber = int.tryParse(value);
    if (asNumber != null) return ScannedTicketRef(number: asNumber);

    if (value.startsWith('evx:')) {
      final parts = value.split(':');
      if (parts.length >= 3 && parts[1].isNotEmpty && parts[2].isNotEmpty) {
        return ScannedTicketRef(eventId: parts[1], ticketId: parts[2]);
      }
    }

    Uri? uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return null;
    }

    final segments = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    final ticketIndex = segments.indexOf('ticket');
    if (ticketIndex >= 0 && segments.length >= ticketIndex + 3) {
      return ScannedTicketRef(
        eventId: segments[ticketIndex + 1],
        ticketId: segments[ticketIndex + 2],
      );
    }

    return null;
  }
}
