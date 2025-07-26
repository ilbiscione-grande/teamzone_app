// lib/features/settings/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teamzone_app/core/providers/theme_providers.dart';
import 'package:teamzone_app/auth/login_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;

  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _isChangingPwd = false;

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Byt lösenord'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _currentPwdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nuvarande lösenord',
                    ),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _newPwdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nytt lösenord',
                    ),
                    obscureText: true,
                  ),
                ],
              ),
              actions: [
                if (_isChangingPwd)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                TextButton(
                  onPressed:
                      _isChangingPwd ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Avbryt'),
                ),
                ElevatedButton(
                  onPressed:
                      _isChangingPwd
                          ? null
                          : () async {
                            final current = _currentPwdCtrl.text.trim();
                            final neuer = _newPwdCtrl.text.trim();
                            if (current.isEmpty || neuer.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Lösenorden saknar eller är för kort',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => _isChangingPwd = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser!;
                              final cred = EmailAuthProvider.credential(
                                email: user.email!,
                                password: current,
                              );
                              await user.reauthenticateWithCredential(cred);
                              await user.updatePassword(neuer);
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lösenord uppdaterat'),
                                ),
                              );
                            } on FirebaseAuthException catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Fel: ${e.message}')),
                              );
                            } finally {
                              setState(() => _isChangingPwd = false);
                            }
                          },
                  child: const Text('Spara'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Inställningar')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          SwitchListTile(
            title: const Text('Mörkt läge'),
            subtitle: const Text('Växla mellan ljust och mörkt tema'),
            value: isDark,
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).state =
                  v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          SwitchListTile(
            title: const Text('Notiser'),
            subtitle: const Text('Ta emot push-notiser'),
            value: _notificationsEnabled,
            onChanged:
                (v) => setState(() {
                  _notificationsEnabled = v;
                }),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Byt lösenord'),
            onTap: _showChangePasswordDialog,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logga ut'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
