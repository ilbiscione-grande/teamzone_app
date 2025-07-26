// lib/core/providers/attendance_repository_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/infrastructure/repositories/attendance_repository.dart';

/// Provider som ger dig ett AttendanceRepository kopplat mot din “region1”-databas
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final db = ref.read(firestoreProvider);
  return AttendanceRepository(db);
});
