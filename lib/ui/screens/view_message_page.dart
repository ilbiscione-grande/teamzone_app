// lib/features/home/view_message_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/user_session.dart';

class ViewMessagePage extends ConsumerStatefulWidget {
  final String messageType; // 'dm', 'chat' eller 'announcement'
  final String conversationId; // dokument-ID i /messages
  final List<String>? toUserIds; // för DM: partnerns UID
  final String? title; // titel i AppBar

  const ViewMessagePage({
    Key? key,
    required this.messageType,
    required this.conversationId,
    this.toUserIds,
    required this.title,
  }) : super(key: key);

  @override
  ConsumerState<ViewMessagePage> createState() => _ViewMessagePageState();
}

class _ViewMessagePageState extends ConsumerState<ViewMessagePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Hämta rätt Firestore-instans (region1)
    final db = ref.read(firestoreProvider);

    final auth = ref.read(authNotifierProvider);
    final session = ref.read(userSessionProvider(auth.currentUser?.uid ?? ''));
    final uid = session.uid;
    final userName = session.userName;

    final convRef = db.collection('messages').doc(widget.conversationId);

    await convRef.collection('messages').add({
      'fromUserId': uid,
      'fromUserName': userName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [uid],
    });

    await convRef.update({
      'lastMessage': text,
      'lastMessageSender': userName,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _controller.clear();
    await Future.delayed(const Duration(milliseconds: 100));
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _showChatInfo() {
    final db = ref.read(firestoreProvider);
    final convRef = db.collection('messages').doc(widget.conversationId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).canvasColor,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return SizedBox(
          width: double.infinity,
          height: screenHeight * 0.8,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: convRef.get(),
              builder: (ctx2, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return const Text('Konversation kunde inte laddas.');
                }
                final data = snap.data!.data()!;
                final tsCreated =
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                final createdStr = DateFormat.yMMMd().add_Hm().format(
                  tsCreated,
                );
                final participants = List<String>.from(
                  data['participants'] ?? [],
                );

                return FutureBuilder<
                  List<DocumentSnapshot<Map<String, dynamic>>>
                >(
                  future: Future.wait(
                    participants.map(
                      (id) => db
                          .collection('users')
                          .where('uid', isEqualTo: id)
                          .limit(1)
                          .get()
                          .then((qs) => qs.docs.first),
                    ),
                  ),
                  builder: (ctx3, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = userSnap.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Text(
                          'Chat-information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Startad: $createdStr'),
                        const SizedBox(height: 8),
                        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          future: convRef.collection('messages').get(),
                          builder: (ctx4, msgSnap) {
                            final count = msgSnap.data?.docs.length ?? 0;
                            return Text('Antal meddelanden: $count');
                          },
                        ),
                        const SizedBox(height: 8),
                        Text('Deltagare (${docs.length}):'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (iCtx, i) {
                              final uDoc = docs[i];
                              final uData = uDoc.data() ?? {};
                              final name =
                                  (uData['displayName'] as String?) ??
                                  '${uData['firstName'] ?? ''} ${uData['lastName'] ?? ''}'
                                      .trim() ??
                                  'Okänd';
                              final picUrl = uData['profilePicture'] as String?;
                              return ListTile(
                                leading:
                                    picUrl != null && picUrl.isNotEmpty
                                        ? CircleAvatar(
                                          backgroundImage: NetworkImage(picUrl),
                                        )
                                        : const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                title: Text(name),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Lämna chatten'),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final me = session.uid;

    // Hämta db för listan med meddelanden
    final db = ref.read(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            widget.messageType == 'dm'
                ? FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: db
                      .collection('users')
                      .where(
                        'uid',
                        isEqualTo:
                            auth.currentUser!.uid == widget.toUserIds!.first
                                ? widget.toUserIds![1]
                                : widget.toUserIds![0],
                      )
                      .limit(1)
                      .get()
                      .then((qs) => qs.docs.first),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.done &&
                        snap.hasData) {
                      final u = snap.data!.data()!;
                      final name =
                          (u['displayName'] as String?)?.trim().isNotEmpty ==
                                  true
                              ? u['displayName'] as String
                              : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                                  .trim();
                      return Text('Chatt med $name');
                    }
                    return const Text('Chatt med …');
                  },
                )
                : Text(
                  widget.title?.isNotEmpty == true
                      ? widget.title!
                      : 'Gruppchatt',
                ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Meddelandelista
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  db
                      .collection('messages')
                      .doc(widget.conversationId)
                      .collection('messages')
                      .orderBy('timestamp')
                      .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError)
                  return Center(child: Text('Fel: ${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final msg = docs[i].data();
                    final isMe = msg['fromUserId'] == me;
                    final ts =
                        (msg['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    final timeStr = TimeOfDay.fromDateTime(ts).format(context);

                    // Markera som läst
                    if (!isMe && !(msg['readBy'] as List).contains(me)) {
                      docs[i].reference.update({
                        'readBy': FieldValue.arrayUnion([me]),
                      });
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isMe
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['text'] as String? ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Inmatningsfält + skicka-knapp
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                right: 75,
                top: 4,
                bottom: 4,
                left: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Skriv ett meddelande…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
