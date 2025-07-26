// lib/features/home/new_member_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';

class NewMemberPage extends ConsumerStatefulWidget {
  const NewMemberPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NewMemberPage> createState() => _NewMemberPageState();
}

class _NewMemberPageState extends ConsumerState<NewMemberPage> {
  final _formKey = GlobalKey<FormState>();

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phoneNumber = '';
  String? _role;
  String _userType = '';
  bool _isAdmin = false;
  bool _isLoading = false;
  bool _sendInvite = false;
  bool _isGhost = false;

  @override
  Widget build(BuildContext context) {
    final playerRoles = [
      'Målvakt',
      'Mittback',
      'Ytterback',
      'Mittfältare Central',
      'Mittfältare Ytter',
      'Central Forward',
      'Forward Ytter',
    ];
    final leaderRoles = [
      'Huvudtränare',
      'Tränare',
      'Lagledare',
      'Kontaktperson',
      'Administratör',
    ];
    final parentRoles = ['Förälder', 'Övrigt'];

    List<DropdownMenuItem<String>> _buildRoleItems() {
      final items = <DropdownMenuItem<String>>[];

      items.add(
        const DropdownMenuItem(
          value: 'section_spelare',
          enabled: false,
          child: Text('Spelare', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
      for (var r in playerRoles) {
        items.add(
          DropdownMenuItem(
            value: r,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(r),
            ),
          ),
        );
      }

      items.add(
        const DropdownMenuItem(
          value: 'section_ledare',
          enabled: false,
          child: Text('Ledare', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
      for (var r in leaderRoles) {
        items.add(
          DropdownMenuItem(
            value: r,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(r),
            ),
          ),
        );
      }

      items.add(
        const DropdownMenuItem(
          value: 'section_foralder',
          enabled: false,
          child: Text(
            'Vårdnadshavare',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var r in parentRoles) {
        items.add(
          DropdownMenuItem(
            value: r,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(r),
            ),
          ),
        );
      }

      return items;
    }

    Future<void> _submit() async {
      final db = ref.read(firestoreProvider);

      if (!_formKey.currentState!.validate()) return;
      _formKey.currentState!.save();

      // Hämta auth & session via Riverpod
      final auth = ref.read(authNotifierProvider);
      final session = ref.read(
        userSessionProvider(auth.currentUser?.uid ?? ''),
      );
      final teamId = session.currentTeamId;
      if (teamId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Välj ett team innan du skapar en användare'),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Hämta FCM-token
        final fcmToken = await FirebaseMessaging.instance.getToken() ?? '';

        // Prepare new user doc
        final usersColl = db.collection('users');
        final userDoc = usersColl.doc();
        final now = FieldValue.serverTimestamp();
        final uid = userDoc.id;

        // Bestäm userType
        if (_role == null) return;
        if ([
          'Huvudtränare',
          'Tränare',
          'Lagledare',
          'Kontaktperson',
          'Administratör',
        ].contains(_role)) {
          _userType = 'Ledare';
        } else {
          _userType = 'Spelare';
        }

        // Sätt ihop användardata
        final userData = {
          'clubIds': [session.currentClubId],
          'activated': false,
          'createdAt': now,
          'createdBy': session.uid,
          'currentTeamId': teamId,
          'email': _email.trim(),
          'favouritePosition': '',
          'fcmToken': fcmToken,
          'firstName': _firstName.trim(),
          'lastName': _lastName.trim(),
          'name': '${_firstName.trim()} ${_lastName.trim()}',
          'mainRole': _role,
          'phoneNumber': _phoneNumber.trim(),
          'profilePicture': '',
          'roles': [_role],
          'teamRoles': {
            teamId: [_role],
          },
          'teamIds': [teamId],
          'authUid': '',
          'uid': uid,
          'userType': _userType,
          'isGhost': _isGhost,
        };

        // Spara ny användare
        await userDoc.set(userData);

        // Uppdatera team-dokumentet
        final teamsColl = db.collection('teams');
        await teamsColl.doc(teamId).update({
          'members': FieldValue.arrayUnion([uid]),
          if (_isAdmin) 'teamAdmins': FieldValue.arrayUnion([uid]),
        });

        // Om vi ska skicka inbjudan:
        if (_sendInvite && !_isGhost) {
          final invitesRef = db.collection('invites');
          // Generera inviteCode via doc()
          final inviteDoc = invitesRef.doc();
          final inviteCode = inviteDoc.id;

          // Hämta teamName
          final teamSnap = await teamsColl.doc(teamId).get();
          final teamName = teamSnap.data()?['name'] as String? ?? '';

          // Anropa Cloud Function
          final fn = FirebaseFunctions.instanceFor(
            region: 'us-central1',
          ).httpsCallable('sendInvitationEmail');
          final res = await fn.call(<String, dynamic>{
            'email': _email.trim(),
            'name': '${_firstName.trim()} ${_lastName.trim()}',
            'teamName': teamName,
            'inviteCode': inviteCode,
            'teamId': teamId,
          });

          if ((res.data as Map)['success'] == true) {
            // Kolla existing invite för e-post + team
            final existing =
                await invitesRef
                    .where('email', isEqualTo: _email.trim())
                    .where('teamId', isEqualTo: teamId)
                    .get();

            if (existing.docs.isNotEmpty) {
              // Uppdatera reminderSent
              await invitesRef.doc(existing.docs.first.id).update({
                'reminderSent': FieldValue.serverTimestamp(),
              });
            } else {
              // Skapa ny invite
              await inviteDoc.set({
                'email': _email.trim(),
                'inviteCode': inviteCode,
                'invitedBy': session.uid,
                'teamId': teamId,
                'timestamp': FieldValue.serverTimestamp(),
                'used': false,
                'reminderSent': FieldValue.serverTimestamp(),
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Misslyckades med att skicka inbjudan'),
              ),
            );
          }
        }

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunde inte skapa användare: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ny användare')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                children: [
                  SwitchListTile(
                    title: const Text('Tillfällig användare (gäst)'),
                    subtitle: const Text(
                      'Sparas som "ghost" utan full funktionalitet',
                    ),
                    value: _isGhost,
                    onChanged: (b) => setState(() => _isGhost = b),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Förnamn'),
                    validator: (v) => v!.isEmpty ? 'Fyll i förnamn' : null,
                    onSaved: (v) => _firstName = v!.trim(),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Efternamn'),
                    validator: (v) => v!.isEmpty ? 'Fyll i efternamn' : null,
                    onSaved: (v) => _lastName = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(
                      labelText: 'Roll',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Välj roll'),
                    items: _buildRoleItems(),
                    onChanged: (val) => setState(() => _role = val),
                    validator: (val) => val == null ? 'Välj roll' : null,
                    onSaved: (val) => _role = val!,
                  ),
                  if (!_isGhost) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'E-post'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (_sendInvite && (v == null || v.trim().isEmpty)) {
                          return 'Fyll i e-post för inbjudan';
                        }
                        if (v != null &&
                            v.trim().isNotEmpty &&
                            !v.contains('@')) {
                          return 'Ogiltig e-post';
                        }
                        return null;
                      },
                      onSaved: (v) => _email = v?.trim() ?? '',
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Telefonnummer (valfritt)',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        return digits.length >= 7
                            ? null
                            : 'Ogiltigt telefonnummer';
                      },
                      onSaved: (v) => _phoneNumber = v?.trim() ?? '',
                    ),
                    SwitchListTile(
                      title: const Text('Admin'),
                      value: _isAdmin,
                      onChanged: (b) => setState(() => _isAdmin = b),
                    ),
                    SwitchListTile(
                      title: const Text('Skicka inbjudan direkt'),
                      subtitle: const Text(
                        'Måste ha giltig e-post för att skicka inbjudan',
                      ),
                      value: _sendInvite,
                      onChanged: (b) => setState(() => _sendInvite = b),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                        child: const Text('Avbryt'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(
                          _isLoading ? 'Sparar...' : 'Skapa användare',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
