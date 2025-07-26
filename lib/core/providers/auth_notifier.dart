// lib/core/providers/auth_notifier.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthNotifier extends ChangeNotifier {
  User? _user;
  bool _isInitializing = true;
  StreamSubscription<User?>? _authSub;

  AuthNotifier() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      if (_isInitializing) _isInitializing = false;
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  bool get isInitializing => _isInitializing;

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
