// lib/infrastructure/repositories/player_stats_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/player_stats.dart';

class PlayerStatsRepository {
  final FirebaseFirestore _db;

  PlayerStatsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('playerStats');

  DocumentReference<Map<String, dynamic>> _docRef(
    String userId,
    String season,
  ) {
    final docId = '${userId}_$season';
    return _col.doc(docId);
  }

  /// Streamar PlayerStats för en given userId och season
  Stream<PlayerStats?> stream(String userId, String season) {
    return _docRef(userId, season).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return PlayerStats.fromMap(snap.id, snap.data()!);
    });
  }

  /// Inkrementellt uppdatera aggregerad statistik
  Future<void> updateStats({
    required String userId,
    required String season,
    required String teamId, // ← nytt
    int deltaCallupsForTrainings = 0,
    int deltaAcceptedCallupsForTrainings = 0,
    int deltaRejectedCallupsForTrainings = 0,
    int deltaAcceptedCallupsForMatches = 0,
    int deltaRejectedCallupsForMatches = 0,
    int deltaAttendedTrainings = 0,
    int deltaTotalTrainings = 0,
    int deltaPlayedMatches = 0,
    int deltaCallupsForMatches = 0,
    int deltaMinutes = 0,
    int deltaGoals = 0,
    int deltaAssists = 0,
  }) {
    return _docRef(userId, season).set({
      'userId': userId,
      'season': season,
      'teamId': teamId,
      // Trainings
      'callupsForTrainings': FieldValue.increment(deltaCallupsForTrainings),
      'acceptedCallupsForTrainings': FieldValue.increment(
        deltaAcceptedCallupsForTrainings,
      ),
      'rejectedCallupsForTrainings': FieldValue.increment(
        deltaRejectedCallupsForTrainings,
      ),
      'attendedTrainings': FieldValue.increment(deltaAttendedTrainings),
      'totalTrainings': FieldValue.increment(deltaTotalTrainings),
      // Matches
      'callupsForMatches': FieldValue.increment(deltaCallupsForMatches),
      'acceptedCallupsForMatches': FieldValue.increment(
        deltaAcceptedCallupsForMatches,
      ),
      'rejectedCallupsForMatches': FieldValue.increment(
        deltaRejectedCallupsForMatches,
      ),
      'deltaPlayedMatches': FieldValue.increment(deltaPlayedMatches),
      'totalMinutes': FieldValue.increment(deltaMinutes),
      'goals': FieldValue.increment(deltaGoals),
      'assists': FieldValue.increment(deltaAssists),
    }, SetOptions(merge: true));
  }

  /// Sätter statistik för ett enskilt event
  Future<void> setEventStats({
    required String eventId,
    required String userId,
    required bool attended,
    int minutes = 0,
    int goals = 0,
    int assists = 0,
  }) {
    final ref = _db
        .collection('events')
        .doc(eventId)
        .collection('eventStats')
        .doc(userId);
    return ref.set({
      'attended': attended,
      'minutes': minutes,
      'goals': goals,
      'assists': assists,
    }, SetOptions(merge: true));
  }

  /// Tar bort per‑event‑statistik
  Future<void> deleteEventStats({
    required String eventId,
    required String userId,
  }) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('eventStats')
        .doc(userId)
        .delete();
  }
}
