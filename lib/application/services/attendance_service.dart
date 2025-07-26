// lib/application/services/attendance_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/attendance.dart';
import '../../infrastructure/repositories/attendance_repository.dart';
import '../../core/providers/attendance_repository_provider.dart';

/// Ett service-lager för att hantera attendance-logik.
class AttendanceService {
  final AttendanceRepository _repo;
  final FirebaseFunctions _functions;

  AttendanceService(this._repo, this._functions);

  /// Skapar eller uppdaterar en attendance-post.
  /// Molnfunktionen `onAttendanceWrite` sköter aggregeringen till playerStats.
  Future<void> recordAttendance(Attendance a) async {
    if (a.id.isEmpty) {
      await _repo.create(a);
    } else {
      await _repo.update(a.id, a.toMap());
    }
  }

  /// Jämför genomsnittliga matcher/minuter i en position.
  Future<Map<String, double>> compareAttendance({
    required String positionId,
    required String season,
  }) async {
    final callable =
        _functions.httpsCallable('compareAttendanceByPosition');
    final resp = await callable.call({
      'positionId': positionId,
      'season': season,
    });
    return Map<String, double>.from(resp.data);
  }
}

/// Riverpod-provider som bygger AttendanceService med rätt instanser.
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  final repo = ref.read(attendanceRepositoryProvider);
  final functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  return AttendanceService(repo, functions);
});
