// lib/core/providers/auth_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'auth_notifier.dart';
import 'user_session.dart';

/// Denna provider ger dig instansen av din AuthNotifier
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>(
  (ref) => AuthNotifier(),
);

/// En “family” provider som skapar en UserSession per uid
final userSessionProvider = ChangeNotifierProvider.family<UserSession, String>(
  (ref, uid) {
    // Hämta din region1-databas
    final db = ref.watch(firestoreProvider);
    // Skicka både uid och db till konstruktorn
    return UserSession(uid, db);
  },
);
