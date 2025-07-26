import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  const AuthGuard({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lyssna på auth-state
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Om vi väntar på auth-status, visa loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Om ingen user, skicka till login
        if (!snapshot.hasData) {
          // Kom ihåg att använda pushReplacement så att det inte går att backa
          Future.microtask(() => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ));
          return const Scaffold(
            body: Center(child: SizedBox.shrink()),
          );
        }
        // Om inloggad, visa den egentliga sidan
        return child;
      },
    );
  }
}
