// lib/domain/models/player_stats.dart

class PlayerStats {
  final String id;
  final String userId;
  final String season;
  final int trainingsAttended;    // antal gjorda träningar
  final int trainingsCalled;      // träningar man kallats till
  final int matchesAttended;      // antal gjorda matcher
  final int matchesCalled;        // matcher man blivit kallad till
  final int totalGoals;
  final int totalAssists;
  final int yellowCards;
  final int redCards;

  PlayerStats({
    required this.id,
    required this.userId,
    required this.season,
    required this.trainingsAttended,
    required this.trainingsCalled,
    required this.matchesAttended,
    required this.matchesCalled,
    required this.totalGoals,
    required this.totalAssists,
    required this.yellowCards,
    required this.redCards,
  });

  factory PlayerStats.fromMap(String id, Map<String, dynamic> m) {
    return PlayerStats(
      id: id,
      userId: m['userId'] as String,
      season: m['season'] as String,
      trainingsAttended: m['trainingsAttended'] as int? ?? 0,
      trainingsCalled: m['trainingsCalled'] as int? ?? 0,
      matchesAttended: m['matchesAttended'] as int? ?? 0,
      matchesCalled: m['matchesCalled'] as int? ?? 0,
      totalGoals: m['totalGoals'] as int? ?? 0,
      totalAssists: m['totalAssists'] as int? ?? 0,
      yellowCards: m['yellowCards'] as int? ?? 0,
      redCards: m['redCards'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'season': season,
      'trainingsAttended': trainingsAttended,
      'trainingsCalled': trainingsCalled,
      'matchesAttended': matchesAttended,
      'matchesCalled': matchesCalled,
      'totalGoals': totalGoals,
      'totalAssists': totalAssists,
      'yellowCards': yellowCards,
      'redCards': redCards,
    };
  }
}
