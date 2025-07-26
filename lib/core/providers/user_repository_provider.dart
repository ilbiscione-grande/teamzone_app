// lib/core/providers/user_repository_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/infrastructure/repositories/user_repository.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';

/// Provider som ger dig ett UserRepository kopplat mot din “region1”-databas
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.read(firestoreProvider);
  return UserRepository(db);
});
