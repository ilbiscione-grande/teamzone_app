// lib/features/home/presentation/widgets/player_tile.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/ui/screens/player_profile_page.dart';
import 'package:teamzone_app/ui/screens/view_message_page.dart';

class PlayerTile extends ConsumerWidget {
  final String userId;
  final String currentUserId;
  final String teamName;
  final String teamId;
  final Map<String, dynamic> player;

  const PlayerTile({
    Key? key,
    required this.userId,
    required this.currentUserId,
    required this.teamName,
    required this.teamId,
    required this.player,
  }) : super(key: key);

  String _generateInviteCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  String get _conversationId {
    final ids = [currentUserId, userId]..sort();
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firestoreProvider);

    final name = player['name'] as String? ?? 'Namnlös spelare';
    final position = player['position'] as String? ?? '';
    final avatarUrl = player['avatarUrl'] as String?;
    final activated = player['activated'] as bool? ?? false;
    final email = player['email'] as String? ?? '';
    final isSelf = userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          leading: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerProfilePage(userId: userId),
                ),
              );
            },
            child:
                avatarUrl != null && avatarUrl.isNotEmpty
                    ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                    : const CircleAvatar(child: Icon(Icons.person)),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle:
              position.isNotEmpty
                  ? Text(position, style: const TextStyle(color: Colors.grey))
                  : null,
          trailing: _buildActionButton(
            context,
            ref,
            db,
            activated,
            isSelf,
            email,
            name,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerProfilePage(userId: userId),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    FirebaseFirestore db,
    bool activated,
    bool isSelf,
    String email,
    String name,
  ) {
    if (activated && !isSelf) {
      // Open or start DM
      return IconButton(
        icon: const Icon(Icons.message),
        color: Theme.of(context).primaryColor,
        onPressed: () async {
          // 1) Find existing DM
          final snap =
              await db
                  .collection('messages')
                  .where('messageType', isEqualTo: 'dm')
                  .where('participants', arrayContains: currentUserId)
                  .get();

          QueryDocumentSnapshot<Map<String, dynamic>>? existing;
          for (var doc in snap.docs) {
            final parts = List<String>.from(doc.data()['participants']);
            if (parts.contains(userId)) {
              existing = doc;
              break;
            }
          }

          // 2) Create if none
          final docRef =
              existing?.reference ??
              await db.collection('messages').add({
                'messageType': 'dm',
                'participants': [currentUserId, userId],
                'createdAt': FieldValue.serverTimestamp(),
              });

          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ViewMessagePage(
                    messageType: 'dm',
                    conversationId: docRef.id,
                    toUserIds: [currentUserId, userId],
                    title: name,
                  ),
            ),
          );
        },
      );
    }

    if (!activated && email.isNotEmpty && !isSelf) {
      // Send invite email
      return IconButton(
        icon: const Icon(Icons.email_outlined),
        color: Theme.of(context).colorScheme.secondary,
        onPressed: () async {
          final invitesRef = db.collection('invites');
          final today = DateTime.now();
          bool canSend = true;
          String inviteCode = _generateInviteCode(6);

          final existing =
              await invitesRef.where('email', isEqualTo: email).limit(1).get();
          if (existing.docs.isNotEmpty) {
            final data = existing.docs.first.data();
            final lastReminder = (data['reminderSent'] as Timestamp?)?.toDate();
            if (lastReminder != null &&
                lastReminder.year == today.year &&
                lastReminder.month == today.month &&
                lastReminder.day == today.day) {
              canSend = false;
            } else {
              inviteCode = data['inviteCode'] as String;
            }
          }

          if (!canSend) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Påminnelse har redan skickats idag.'),
              ),
            );
            return;
          }

          try {
            final fn = FirebaseFunctions.instanceFor(
              region: 'us-central1',
            ).httpsCallable('sendInvitationEmail');
            final res = await fn.call(<String, dynamic>{
              'email': email,
              'name': name,
              'teamName': teamName,
              'inviteCode': inviteCode,
              'teamId': teamId,
            });

            if ((res.data as Map)['success'] == true) {
              if (existing.docs.isNotEmpty) {
                await invitesRef.doc(existing.docs.first.id).update({
                  'reminderSent': Timestamp.now(),
                });
              } else {
                await invitesRef.add({
                  'email': email,
                  'inviteCode': inviteCode,
                  'invitedBy': currentUserId,
                  'inviteType': 'invite',
                  'invitedAt' : Timestamp.now(),
                  'teamId': teamId,
                  'timestamp': Timestamp.now(),
                  'used': false,
                  'reminderSent': Timestamp.now(),
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Inbjudan skickad till $email')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Fel: $e')));
          }
        },
      );
    }

    // Otherwise lock icon / nothing
    return const Icon(Icons.lock, color: Colors.grey);
  }
}
