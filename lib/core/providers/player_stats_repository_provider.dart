// lib/core/providers/player_stats_repository_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/infrastructure/repositories/player_stats_repository.dart';

/// Provider som ger dig ett PlayerStatsRepository kopplat mot din “region1”-databas
final playerStatsRepositoryProvider = Provider<PlayerStatsRepository>((ref) {
  final db = ref.read(firestoreProvider);
  return PlayerStatsRepository(db);
});
