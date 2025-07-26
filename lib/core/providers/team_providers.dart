// lib/core/providers/team_providers.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/domain/models/team.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart ';

/// Provider som returnerar alla lag vars ID finns i
/// fältet `teamIds` på det inloggade användar‐dokumentet.
final userTeamsProvider = FutureProvider<List<Team>>((ref) async {
  final uid = ref.watch(authNotifierProvider).currentUser?.uid;
  if (uid == null) return [];

  final db = ref.watch(firestoreProvider);

  final userQuery =
      await db.collection('users').where('uid', isEqualTo: uid).limit(1).get();

  if (userQuery.docs.isEmpty) {
    debugPrint('🛑 Inget användardokument med uid=$uid funnet');
    return [];
  }

  final userSnap = userQuery.docs.first;
  final data = userSnap.data()!;
  final teamIds = (data['teamIds'] as List<dynamic>?)?.cast<String>() ?? [];

  final snaps = await Future.wait(
    teamIds.map((tid) => db.collection('teams').doc(tid).get()),
  );

  return snaps
      .where((s) => s.exists)
      .map((s) => Team.fromMap(s.id, s.data()!))
      .toList();
});

/// StateNotifier som håller valt lag‐ID, och kan bytas via [select].
class CurrentTeamNotifier extends StateNotifier<String?> {
  CurrentTeamNotifier() : super(null);

  /// Byt valt lag manuellt
  void select(String? teamId) => state = teamId;
}

/// Provider för det just nu valda laget.
/// Lyssnar på när [userTeamsProvider] levererar data
/// och sätter första ID:t automatiskt.
final currentTeamProvider = StateNotifierProvider<CurrentTeamNotifier, String?>(
  (ref) {
    final notifier = CurrentTeamNotifier();
    ref.listen<AsyncValue<List<Team>>>(userTeamsProvider, (_, teams) {
      teams.whenData((list) {
        if (list.isNotEmpty) {
          notifier.select(list.first.id);
        }
      });
    });
    return notifier;
  },
);

/// Ny: StreamProvider för att hämta ett enskilt Team med given teamId
final teamProvider = StreamProvider.family<Team, String>((ref, teamId) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('teams')
      .doc(teamId)
      .snapshots()
      .map((snap) => Team.fromMap(snap.id, snap.data()!));
});
