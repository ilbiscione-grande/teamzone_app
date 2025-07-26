// lib/infrastructure/repositories/attendance_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/attendance.dart';

class AttendanceRepository {
  final FirebaseFirestore _db;

  /// Ta emot din Firestore-instans i konstruktorn
  AttendanceRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('attendance');

  Future<void> create(Attendance a) async {
    await _col.add({
      ...a.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Attendance>> streamByUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Attendance.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Attendance>> streamByCallup(String callupId) {
    return _col
        .where('callupId', isEqualTo: callupId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Attendance.fromMap(d.id, d.data())).toList());
  }
}
