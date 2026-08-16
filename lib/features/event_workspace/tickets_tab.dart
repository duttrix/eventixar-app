import 'package:flutter/material.dart';

import 'organizer_sell_screen.dart';

/// Organizer ticket hub: sell / share / print.
class TicketsTab extends StatelessWidget {
  const TicketsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return OrganizerSellScreen(
      eventId: eventId,
      embedded: true,
    );
  }
}
