// lib/features/home/create_group_chat.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'view_message_page.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/user_session.dart';
import '../../core/providers/firestore_providers.dart';

class CreateGroupChatPage extends ConsumerStatefulWidget {
  const CreateGroupChatPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupChatPage> createState() =>
      _CreateGroupChatPageState();
}

class _CreateGroupChatPageState extends ConsumerState<CreateGroupChatPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  List<String> _selected = [];
  bool _creating = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGroupChat() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Välj minst en annan deltagare.')),
      );
      return;
    }

    setState(() => _creating = true);

    final db = ref.read(firestoreProvider);
    final auth = ref.read(authNotifierProvider);
    final session = ref.read(userSessionProvider(auth.currentUser?.uid ?? ''));
    final me = session.uid;

    final participants = [me, ..._selected];

    // Skapa ny konversation i nya databasen
    final convRef = await db.collection('messages').add({
      'messageType': 'chat',
      'title': _titleCtrl.text.trim(),
      'participants': participants,
      'lastMessage': '',
      'lastMessageSender': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'readBy': [me],
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => ViewMessagePage(
              messageType: 'chat',
              conversationId: convRef.id,
              toUserIds: participants,
              title: _titleCtrl.text.trim(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final teamId = session.currentTeamId;
    final me = session.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Ny gruppchatt')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Gruppnamn
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gruppnamn',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        (v?.trim().isEmpty ?? true)
                            ? 'Ange ett gruppnamn'
                            : null,
              ),
            ),
            const SizedBox(height: 16),

            // Välj deltagare
            Expanded(
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future:
                    db
                        .collection('users')
                        .where('teamIds', arrayContains: teamId)
                        .get(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || !snap.hasData) {
                    return const Center(
                      child: Text('Kunde inte ladda medlemmar'),
                    );
                  }
                  final activated =
                      snap.data!.docs.where((d) {
                        return (d.data()['activated'] as bool?) == true;
                      }).toList();
                  if (activated.isEmpty) {
                    return const Center(
                      child: Text('Inga aktiverade medlemmar'),
                    );
                  }

                  return ListView.builder(
                    itemCount: activated.length,
                    itemBuilder: (ctx, i) {
                      final d = activated[i];
                      final data = d.data();
                      final name = data['firstName'] as String? ?? 'Anonym';
                      final docUid = data['uid'] as String? ?? d.id;
                      final isCreator = docUid == me;
                      final checked = isCreator || _selected.contains(docUid);

                      return CheckboxListTile(
                        title: Text(name),
                        value: checked,
                        onChanged:
                            isCreator
                                ? null
                                : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selected.add(docUid);
                                    } else {
                                      _selected.remove(docUid);
                                    }
                                  });
                                },
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary:
                            isCreator
                                ? const Icon(Icons.star, color: Colors.amber)
                                : null,
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Skapa-knapp
            ElevatedButton.icon(
              onPressed: _creating ? null : _createGroupChat,
              icon: const Icon(Icons.group_add),
              label: Text(_creating ? 'Skapar…' : 'Skapa gruppchatt'),
            ),
          ],
        ),
      ),
    );
  }
}
