// lib/features/home/presentation/widgets/handle_invite_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/main_scaffold.dart';
import '../../core/providers/firestore_providers.dart';

class HandleInvitePage extends ConsumerStatefulWidget {
  final String inviteCode;
  const HandleInvitePage({Key? key, required this.inviteCode})
    : super(key: key);

  @override
  ConsumerState<HandleInvitePage> createState() => _HandleInvitePageState();
}

class _HandleInvitePageState extends ConsumerState<HandleInvitePage> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _email;
  String? _teamId;
  DocumentReference<Map<String, dynamic>>? _inviteRef;

  @override
  void initState() {
    super.initState();
    _validateInviteCode();
  }

  Future<void> _validateInviteCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final db = ref.read(firestoreProvider);
    try {
      final query =
          await db
              .collection('invites')
              .where('inviteCode', isEqualTo: widget.inviteCode)
              .where('used', isEqualTo: false)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        setState(() => _error = 'Ogiltig eller redan använd kod.');
      } else {
        final invite = query.docs.first;
        setState(() {
          _email = invite.data()['email'] as String?;
          _teamId = invite.data()['teamId'] as String?;
          _inviteRef = invite.reference;
        });
      }
    } catch (e) {
      setState(() => _error = 'Fel vid kontroll av inbjudan: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createAccount() async {
    if (_email == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final db = ref.read(firestoreProvider);
    final auth = fbAuth.FirebaseAuth.instance;
    final pwd = _passwordController.text.trim();

    if (pwd.length < 6) {
      setState(() {
        _loading = false;
        _error = 'Lösenordet måste vara minst 6 tecken.';
      });
      return;
    }

    try {
      fbAuth.UserCredential cred;
      try {
        cred = await auth.createUserWithEmailAndPassword(
          email: _email!,
          password: pwd,
        );
      } on fbAuth.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cred = await auth.signInWithEmailAndPassword(
            email: _email!,
            password: pwd,
          );
        } else {
          rethrow;
        }
      }

      final user = cred.user!;
      final fcmToken = await FirebaseMessaging.instance.getToken();

      // 1) Punkt A: flytta/skriv över alla fält från gammalt doc (om det finns)
      final oldQuery =
          await db
              .collection('users')
              .where('email', isEqualTo: _email)
              .limit(1)
              .get();
      if (oldQuery.docs.isNotEmpty) {
        final oldData = oldQuery.docs.first.data();
        // Sätt (merge: true) så vi behåller befintliga fält
        await db
            .collection('users')
            .doc(user.uid)
            .set(oldData, SetOptions(merge: true));
        // Radera gamla dokumentet
        await oldQuery.docs.first.reference.delete();
      }

      // 2) Punkt B: skriv de uppdaterade fälten under users/{authUid}
      final userDoc = db.collection('users').doc(user.uid);
      await userDoc.set({
        'uid': user.uid,
        'teamIds': FieldValue.arrayUnion([_teamId]),
        'currentTeamId': _teamId,
        'activated': true,
        if (fcmToken != null) 'fcmToken': fcmToken,
      }, SetOptions(merge: true));

      // 3) Markera invite som använd
      await _inviteRef?.update({'used': true});

      // 4) Navigera in i appen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    } catch (e) {
      setState(() => _error = 'Fel: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbjudan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              _loading
                  ? const CircularProgressIndicator()
                  : _email == null
                  ? Text(_error ?? 'Laddar…')
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Inbjudan bekräftad!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('E-post: $_email'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Välj lösenord',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _createAccount,
                        child: const Text('Skapa konto och gå vidare'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
        ),
      ),
    );
  }
}
