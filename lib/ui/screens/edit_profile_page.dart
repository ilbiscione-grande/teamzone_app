// lib/features/home/presentation/pages/edit_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/user.dart';
import '../../core/providers/user_repository_provider.dart';
import '../../core/providers/firestore_providers.dart';
import '../../core/providers/auth_providers.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Nu separata fält för förnamn/efternamn
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mainRoleCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _avatarUrlCtrl = TextEditingController();
  // Nya fält
  final _favouritePositionCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final fbUser = fbAuth.FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getUserById(fbUser.uid);

      // Fyll i kontrollerna
      _firstNameCtrl.text = user.firstName;
      _lastNameCtrl.text = user.lastName;
      _mainRoleCtrl.text = user.mainRole;
      _emailCtrl.text = user.email;
      _avatarUrlCtrl.text = user.avatarUrl;
      _favouritePositionCtrl.text = user.favouritePosition ?? '';
      _phoneNumberCtrl.text = user.phoneNumber ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final fbUser = fbAuth.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingen inloggad användare')));
      return;
    }

    try {
      // Kombinera förnamn+efternamn för den gamla updateUser-metoden
      final fullName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

      // 1) Uppdatera övriga fält via UserRepository
      final updated = User(
        id: fbUser.uid,
        fullName: fullName,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        mainRole: _mainRoleCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        favouritePosition: _favouritePositionCtrl.text.trim(),
        phoneNumber: _phoneNumberCtrl.text.trim(),
        avatarUrl: _avatarUrlCtrl.text.trim(),
        yob: DateTime.now().year.toString(), // ev. behåll eller ta bort
      );
      await ref.read(userRepositoryProvider).updateUser(updated);

      // 2) Separat uppdatering av nya fält
      final db = ref.read(firestoreProvider);
      await db.collection('users').doc(fbUser.uid).update({
        'favouritePosition': _favouritePositionCtrl.text.trim(),
        'phoneNumber': _phoneNumberCtrl.text.trim(),
      });

      if (mounted) setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil uppdaterad')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kunde inte spara: $e')));
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Bekräfta radering'),
            content: const Text(
              'Är du säker på att du vill ta bort din profil? Detta går inte att ångra.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Ta bort'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      final fbUser = fbAuth.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        // Tar bort användare
        await ref.read(userRepositoryProvider).deleteUser(fbUser.uid);
        await fbAuth.FirebaseAuth.instance.signOut();
      }
      if (mounted) {
        setState(() => _loading = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil borttagen')));
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mainRoleCtrl.dispose();
    _emailCtrl.dispose();
    _avatarUrlCtrl.dispose();
    _favouritePositionCtrl.dispose();
    _phoneNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1) Läs auth‐state
    final auth = ref.watch(authNotifierProvider);
    // 2) Läs in din UserSession baserat på uid (tom sträng om ingen uid)
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redigera profil'),
        actions: [
          session.isAdmin
              ? IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Ta bort profil',
                onPressed: _confirmAndDelete,
              )
              : Container(),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Spara ändringar',
            onPressed: _saveProfile,
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Förnamn & Efternamn
                      TextFormField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'Förnamn'),
                        validator:
                            (v) =>
                                v == null || v.isEmpty ? 'Ange förnamn' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Efternamn',
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Ange efternamn'
                                    : null,
                      ),
                      const SizedBox(height: 12),

                      // Roll, E‑post & Avatar
                      TextFormField(
                        controller: _mainRoleCtrl,
                        decoration: const InputDecoration(labelText: 'Roll'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'E‑post'),
                        validator:
                            (v) =>
                                v != null && v.contains('@')
                                    ? null
                                    : 'Ogiltig e‑post',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _avatarUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nya fält: Favoritposition & Telefonnummer
                      TextFormField(
                        controller: _phoneNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Telefonnummer',
                        ),
                        keyboardType: TextInputType.phone,
                        // Gör det frivilligt:
                        validator: (v) {
                          // Returnera null (inget fel) även om det är tomt
                          if (v == null || v.isEmpty) return null;
                          // Eller kontrollera format om du vill:
                          // if (!RegExp(r'^[0-9 +\-]+$').hasMatch(v)) return 'Ogiltigt nummer';
                          return null;
                        },
                      ),
                      // Nya fält: Favoritposition & Telefonnummer
                      TextFormField(
                        controller: _favouritePositionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Favoritposition',
                        ),
                        // Gör det frivilligt:
                        validator: (v) {
                          // Returnera null (inget fel) även om det är tomt
                          if (v == null || v.isEmpty) return null;
                          // Eller kontrollera format om du vill:
                          // if (!RegExp(r'^[0-9 +\-]+$').hasMatch(v)) return 'Ogiltigt nummer';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
