// lib/application/services/player_stats_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/player_stats.dart';
import '../../infrastructure/repositories/player_stats_repository.dart';
import '../../core/providers/player_stats_repository_provider.dart';

class PlayerStatsService {
  final PlayerStatsRepository _repo;
  PlayerStatsService(this._repo);

  /// Streamar aggregerad statistik för en spelare/säsong.
  Stream<PlayerStats?> statsStream(String userId, String season) {
    return _repo.stream(userId, season);
  }

  /// Inkrementellt uppdatera den aggregerade statistiken.
// lib/application/services/player_stats_service.dart

Future<void> updateStats({
  required String userId,
  required String season,
  required String teamId,
  int deltaAttendedTrainings        = 0,
  int deltaCallupsForTrainings      = 0,
  int deltaAcceptedCallupsForTrainings   = 0,  // nytt
  int deltaRejectedCallupsForTrainings   = 0,  // nytt
  int deltaPlayedMatches            = 0,
  int deltaCallupsForMatches        = 0,
  int deltaAcceptedCallupsForMatches     = 0,  // nytt
  int deltaRejectedCallupsForMatches     = 0,  // nytt
  int deltaMinutes                  = 0,
  int deltaGoals                    = 0,
  int deltaAssists                  = 0,
}) {
  return _repo.updateStats(
    userId: userId,
    season: season,
    teamId: teamId,
    deltaAttendedTrainings: deltaAttendedTrainings,
    deltaCallupsForTrainings: deltaCallupsForTrainings,
    deltaAcceptedCallupsForTrainings: deltaAcceptedCallupsForTrainings,
    deltaRejectedCallupsForTrainings: deltaRejectedCallupsForTrainings,
    deltaPlayedMatches: deltaPlayedMatches,
    deltaCallupsForMatches: deltaCallupsForMatches,
    deltaAcceptedCallupsForMatches: deltaAcceptedCallupsForMatches,
    deltaRejectedCallupsForMatches: deltaRejectedCallupsForMatches,
    deltaMinutes: deltaMinutes,
    deltaGoals: deltaGoals,
    deltaAssists: deltaAssists,
  );
}

  /// Sätt statistik för ett enskilt event under /events/{eventId}/eventStats/{userId}.
  Future<void> setEventStats({
    required String eventId,
    required String userId,
    required bool attended,
    int minutes = 0,
    int goals = 0,
    int assists = 0,
  }) {
    return _repo.setEventStats(
      eventId: eventId,
      userId: userId,
      attended: attended,
      minutes: minutes,
      goals: goals,
      assists: assists,
    );
  }

  // lib/application/services/player_stats_service.dart

  /// Tar bort per‑event‑statistik
  Future<void> deleteEventStats({
    required String eventId,
    required String userId,
  }) {
    return _repo.deleteEventStats(eventId: eventId, userId: userId);
  }
}

/// Riverpod‑provider för PlayerStatsService
final playerStatsServiceProvider = Provider<PlayerStatsService>((ref) {
  final repo = ref.read(playerStatsRepositoryProvider);
  return PlayerStatsService(repo);
});
