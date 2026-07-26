import 'package:flutter_test/flutter_test.dart';

import 'package:eventixar/core/router/deep_link_mapper.dart';
import 'package:eventixar/shared/widgets/qr_scan_screen.dart';

void main() {
  group('DeepLinkMapper', () {
    test('maps https and custom-scheme join urls', () {
      expect(
        DeepLinkMapper.locationFromUri(
          Uri.parse('https://app.eventixar.com/join/abc123'),
        ),
        '/join/abc123',
      );
      expect(
        DeepLinkMapper.locationFromUri(
          Uri.parse('https://eventixar.web.app/join/abc123'),
        ),
        '/join/abc123',
      );
      expect(
        DeepLinkMapper.locationFromUri(Uri.parse('eventixar://join/tok')),
        '/join/tok',
      );
      expect(
        DeepLinkMapper.locationFromUri(
          Uri.parse('eventixar://join/QO-OT5wX5xYt9Oym71bugY9P_RMmlkHu'),
        ),
        '/join/QO-OT5wX5xYt9Oym71bugY9P_RMmlkHu',
      );
    });

    test('does not open ticket urls (buyers get images, not a screen)', () {
      expect(
        DeepLinkMapper.locationFromUri(
          Uri.parse('https://app.eventixar.com/ticket/ev1/t_18'),
        ),
        isNull,
      );
      expect(
        DeepLinkMapper.locationFromUri(
          Uri.parse('eventixar://ticket/ev1/t_3'),
        ),
        isNull,
      );
    });

    test('ignores unknown hosts', () {
      expect(
        DeepLinkMapper.locationFromUri(Uri.parse('https://evil.com/join/x')),
        isNull,
      );
    });
  });

  group('ScannedTicketRef', () {
    test('parses plain number and qr payload', () {
      expect(ScannedTicketRef.parse('18')?.number, 18);
      final fromQr = ScannedTicketRef.parse('evx:ev1:t_18');
      expect(fromQr?.eventId, 'ev1');
      expect(fromQr?.ticketId, 't_18');
    });

    test('still parses legacy ticket urls for old images', () {
      final fromUrl = ScannedTicketRef.parse(
        'https://app.eventixar.com/ticket/ev1/t_18',
      );
      expect(fromUrl?.eventId, 'ev1');
      expect(fromUrl?.ticketId, 't_18');
    });
  });
}
