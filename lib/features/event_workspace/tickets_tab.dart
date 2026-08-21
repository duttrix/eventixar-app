import 'package:flutter/material.dart';

import 'organizer_tickets_screen.dart';

/// Organizer ticket hub: manage, sell, share and print tickets.
class TicketsTab extends StatelessWidget {
  const TicketsTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return OrganizerTicketsScreen(eventId: eventId);
  }
}
