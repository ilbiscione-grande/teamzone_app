// lib/features/home/new_team_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/user_session.dart';
import '../../core/providers/firestore_providers.dart';

class NewTeamPage extends ConsumerStatefulWidget {
  const NewTeamPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NewTeamPage> createState() => _NewTeamPageState();
}

class _NewTeamPageState extends ConsumerState<NewTeamPage> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameCtrl = TextEditingController();
  final _newClubNameCtrl = TextEditingController();
  bool _isSaving = false;

  List<String> _allClubs = [];
  Set<String> _adminClubs = {};
  String? _selectedClub;
  bool _loadingClubs = true;

  @override
  void initState() {
    super.initState();
    _fetchClubs();
  }

  Future<void> _fetchClubs() async {
    final db = ref.read(firestoreProvider);
    final uid = ref.read(authNotifierProvider).currentUser!.uid;

    // Hämta alla klubbar
    final allSnap = await db.collection('clubs').get();
    final allNames =
        allSnap.docs.map((d) => d.data()['clubName'] as String).toList()
          ..sort();

    // Klubbar där användaren är admin eller owner
    final adminSnap =
        await db
            .collection('clubs')
            .where('clubAdmins', arrayContains: uid)
            .get();
    final ownerSnap =
        await db
            .collection('clubs')
            .where('clubOwners', arrayContains: uid)
            .get();

    final adminSet = <String>{};
    for (var doc in [...adminSnap.docs, ...ownerSnap.docs]) {
      adminSet.add(doc.data()['clubName'] as String);
    }

    setState(() {
      _allClubs = allNames;
      _adminClubs = adminSet;
      _loadingClubs = false;
    });
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _newClubNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final db = ref.read(firestoreProvider);
    final uid = ref.read(authNotifierProvider).currentUser!.uid;
    String clubName;
    String clubId;

    if (_selectedClub == 'new') {
      // Skapa ny klubb
      final newRef = await db.collection('clubs').add({
        'clubName': _newClubNameCtrl.text.trim(),
        'clubNameLower': _newClubNameCtrl.text.trim().toLowerCase(),
        'clubAdmins': [uid],
        'clubOwners': [uid],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'teams': [],
      });
      clubName = _newClubNameCtrl.text.trim();
      clubId = newRef.id;
    } else {
      clubName = _selectedClub!;
      // Hämta doc ID baserat på clubName
      final clubQuery =
          await db
              .collection('clubs')
              .where('clubName', isEqualTo: clubName)
              .limit(1)
              .get();
      clubId = clubQuery.docs.first.id;
    }

    // Skapa team
    final teamRef = await db.collection('teams').add({
      'teamName': _teamNameCtrl.text.trim(),
      'clubName': clubName,
      'clubId': clubId,
      'imageUrl': '',
      'members': [uid],
      'teamAdmins': [uid],
      'teamRoles': {
        uid: ['Admin'],
      },
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    });

    // Uppdatera klubbens teams-lista
    await db.collection('clubs').doc(clubId).update({
      'teams': FieldValue.arrayUnion([teamRef.id]),
    });

    // Uppdatera användarens dokument
    await db.collection('users').doc(uid).update({
      'currentTeamId': teamRef.id,
      'teamRoles.${teamRef.id}': ['Admin'],
      'clubIds': FieldValue.arrayUnion([clubId]),
      'teamIds': FieldValue.arrayUnion([teamRef.id]),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skapa nytt lag')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _loadingClubs
                ? const Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _teamNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Lagets namn',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Fyll i ett namn'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedClub,
                        decoration: const InputDecoration(
                          labelText: 'Välj klubb',
                          helperText:
                              'Endast klubbar där du är admin/ägare är valbara.',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ..._allClubs.map(
                            (name) => DropdownMenuItem(
                              value: name,
                              enabled: _adminClubs.contains(name),
                              child: Text(
                                name,
                                style:
                                    _adminClubs.contains(name)
                                        ? null
                                        : const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'new',
                            child: Text('Ny klubb...'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedClub = val),
                        validator:
                            (v) =>
                                (v == null)
                                    ? 'Välj en klubb eller skapa ny'
                                    : null,
                      ),

                      if (_selectedClub == 'new') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newClubNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nytt klubbnamn',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (_selectedClub == 'new' &&
                                          (v == null || v.trim().isEmpty))
                                      ? 'Fyll i ett klubbnamn'
                                      : null,
                        ),
                      ],

                      const SizedBox(height: 24),
                      _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Spara'),
                            onPressed: _saveTeam,
                          ),
                    ],
                  ),
                ),
      ),
    );
  }
}
