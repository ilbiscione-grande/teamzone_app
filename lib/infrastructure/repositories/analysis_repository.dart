import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  // Hämta din region1‐instans
  final db = ref.read(firestoreProvider);
  return AnalysisRepository(db);
});

class AnalysisRepository {
  final FirebaseFirestore _firestore;
  AnalysisRepository(this._firestore);

  /// Hämtar analys-dokumentet som en Stream eller Future (om du vill)
  Stream<Map<String, dynamic>?> watchAnalysis(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('analysis')
        .doc('summary')
        .snapshots()
        .map((snap) => snap.data());
  }

  /// Uppdaterar ett fält i Firestore
  Future<void> updateField({
    required String eventId,
    required String field,
    required dynamic value,
  }) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('analysis')
        .doc('summary')
        .set({field: value}, SetOptions(merge: true));
  }
}
