// lib/features/home/messages_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../screens/view_message_page.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/user_session.dart';
import '../../core/providers/firestore_providers.dart'; // ← Lägg till denna

class MessagesList extends ConsumerWidget {
  final String messageType; // "dm", "chat" or "announcement"

  const MessagesList({Key? key, required this.messageType}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final uid = session.uid;
    final teamId = session.currentTeamId;

    // Bas‐query
    Query<Map<String, dynamic>> query = db
        .collection('messages')
        .where('messageType', isEqualTo: messageType)
        .orderBy('lastMessageTime', descending: true);

    if (messageType != 'announcement') {
      query = query.where('participants', arrayContains: uid);
    } else {
      query = query.where('teamId', isEqualTo: teamId);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('Fel: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text('Inga konversationer här.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data();

            final lastMsg = data['lastMessage'] as String? ?? '';
            final lastSender = data['lastMessageSender'] as String? ?? '';
            final lastTime =
                (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                DateTime.now();

            final readBy = List<String>.from(data['readBy'] ?? []);
            final unread = !readBy.contains(uid);
            final titleStyle = TextStyle(
              fontWeight: unread ? FontWeight.bold : FontWeight.normal,
            );
            final subtitleStyle = TextStyle(
              fontWeight: unread ? FontWeight.bold : FontWeight.normal,
            );

            // Title‐widget
            Widget titleWidget;
            if (messageType == 'dm') {
              final parts = List<String>.from(data['participants'] ?? []);
              final partnerId = parts.firstWhere(
                (id) => id != uid,
                orElse: () => '',
              );
              if (partnerId.isEmpty) {
                titleWidget = Text('Privatchatt', style: titleStyle);
              } else {
                titleWidget = FutureBuilder<
                  QuerySnapshot<Map<String, dynamic>>
                >(
                  future:
                      db
                          .collection('users')
                          .where('uid', isEqualTo: partnerId)
                          .limit(1)
                          .get(),
                  builder: (c, snap2) {
                    if (snap2.connectionState == ConnectionState.waiting) {
                      return Text('Laddar…', style: titleStyle);
                    }
                    if (snap2.hasError || snap2.data!.docs.isEmpty) {
                      return Text('Okänd', style: titleStyle);
                    }
                    final u = snap2.data!.docs.first.data();
                    final displayName =
                        (u['displayName'] as String?)?.trim().isNotEmpty == true
                            ? u['displayName'] as String
                            : '${(u['firstName'] ?? '')} ${(u['lastName'] ?? '')}'
                                .trim();
                    return Text(displayName, style: titleStyle);
                  },
                );
              }
            } else {
              final raw = data['title'] as String?;
              final fallback =
                  messageType == 'announcement' ? 'Info' : 'Gruppchatt';
              final t = (raw?.trim().isNotEmpty == true) ? raw! : fallback;
              titleWidget = Text(t, style: titleStyle);
            }

            // Leading‐ikon
            Widget leading;
            if (messageType == 'announcement') {
              leading = const Icon(Icons.announcement);
            } else if (messageType == 'dm') {
              final parts = List<String>.from(data['participants'] ?? []);
              final partnerId = parts.firstWhere(
                (id) => id != uid,
                orElse: () => '',
              );
              leading = FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future:
                    db
                        .collection('users')
                        .where('uid', isEqualTo: partnerId)
                        .limit(1)
                        .get(),
                builder: (c, uSnap) {
                  if (uSnap.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (uSnap.hasError || uSnap.data!.docs.isEmpty) {
                    return const CircleAvatar(child: Icon(Icons.person));
                  }
                  final u = uSnap.data!.docs.first.data();
                  final pic = u['profilePicture'] as String?;
                  if (pic != null && pic.startsWith('http')) {
                    return CircleAvatar(backgroundImage: NetworkImage(pic));
                  }
                  final initials = ((u['displayName'] as String?) ?? '?')
                      .substring(0, 1);
                  return CircleAvatar(child: Text(initials));
                },
              );
            } else {
              final grp = (data['title'] as String?) ?? 'G';
              leading = CircleAvatar(child: Text(grp[0]));
            }

            return ListTile(
              leading: leading,
              title: titleWidget,
              subtitle: Text(
                lastSender.isNotEmpty ? '$lastSender: $lastMsg' : lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
              trailing: _buildTimestamp(lastTime),
              onTap: () {
                db.collection('messages').doc(doc.id).update({
                  'readBy': FieldValue.arrayUnion([uid]),
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ViewMessagePage(
                          messageType: messageType,
                          conversationId: doc.id,
                          toUserIds: List<String>.from(
                            data['participants'] ?? [],
                          ),
                          title:
                              messageType == 'dm'
                                  ? null
                                  : data['title'] as String?,
                        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Hjälpfunktion som formaterar tidsstämpeln enligt:
  /// • Idag: bara klockslag
  /// • Igår: “Igår” över klockslag
  /// • Äldre: datum “d/M” över klockslag
  Widget _buildTimestamp(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(ts.year, ts.month, ts.day);
    String? label;

    if (msgDay == today) {
      label = null;
    } else if (msgDay == today.subtract(const Duration(days: 1))) {
      label = 'Igår';
    } else {
      label = DateFormat('d MMM').format(ts);
    }

    final timeOnly = DateFormat.Hm('sv_SE').format(ts);
    final style = const TextStyle(fontSize: 10, color: Colors.black);

    if (label == null) {
      return Text(timeOnly, style: style);
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label, style: style), Text(timeOnly, style: style)],
      );
    }
  }
}
