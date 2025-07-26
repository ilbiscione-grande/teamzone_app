/// lib/core/providers/event_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/repositories/event_repository.dart';
import '../../infrastructure/repositories/analysis_repository.dart';
import '../../domain/models/analysis.dart';
import '../../domain/models/my_event.dart';
import '../../domain/models/member_callup.dart';
import '../../core/providers/firestore_providers.dart';

/// Här injicerar vi Firestore-instansen i EventRepository

/// Event repository provider
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return EventRepository(db);
});

/// Stream of Analysis for a given eventId
final analysisProvider = StreamProvider.family<Map<String, dynamic>?, String>((
  ref,
  eventId,
) {
  final repo = ref.read(analysisRepositoryProvider);
  return repo.watchAnalysis(eventId);
});

/// Stream of MyEvent for a given eventId
final eventProvider = StreamProvider.family<MyEvent, String>((ref, eventId) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.streamEvent(eventId);
});

/// Stream of MemberCallup per eventId
final callupsProvider = StreamProvider.family<List<MemberCallup>, String>((
  ref,
  eventId,
) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.streamMembersWithCallups(eventId).asBroadcastStream();
});
