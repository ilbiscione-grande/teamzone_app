import 'member.dart';
import 'callup.dart';

class MemberCallup {
  final String? callupId; // null om ingen kallelse finns
  final Member member;
  final CallupStatus status;
  final bool participated;

  // Ny träningsstatistik
  final int training2Weeks; // Antal träningar deltagit i senaste 2 veckor
  final int training6Weeks; // Antal träningar deltagit i senaste 6 veckor
  final int
  trainingTotal; // Totalt antal träningar deltagit i (från playerStats)

  MemberCallup({
    this.callupId,
    required this.member,
    required this.status,
    required this.participated,
    this.training2Weeks = 0,
    this.training6Weeks = 0,
    this.trainingTotal = 0,
  });

  // Hjälper om du vill uppdatera enstaka värden utan att skapa ny instans manuellt
  MemberCallup copyWith({
    String? callupId,
    Member? member,
    CallupStatus? status,
    bool? participated,
    int? training2Weeks,
    int? training6Weeks,
    int? trainingTotal,
  }) {
    return MemberCallup(
      callupId: callupId ?? this.callupId,
      member: member ?? this.member,
      status: status ?? this.status,
      participated: participated ?? this.participated,
      training2Weeks: training2Weeks ?? this.training2Weeks,
      training6Weeks: training6Weeks ?? this.training6Weeks,
      trainingTotal: trainingTotal ?? this.trainingTotal,
    );
  }
}
