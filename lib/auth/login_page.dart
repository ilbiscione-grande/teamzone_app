// lib/features/auth/presentation/login_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/widgets/main_scaffold.dart';
import 'package:teamzone_app/auth/register_page.dart';
import '../../core/providers/firestore_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Lyssna på token-uppdateringar (t.ex. efter ominstallation)
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      registerTokenForCurrentUser();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Flyttar dagens device-token till aktuell inloggad användare.
  Future<void> registerTokenForCurrentUser() async {
    final messaging = FirebaseMessaging.instance;
    final firestore = ref.read(firestoreProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('▶ registerToken, uid=$uid');
    if (uid == null) return;

    final token = await messaging.getToken();
    debugPrint('▶ Got FCM token: $token');
    if (token == null) return;

    try {
      // ENKEL uppdatering (skippa batch för test)
      await firestore.collection('users').doc(uid).update({'fcmToken': token});
      debugPrint('✅ Token sparad');
    } catch (e, st) {
      debugPrint('❌ Kunde inte spara token: $e\n$st');
    }
  }

  Future<void> handleLogin() async {
    setState(() => isLoading = true);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // Validera e-postformat
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      showError('Ange en giltig e-postadress.');
      setState(() => isLoading = false);
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      showError('E-post och lösenord krävs.');
      setState(() => isLoading = false);
      return;
    }

    try {
      final db = ref.read(firestoreProvider);
      final auth = FirebaseAuth.instance;

      // 1) Kolla om användare finns i Firestore
      final userQuery =
          await db.collection('users').where('email', isEqualTo: email).get();

      if (userQuery.docs.isEmpty) {
        final create = await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: const Text('Ingen användare hittades'),
                content: const Text(
                  'Vill du skapa en ny användare och ett nytt lag med denna e-post?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Avbryt'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Skapa'),
                  ),
                ],
              ),
        );
        if (create == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterPage(email: email, password: password),
            ),
          );
        }
        return;
      }

      final userData = userQuery.docs.first.data();
      final activated = userData['activated'] == true;

      if (activated) {
        // Aktiv användare: vanlig inloggning
        await auth.signInWithEmailAndPassword(email: email, password: password);
        // Flytta device-token till denna användare
        await registerTokenForCurrentUser();
      } else {
        // Ej aktiverad: kolla invites
        final inviteQuery =
            await db
                .collection('invites')
                .where('email', isEqualTo: email)
                .get();

        if (inviteQuery.docs.isEmpty) {
          // Inga invites — erbjud join_request
          final userId = userQuery.docs.first.id;
          final teamId = userQuery.docs.first['teamIds']?[0] as String?;
          if (teamId != null) {
            final existingRequest =
                await db
                    .collection('join_requests')
                    .where('email', isEqualTo: email)
                    .where('teamId', isEqualTo: teamId)
                    .where('status', isEqualTo: 'pending')
                    .limit(1)
                    .get();
            if (existingRequest.docs.isNotEmpty) {
              await showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Förfrågan redan skickad'),
                      content: const Text(
                        'Du har redan skickat en förfrågan om att gå med i ett lag. '
                        'Vänligen invänta svar från lagets administratör.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            } else {
              await showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Ingen inbjudan hittades'),
                      content: const Text(
                        'Denna e-post är redan registrerad, men saknar en aktiv inbjudan. '
                        'Du kan skicka en förfrågan till lagets administratör om att få gå med i laget.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await db.collection('join_requests').add({
                              'userId': userId,
                              'email': email,
                              'teamId': teamId,
                              'namn': userData['namn'],
                              'status': 'pending',
                              'requestedAt': Timestamp.now(),
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Förfrågan skickad till lagets administratör.',
                                ),
                              ),
                            );
                          },
                          child: const Text('Skicka förfrågan'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Avbryt'),
                        ),
                      ],
                    ),
              );
            }
          } else {
            showError('Ingen koppling till lag hittades.');
          }
          setState(() => isLoading = false);
          return;
        }

        // Finn inviteCode i password-fältet
        final matching = inviteQuery.docs.any(
          (doc) => doc.data()['inviteCode'] == password,
        );
        if (!matching) {
          showError('Felaktig inbjudningskod.');
          setState(() => isLoading = false);
          return;
        }
        // Ta bort använda invites
        for (var doc in inviteQuery.docs) {
          if (doc.data()['inviteCode'] == password) {
            await db.collection('invites').doc(doc.id).delete();
          }
        }
        // Logga in användaren ändå
        await auth.signInWithEmailAndPassword(email: email, password: password);
        // Flytta device-token till denna användare
        await registerTokenForCurrentUser();
        await db.collection('users').doc(userQuery.docs.first.id).update({
          'activated': true,
        });
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
        (route) => false,
      );
    } on FirebaseAuthException {
      showError('Fel e-post eller lösenord.');
    } catch (e) {
      showError('Login error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 193, 225, 243),
                Color.fromARGB(255, 240, 250, 255),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: [0.0, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        Image.asset(
                          'assets/football_intro_noBg.png',
                          width: MediaQuery.of(context).size.width * 0.7,
                        ),
                        const SizedBox(height: 30),

                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: const Text(
                            'Här loggar du in till ditt lag med mail och lösenord. Om du inte redan har ett konto eller har fått en inbjudan från något lag så skapas ett nytt automatiskt. ',
                          ),
                        ),
                        TextField(
                          controller: emailController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'E-post',
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            labelText: 'Lösenord eller inbjudningskod',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: handleLogin,
                          child: const Text('Fortsätt'),
                        ),
                        SizedBox(height: 300),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
