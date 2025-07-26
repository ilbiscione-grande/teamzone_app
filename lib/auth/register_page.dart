// lib/auth/presentation/register_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/widgets/main_scaffold.dart';
import '../../core/providers/firestore_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  final String email;
  final String password;
  const RegisterPage({super.key, required this.email, required this.password});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool isLoading = false;
  String? _fcmToken;

  // Step controllers and error flags
  final clubController = TextEditingController();
  final teamNameController = TextEditingController();
  bool clubError = false;
  bool teamError = false;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  String? role;
  bool firstNameError = false;
  bool lastNameError = false;
  bool roleError = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initFCM();
  }

  @override
  void dispose() {
    _pageController.dispose();
    clubController.dispose();
    teamNameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  // 3. Hämta token och lyssna på uppdateringar
  Future<void> _initFCM() async {
    // (iOS) be om tillstånd
    await FirebaseMessaging.instance.requestPermission();

    // hämta initial token
    _fcmToken = await FirebaseMessaging.instance.getToken();

    // lyssna på token-refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      setState(() => _fcmToken = newToken);
      // direkt uppdatera Firestore om användaren redan finns
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final db = ref.read(firestoreProvider);
        db.collection('users').doc(user.uid).update({'fcmToken': newToken});
      }
    });
  }

  void _nextPage() async {
    setState(() {
      clubError = false;
      teamError = false;
      firstNameError = false;
      lastNameError = false;
      roleError = false;
    });

    if (_currentPage == 0) {
      if (clubController.text.trim().isEmpty) clubError = true;
      if (teamNameController.text.trim().isEmpty) teamError = true;
      if (clubError || teamError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vänligen fyll i klubb och lagnamn.')),
        );
        return;
      }
    }

    if (_currentPage == 1) {
      if (firstNameController.text.trim().isEmpty) firstNameError = true;
      if (lastNameController.text.trim().isEmpty) lastNameError = true;
      if (role == null) roleError = true;
      if (firstNameError || lastNameError || roleError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vänligen fyll i personuppgifter.')),
        );
        return;
      }
    }

    if (_currentPage == 2) {
      _finalizeRegistration();
      return;
    }

    setState(() => _currentPage++);
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _finalizeRegistration() async {
    setState(() => isLoading = true);

    final db = ref.read(firestoreProvider);
    final auth = FirebaseAuth.instance;

    try {
      var user = auth.currentUser;
      if (user == null) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
        user = credential.user;
      }

      if (user == null) throw Exception("Ingen användare");
      // 1) Klubb
      final clubName = clubController.text.trim();
      final teamName = teamNameController.text.trim();

      // 2) Hämta/skap klubb
      final clubQuery =
          await db
              .collection('clubs')
              .where('clubNameLower', isEqualTo: clubName.toLowerCase())
              .limit(1)
              .get();
      DocumentReference<Map<String, dynamic>> clubRef;
      if (clubQuery.docs.isNotEmpty) {
        // befintlig klubb
        clubRef = clubQuery.docs.first.reference;
        final createdBy = clubQuery.docs.first.data()['createdBy'] as String;
        if (createdBy != user.uid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ingen behörighet på befintlig klubb.'),
            ),
          );
          return;
        }
      } else {
        // skapa ny klubb
        clubRef = await db.collection('clubs').add({
          'clubName': clubName,
          'clubNameLower': clubName.toLowerCase(),
          'createdBy': user.uid,
          'members': [user.uid],
          'teams': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3) Skapa team
      final teamRef = await db.collection('teams').add({
        'teamName': teamName,
        'clubName': clubName,
        'members': [user.uid],
        'createdBy': user.uid,
        'teamAdmins': [user.uid],
        'teamPhoto': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4) Uppdatera klubb med team & medlem
      await clubRef.update({
        'teams': FieldValue.arrayUnion([teamRef.id]),
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // 5) Bestäm userType från role
      final userType =
          <String>{
                'Huvudtränare',
                'Tränare',
                'Lagledare',
                'Kontaktperson',
                'Administratör',
              }.contains(role)
              ? 'Ledare'
              : 'Spelare';

      // 6) Spara user‐doc
      await db.collection('users').doc(user.uid).set({
        'email': widget.email,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'name':
            '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
        'mainRole': role,
        'roles': [role],
        'currentTeamId': teamRef.id,
        'favouritePosition': '',
        'fcmToken': _fcmToken ?? '',
        'phoneNumber': '',
        'profilePicture': '',
        'teamIds': [teamRef.id],
        'uid': user.uid,
        'userType': userType,
        'activated': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 7) Hoppa till bekräftelses‐sida
      setState(() => _currentPage = 3);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            3,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registrering misslyckades: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrera nytt konto'),
        leading:
            _currentPage > 0
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _previousPage,
                )
                : null,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Steg 1: Klubb + Lagnamn
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FutureBuilder<QuerySnapshot>(
                          future:
                              db
                                  .collection('clubs')
                                  .orderBy('clubNameLower')
                                  .get(),
                          builder: (ctx, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final clubs =
                                snap.data!.docs
                                    .map((d) => d['clubName'] as String)
                                    .toList();
                            return DropdownButtonFormField<String>(
                              value:
                                  clubs.contains(clubController.text)
                                      ? clubController.text
                                      : null,
                              hint: const Text('Välj klubb'),
                              decoration: InputDecoration(
                                labelText: 'Klubb',
                                errorText: clubError ? 'Obligatoriskt' : null,
                                border: const OutlineInputBorder(),
                              ),
                              items:
                                  clubs
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (String? val) {
                                if (val != null) {
                                  setState(() => clubController.text = val);
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: clubController,
                          decoration: InputDecoration(
                            labelText: 'Klubb',
                            errorText: clubError ? 'Obligatoriskt' : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: teamNameController,
                          decoration: InputDecoration(
                            labelText: 'Lagnamn',
                            errorText: teamError ? 'Obligatoriskt' : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _nextPage,
                          child: const Text('Nästa'),
                        ),
                      ],
                    ),
                  ),
                  // Steg 2: Personuppgifter + Rolle
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: firstNameController,
                          decoration: InputDecoration(
                            labelText: 'Förnamn',
                            errorText: firstNameError ? 'Obligatoriskt' : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Efternamn',
                            errorText: lastNameError ? 'Obligatoriskt' : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          value: role,
                          hint: const Text('Välj roll'),
                          decoration: InputDecoration(
                            labelText: 'Roll',
                            errorText: roleError ? 'Obligatoriskt' : null,
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<String?>(
                              enabled: false,
                              value: null,
                              child: Text(
                                'Ledare',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Huvudtränare',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Huvudtränare'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Tränare',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Tränare'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Lagledare',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Lagledare'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Kontaktperson',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Kontaktperson'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Administratör',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Administratör'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              enabled: false,
                              value: null,
                              child: Text(
                                'Spelare',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Målvakt',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Målvakt'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Mittback',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Mittback'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Ytterback',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Ytterback'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Mittfältare Central',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Mittfältare Central'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Mittfältare Ytter',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Mittfältare Ytter'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Central Forward Central',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Central Forward Central'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Forward Ytter',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Forward Ytter'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              enabled: false,
                              value: null,
                              child: Text(
                                'Vårdnadshavare',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Förälder',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Förälder'),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Övrigt',
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Övrigt'),
                              ),
                            ),
                          ],
                          onChanged: (String? val) {
                            if (val != null) setState(() => role = val);
                          },
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _nextPage,
                          child: const Text('Nästa'),
                        ),
                      ],
                    ),
                  ),
                  // Steg 3: Sammanfattning
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Klubb: ${clubController.text}'),
                        Text('Lag: ${teamNameController.text}'),
                        Text(
                          'Namn: ${firstNameController.text} ${lastNameController.text}',
                        ),
                        Text('Roll: $role'),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _nextPage,
                          child: const Text('Slutför'),
                        ),
                      ],
                    ),
                  ),
                  // Steg 4: Färdig
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        const Text('Grattis, ditt konto är skapat!'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MainScaffold(),
                              ),
                              (route) => false,
                            );
                          },
                          child: const Text('Till startsidan'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
