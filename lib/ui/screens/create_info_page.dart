import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/event_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/core/providers/user_session.dart';
import 'view_message_page.dart';

class CreateInfoPage extends ConsumerStatefulWidget {
  const CreateInfoPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateInfoPage> createState() => _CreateInfoPageState();
}

class _CreateInfoPageState extends ConsumerState<CreateInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      // Hämta repo-provider eller direkt Firestore-instans
      final db = ref.read(firestoreProvider);

      final auth = ref.read(authNotifierProvider);
      final session = ref.read(
        userSessionProvider(auth.currentUser?.uid ?? ''),
      );
      final me = session.uid;
      final name = session.userName;
      final teamId = session.currentTeamId;

      final convRef = await db.collection('messages').add({
        'messageType': 'announcement',
        'teamId': teamId,
        'title': _titleCtrl.text.trim(),
        'participants': [],
        'lastMessage': _textCtrl.text.trim(),
        'lastMessageSender': name,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'readBy': [me],
      });

      await convRef.collection('messages').add({
        'messageType': 'announcement',
        'fromUserId': me,
        'fromUserName': name,
        'text': _textCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [me],
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => ViewMessagePage(
                messageType: 'announcement',
                conversationId: convRef.id,
                toUserIds: null,
                title: _titleCtrl.text.trim(),
              ),
        ),
      );
    } catch (e, st) {
      // Visa ett felmeddelande så användaren förstår vad som hände
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunde inte skicka meddelandet: $e')),
        );
      }
      debugPrint('Fel i _sendInfo: $e\n$st');
    } finally {
      // Oavsett om det gick eller ej, återställ knappen så att användaren kan försöka igen
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skicka informationsmeddelande')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) => (v?.trim().isEmpty ?? true) ? 'Ange en titel' : null,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Innehåll',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                  expands: true,
                  validator:
                      (v) => (v?.trim().isEmpty ?? true) ? 'Ange text' : null,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sending ? null : _sendInfo,
                icon: const Icon(Icons.send),
                label: Text(
                  _sending ? 'Skickar…' : 'Skicka informationsmeddelande',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
