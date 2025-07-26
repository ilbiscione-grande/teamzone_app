// lib/domain/models/team.dart

class Team {
  final String id;
  final String teamName;
  final String clubId;
  final String clubName;
  

  /// Om säsongen går över årsskiftet (t.ex. basket/handboll)
  final bool seasonCrossYear;

  /// Månad (1–12) då säsongen startar om crossYear=true
  final int seasonStartMonth;

  Team({
    required this.id,
    required this.teamName,
    required this.clubId,
    required this.clubName,
    this.seasonCrossYear = false,
    this.seasonStartMonth = 1,
  });

  factory Team.fromMap(String id, Map<String, dynamic> data) {
    return Team(
      id: id,
      teamName: data['teamName']        as String? ?? 'Namnlöst lag',
      clubId: data['clubId']            as String? ?? '',
      clubName: data['clubName']        as String? ?? 'Ingen klubb',
      seasonCrossYear: data['seasonCrossYear']    as bool? ?? false,
      seasonStartMonth: data['seasonStartMonth']  as int?  ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'teamName':         teamName,
    'clubId':           clubId,
    'clubName':         clubName,
    'seasonCrossYear':  seasonCrossYear,
    'seasonStartMonth': seasonStartMonth,
  };
}
