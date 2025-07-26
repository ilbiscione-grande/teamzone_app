// lib/features/home/messages_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/core/providers/user_session.dart';
import 'package:teamzone_app/ui/screens/create_group_chat.dart';
import 'package:teamzone_app/ui/screens/create_info_page.dart';
import 'package:teamzone_app/ui/screens/view_message_page.dart';
import 'package:teamzone_app/ui/widgets/messages_list.dart';

class MessagesTab extends ConsumerStatefulWidget {
  const MessagesTab({Key? key}) : super(key: key);

  @override
  ConsumerState<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends ConsumerState<MessagesTab> {
  late final UserSession _session;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // Hämta session och admin-flagga efter första build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authNotifierProvider);
      _session = ref.read(userSessionProvider(auth.currentUser?.uid ?? ''));
      setState(() {
        _isAdmin = _session.isAdmin;
      });
    });
  }

  void _openNewChatModal() {
    final db = ref.read(firestoreProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            builder: (ctx, scrollCtrl) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skriv meddelande',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1) Informationsmeddelande (endast för admins)
                    if (_session.isAdmin)
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Skicka informationsmeddelande'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateInfoPage(),
                            ),
                          );
                        },
                      ),

                    // 2) Gruppchatt
                    ListTile(
                      leading: const Icon(Icons.group_add),
                      title: const Text('Starta ny gruppchatt'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupChatPage(),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    // 3) Direktmeddelande
                    Expanded(
                      child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        future:
                            db
                                .collection('users')
                                .where(
                                  'teamIds',
                                  arrayContains: _session.currentTeamId,
                                )
                                .get(),
                        builder: (ctx2, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasError || !snap.hasData) {
                            return const Center(
                              child: Text('Kunde inte ladda medlemmar'),
                            );
                          }

                          // 1) Filtrera bort dig själv
                          final allMembers =
                              snap.data!.docs
                                  .where((d) => d.data()['uid'] != _session.uid)
                                  .toList();

                          // 2) Dela upp i aktiverade / inaktiva
                          final activatedMembers =
                              allMembers
                                  .where(
                                    (d) =>
                                        d.data()['activated'] as bool? ?? false,
                                  )
                                  .toList();
                          final inactiveMembers =
                              allMembers
                                  .where(
                                    (d) =>
                                        !(d.data()['activated'] as bool? ??
                                            false),
                                  )
                                  .toList();

                          // 3) Slå ihop så att aktiverade först
                          final sortedMembers =
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[
                                ...activatedMembers,
                                ...inactiveMembers,
                              ];

                          if (sortedMembers.isEmpty) {
                            return const Center(
                              child: Text('Inga andra lagmedlemmar.'),
                            );
                          }

                          return ListView.builder(
                            controller: scrollCtrl,
                            itemCount: sortedMembers.length,
                            itemBuilder: (ctx3, i) {
                              final data = sortedMembers[i].data();
                              final uid = data['uid'] as String;
                              final activated =
                                  data['activated'] as bool? ?? false;
                              final name =
                                  (data['displayName'] as String?)?.trim() ??
                                  '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                                      .trim();
                              final pic = data['profilePicture'] as String?;

                              return ListTile(
                                enabled: activated,
                                leading:
                                    pic != null && pic.startsWith('http')
                                        ? CircleAvatar(
                                          backgroundImage: NetworkImage(pic),
                                        )
                                        : CircleAvatar(
                                          child: Text(
                                            name.isNotEmpty ? name[0] : '?',
                                          ),
                                        ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: activated ? null : Colors.grey,
                                  ),
                                ),
                                onTap:
                                    activated
                                        ? () {
                                          Navigator.pop(context);
                                          _startOrOpenDm(uid, name);
                                        }
                                        : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Future<void> _startOrOpenDm(String partnerId, String partnerName) async {
    final me = _session.uid;
    final db = ref.read(firestoreProvider);
    final coll = db.collection('messages');

    // 1) Hitta befintlig DM
    final snap =
        await coll
            .where('messageType', isEqualTo: 'dm')
            .where('participants', arrayContains: me)
            .get();
    QueryDocumentSnapshot<Map<String, dynamic>>? existing;
    for (var d in snap.docs) {
      final parts = List<String>.from(d.data()['participants'] ?? []);
      if (parts.contains(partnerId)) {
        existing = d;
        break;
      }
    }

    // 2) Skapa om den inte finns
    final docRef =
        existing?.reference ??
        await coll.add({
          'messageType': 'dm',
          'participants': [me, partnerId],
          'title': partnerName,
          'lastMessage': '',
          'lastMessageSender': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'readBy': [],
        });

    // 3) Navigera in i chatten
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ViewMessagePage(
              messageType: 'dm',
              conversationId: docRef.id,
              toUserIds: [partnerId],
              title: partnerName,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meddelanden'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment),
              tooltip: 'Skicka meddelande',
              onPressed: _openNewChatModal,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'DM'),
              Tab(text: 'Gruppchattar'),
              Tab(text: 'Information'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MessagesList(messageType: 'dm'),
            MessagesList(messageType: 'chat'),
            MessagesList(messageType: 'announcement'),
          ],
        ),
      ),
    );
  }
}
