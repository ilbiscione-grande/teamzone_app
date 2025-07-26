// lib/features/home/presentation/widgets/announcement_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- Import
import 'package:teamzone_app/core/providers/firestore_providers.dart';

class AnnouncementCard extends ConsumerWidget {
  // <-- Ändrat
  final Map<String, dynamic> data;
  final String docId;
  final String currentUserId;

  const AnnouncementCard({
    Key? key,
    required this.data,
    required this.docId,
    required this.currentUserId,
  }) : super(key: key);

  factory AnnouncementCard.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    return AnnouncementCard(
      data: doc.data(),
      docId: doc.id,
      currentUserId: currentUserId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // <-- Får in ref
    final db = ref.read(firestoreProvider);

    final subject = data['title'] as String? ?? '';
    final text = data['lastMessage'] as String? ?? '';
    final ts = data['lastMessageTime'] as Timestamp?;
    final date = ts?.toDate() ?? DateTime.now();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rad med datum + stäng-knapp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year} '
                  '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    db.collection('messages').doc(docId).update({
                      'readBy': FieldValue.arrayUnion([currentUserId]),
                    });
                  },
                ),
              ],
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.announcement, color: Colors.red),
              title: Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(text),
            ),
          ],
        ),
      ),
    );
  }
}
