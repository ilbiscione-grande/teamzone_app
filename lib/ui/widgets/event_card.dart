// lib/features/home/presentation/widgets/event_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ← Import för ConsumerWidget
import 'package:intl/intl.dart';
import '../../core/providers/firestore_providers.dart';

class EventCard extends ConsumerWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final String currentUserId;

  const EventCard({
    Key? key,
    required this.eventId,
    required this.event,
    required this.currentUserId,
  }) : super(key: key);

  /// Skapa från en QueryDocumentSnapshot
  factory EventCard.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    return EventCard(
      eventId: doc.id,
      event: doc.data(),
      currentUserId: currentUserId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Läs rätt Firestore-instans
    final db = ref.watch(firestoreProvider);

    final eventType = event['eventType'] as String? ?? 'Ingen titel';
    final opponent = event['opponent'] as String? ?? '';
    final desc = event['description'] as String? ?? '';
    final area = event['area'] as String? ?? '';
    final pitch = event['pitch'] as String? ?? '';
    final ts = event['eventDate'] as Timestamp;
    final date = ts.toDate();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              eventType == "Match" && opponent.isNotEmpty
                  ? opponent
                  : eventType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              DateFormat("d MMMM HH:mm", "sv_SE").format(date),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pitch.isNotEmpty)
                  Text(pitch)
                else
                  const Text('Ingen plats'),
                if (area.isNotEmpty) Text(', $area') else const SizedBox(),
              ],
            ),
            if (desc.isNotEmpty) ...[const SizedBox(height: 8), Text(desc)],
          ],
        ),

        // Trailing: visa callup-status
        trailing: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              db
                  .collection('callups')
                  .where('eventId', isEqualTo: eventId)
                  .where('memberId', isEqualTo: currentUserId)
                  .limit(1)
                  .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const SizedBox(width: 24);
            }
            final callup = snap.data!.docs.first.data();
            final status = callup['status'] as String? ?? 'invited';
            switch (status) {
              case 'accepted':
                return const Icon(Icons.check_circle, color: Colors.green);
              case 'declined':
                return const Icon(Icons.cancel, color: Colors.red);
              case 'pending':
              default:
                return const Icon(
                  Icons.notifications_active,
                  color: Colors.amber,
                );
            }
          },
        ),
      ),
    );
  }
}
