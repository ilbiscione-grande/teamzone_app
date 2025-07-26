// lib/domain/models/attendance.dart
class Attendance {
  final String id;
  final String callupId;
  final String eventId;
  final String userId;
  final bool attended;
  final int minutesPlayed;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;

  Attendance({
    required this.id,
    required this.callupId,
    required this.eventId,
    required this.userId,
    required this.attended,
    required this.minutesPlayed,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
  });

  factory Attendance.fromMap(String id, Map<String, dynamic> m) => Attendance(
        id: id,
        callupId: m['callupId'],
        eventId: m['eventId'],
        userId: m['userId'],
        attended: m['attended'],
        minutesPlayed: m['minutesPlayed'],
        goals: m['goals'],
        assists: m['assists'],
        yellowCards: m['yellowCards'],
        redCards: m['redCards'],
      );

  Map<String, dynamic> toMap() => {
        'callupId': callupId,
        'eventId': eventId,
        'userId': userId,
        'attended': attended,
        'minutesPlayed': minutesPlayed,
        'goals': goals,
        'assists': assists,
        'yellowCards': yellowCards,
        'redCards': redCards,
      };
}
