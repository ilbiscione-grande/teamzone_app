// lib/models/stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enkel klass för en datapunkt i närvarostatistiken
class AttendanceCount {
  final int dayIndex;
  final int count;

  AttendanceCount({
    required this.dayIndex,
    required this.count,
  });

  factory AttendanceCount.fromJson(Map<String, dynamic> json) {
    return AttendanceCount(
      dayIndex: json['dayIndex'] as int,
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayIndex': dayIndex,
      'count': count,
    };
  }
}

class ScoreCount {
  final int dayIndex;
  final int ourScore;
  final int opponentScore;

  ScoreCount({
    required this.dayIndex,
    required this.ourScore,
    required this.opponentScore,
  });
}

/// Samlad statistik för ett event
class Stats {
  final List<AttendanceCount> attendance;
   final List<ScoreCount> scores;

Stats({
    this.attendance = const [],
    this.scores = const [],
  });
  /// Bygger Stats från ett Firestore-dokument (antingen enda doc eller en samling)
  factory Stats.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    final rawList = data['attendance'] as List<dynamic>? ?? [];
    return Stats(
      attendance: rawList
          .map((e) => AttendanceCount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendance': attendance.map((e) => e.toJson()).toList(),
    };
  }
}
