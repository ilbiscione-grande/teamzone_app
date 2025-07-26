// lib/repositories/event_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/my_event.dart';
import '../../domain/models/member.dart';
import '../../domain/models/callup.dart';
import '../../domain/models/member_callup.dart';
import '../../domain/models/resource.dart';
import '../../domain/models/stats.dart';
import '../../domain/models/analysis.dart';
import '../../application/services/player_stats_service.dart';

class EventRepository {
  final FirebaseFirestore _db;

  /// Ta emot din Firestore-instans i konstruktorn
  EventRepository(this._db);

  /// Streamar ett enskilt event
  Stream<MyEvent> streamEvent(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((snap) => MyEvent.fromSnapshot(snap));
  }

  /// Streamar alla medlemmar + deras callup-status för ett event
  Stream<List<MemberCallup>> streamMembersWithCallups(String eventId) {
    final eventRef = _db.collection('events').doc(eventId);

    return eventRef.snapshots().switchMap((eventSnap) {
      final teamId = eventSnap.data()?['teamId'] as String?;
      if (teamId == null) return Stream.value(<MemberCallup>[]);

      final callupsStream =
          _db
              .collection('callups')
              .where('eventId', isEqualTo: eventId)
              .snapshots();

      final teamMembersStream =
          _db
              .collection('users')
              .where('teamIds', arrayContains: teamId)
              .snapshots();

      return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        Future<List<MemberCallup>>
      >(callupsStream, teamMembersStream, (callupSnap, userSnap) async {
        // a) Bygg en karta memberId → Callup
        final callupMap = <String, Callup>{
          for (var doc in callupSnap.docs)
            Callup.fromSnapshot(doc).memberId: Callup.fromSnapshot(doc),
        };

        // b) Slå ihop alla userIds och callupIds
        final teamIds =
            userSnap.docs.map((d) => Member.fromSnapshot(d).uid).toSet();
        final callupIds = callupMap.keys.toSet();
        final allIds = {...teamIds, ...callupIds};

        // c) Hämta Member-objekt i batchar
        final List<Member> members = [];
        const batchSize = 10;
        final idsList = allIds.toList();
        for (var i = 0; i < idsList.length; i += batchSize) {
          final chunk = idsList.sublist(
            i,
            i + batchSize > idsList.length ? idsList.length : i + batchSize,
          );
          final snap =
              await _db.collection('users').where('uid', whereIn: chunk).get();
          members.addAll(snap.docs.map(Member.fromSnapshot));
        }

        // d) Mappa Member + CallupStatus → MemberCallup
        return members.map((member) {
          final c = callupMap[member.uid];
          return MemberCallup(
            callupId: c?.id,
            member: member,
            status: c?.status ?? CallupStatus.notCalled,
            participated: c?.participated ?? false,
          );
        }).toList();
      }).asyncMap((futureList) => futureList);
    });
  }

  Future<List<MemberCallup>> fetchMembersWithSameRole(
    String eventId,
    String position,
  ) async {
    final eventSnap = await _db.collection('events').doc(eventId).get();
    final teamId = eventSnap.data()?['teamId'] as String?;
    if (teamId == null) return [];

    final usersSnap =
        await _db
            .collection('users')
            .where('currentTeamId', isEqualTo: teamId)
            .get();

    final matchingMembers =
        usersSnap.docs
            .map((doc) => Member.fromSnapshot(doc))
            .where((m) => m.position == position)
            .take(3)
            .toList();

    if (matchingMembers.isEmpty) return [];

    final uidList = matchingMembers.map((m) => m.uid).toList();
    final statsSnap =
        await _db
            .collection('playerStats')
            .where('uid', whereIn: uidList)
            .get();

    final statsByUid = {
      for (var doc in statsSnap.docs) doc['uid'] as String: doc.data(),
    };

    final allTrainingsSnap =
        await _db
            .collection('events')
            .where('teamId', isEqualTo: teamId)
            .where('eventType', isEqualTo: 'Träning')
            .where('start', isLessThan: DateTime.now())
            .get();

    final allTrainings = allTrainingsSnap.docs.map((d) => d.data()).toList();
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final sixWeeksAgo = now.subtract(const Duration(days: 42));

    final filtered2Weeks =
        allTrainings
            .where(
              (t) =>
                  (t['start'] as Timestamp?)?.toDate().isAfter(twoWeeksAgo) ??
                  false,
            )
            .toList();
    final filtered6Weeks =
        allTrainings
            .where(
              (t) =>
                  (t['start'] as Timestamp?)?.toDate().isAfter(sixWeeksAgo) ??
                  false,
            )
            .toList();

    return matchingMembers.map((member) {
      final stats = statsByUid[member.uid] ?? {};
      final participatedIds = List<String>.from(
        stats['trainingsParticipatedIds'] ?? [],
      );

      final p2 =
          filtered2Weeks.where((t) => participatedIds.contains(t['id'])).length;
      final p6 =
          filtered6Weeks.where((t) => participatedIds.contains(t['id'])).length;

      return MemberCallup(
        member: member,
        status: CallupStatus.notCalled,
        participated: false,
        training2Weeks: p2,
        training6Weeks: p6,
        trainingTotal: participatedIds.length,
      );
    }).toList();
  }

  /// Tar bort en kallelse OCH rullar tillbaka aggregerad statistik korrekt
  /// Tar bort en kallelse *och* rullar tillbaka aggregerad statistik
  Future<void> deleteCallupAndRollback({
    required String eventId,
    required String callupId,
    required String memberId,
    required bool participated,
    required PlayerStatsService statsSvc,
  }) async {
    // 1) Hämta event & team → season
    final evSnap = await _db.collection('events').doc(eventId).get();
    if (!evSnap.exists) return;
    final evData = evSnap.data()!;
    final teamId = evData['teamId'] as String;
    final evType = (evData['eventType'] as String? ?? '').toLowerCase();
    final isMatch = evType == 'match';
    final isTraining = evType == 'träning';
    final date =
        (evData['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    final teamDoc = await _db.collection('teams').doc(teamId).get();
    final cross = teamDoc.data()?['seasonCrossYear'] as bool? ?? false;
    final startMo = teamDoc.data()?['seasonStartMonth'] as int? ?? 1;

    final season = _computeSeasonId(
      date,
      crossYear: cross,
      seasonStartMonth: startMo,
    );

    // 2) Läs in callup‑dokumentet för att veta gammal status
    final callupSnap = await _db.collection('callups').doc(callupId).get();
    if (!callupSnap.exists) return;
    final callupData = callupSnap.data()!;
    final oldStatus = CallupStatus.values.firstWhere(
      (e) => e.toString().split('.').last == callupData['status'],
      orElse: () => CallupStatus.notCalled,
    );

    // 3) Bygg upp samtliga deltas
    int deltaCallupsForMatches = isMatch ? -1 : 0;
    int deltaCallupsForTrainings = isTraining ? -1 : 0;
    int deltaPlayedMatches = (isMatch && participated) ? -1 : 0;
    int deltaAttendedTrainings = (isTraining && participated) ? -1 : 0;

    int deltaAcceptedForMatches = 0;
    int deltaAcceptedForTrainings = 0;
    int deltaRejectedForMatches = 0;
    int deltaRejectedForTrainings = 0;

    if (oldStatus == CallupStatus.accepted) {
      if (isMatch) deltaAcceptedForMatches = -1;
      if (isTraining) deltaAcceptedForTrainings = -1;
    } else if (oldStatus == CallupStatus.declined) {
      if (isMatch) deltaRejectedForMatches = -1;
      if (isTraining) deltaRejectedForTrainings = -1;
    }

    // 4) Rulla tillbaka alla statistikräkningar
    await statsSvc.updateStats(
      userId: memberId,
      season: season,
      teamId: teamId,
      deltaCallupsForMatches: deltaCallupsForMatches,
      deltaPlayedMatches: deltaPlayedMatches,
      deltaCallupsForTrainings: deltaCallupsForTrainings,
      deltaAttendedTrainings: deltaAttendedTrainings,
      deltaAcceptedCallupsForMatches: deltaAcceptedForMatches,
      deltaAcceptedCallupsForTrainings: deltaAcceptedForTrainings,
      deltaRejectedCallupsForMatches: deltaRejectedForMatches,
      deltaRejectedCallupsForTrainings: deltaRejectedForTrainings,
    );

    // 5) Ta bort kallelsen
    await _db.collection('callups').doc(callupId).delete();
  }

  /// Skickar kallelser och uppdaterar aggregerad statistik.
  ///
  /// [crossYear] och [seasonStartMonth] kommer från teamets inställningar.
  Future<void> sendCallups(
    String eventId,
    List<MemberCallup> mcs,
    PlayerStatsService statsSvc, {
    required bool crossYear,
    required int seasonStartMonth,
  }) async {
    // 0) Hämta alla redan kallade memberId för det här eventet
    final memberIds = mcs.map((mc) => mc.member.uid).toList();
    final existingSnap =
        await _db
            .collection('callups')
            .where('eventId', isEqualTo: eventId)
            .where('memberId', whereIn: memberIds)
            .get();
    final alreadyCalled =
        existingSnap.docs
            .map((doc) => doc.data()['memberId'] as String)
            .toSet();

    // 1) Filtrera bort de som redan är kallade
    final toSend =
        mcs.where((mc) => !alreadyCalled.contains(mc.member.uid)).toList();
    if (toSend.isEmpty) return; // inget nytt att skicka

    // 2) Läs eventets grunddata
    final eventSnap = await _db.collection('events').doc(eventId).get();
    final data = eventSnap.data()!;
    final eventDate = data['eventDate'] as Timestamp?;
    final teamId = data['teamId'] as String;
    final rawType = (data['eventType'] as String? ?? '').trim().toLowerCase();
    final isMatch = rawType == 'match';
    final isTraining = rawType == 'träning';

    // 3) Batcha NYA kallelser
    final batch = _db.batch();
    for (var mc in toSend) {
      final docRef = _db.collection('callups').doc();
      batch.set(docRef, {
        'userId': mc.member.uid,
        'memberId': mc.member.uid,
        'eventId': eventId,
        'type': mc.member.userType.toString().split('.').last,
        'status': CallupStatus.pending.toString().split('.').last,
        'sentAt': FieldValue.serverTimestamp(),
        if (eventDate != null) 'eventDate': eventDate,
        'participated': false,
      });
    }
    await batch.commit();

    // 4) Uppdatera playerStats bara för de nya
    final season = _computeSeasonId(
      eventDate?.toDate() ?? DateTime.now(),
      crossYear: crossYear,
      seasonStartMonth: seasonStartMonth,
    );
    for (var mc in toSend) {
      await statsSvc.updateStats(
        userId: mc.member.uid,
        season: season,
        teamId: teamId,
        deltaPlayedMatches: isMatch && mc.participated ? 1 : 0,
        deltaCallupsForMatches: isMatch ? 1 : 0,
        deltaCallupsForTrainings: isTraining ? 1 : 0,
        deltaAttendedTrainings: isTraining && mc.participated ? 1 : 0,
      );
    }
  }

  /// Beräknar ett season‑ID utan "/" baserat på upplägget för laget:
  ///
  /// - crossYear=false ⇒ "2025" (kalendersäsong)
  /// - crossYear=true  ⇒ "2025_2026" (t.ex. höst–vår‑säsong)
  String _computeSeasonId(
    DateTime date, {
    required bool crossYear,
    required int seasonStartMonth,
  }) {
    final year = date.year;
    if (!crossYear) {
      return '$year';
    }
    if (date.month >= seasonStartMonth) {
      return '${year}_${year + 1}';
    } else {
      return '${year - 1}_$year';
    }
  }

  /// Ändrar status på en kallelse OCH uppdaterar antalet accepterade/avvisade
  Future<void> updateCallupStatus({
    required String callupId,
    required CallupStatus newStatus,
    required PlayerStatsService statsSvc,
    required bool crossYear,
    required int seasonStartMonth,
  }) async {
    final docRef = _db.collection('callups').doc(callupId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final oldStatus = CallupStatus.values.firstWhere(
      (e) => e.toString().split('.').last == data['status'],
      orElse: () => CallupStatus.notCalled,
    );
    if (oldStatus == newStatus) return;

    final userId = data['memberId'] as String;
    final eventId = data['eventId'] as String;

    // Hämta event‑datan
    final evSnap = await _db.collection('events').doc(eventId).get();
    if (!evSnap.exists) return;
    final ev = evSnap.data()!;
    final ts = ev['eventDate'] as Timestamp?;
    final season = _computeSeasonId(
      ts?.toDate() ?? DateTime.now(),
      crossYear: crossYear,
      seasonStartMonth: seasonStartMonth,
    );
    final isMatch = (ev['eventType'] as String).toLowerCase() == 'match';
    final isTraining = (ev['eventType'] as String).toLowerCase() == 'träning';
    final teamId = ev['teamId'] as String;

    // Räkna ut nettoplustecken per fält
    final int deltaAccepted =
        (newStatus == CallupStatus.accepted ? 1 : 0) -
        (oldStatus == CallupStatus.accepted ? 1 : 0);
    final int deltaRejected =
        (newStatus == CallupStatus.declined ? 1 : 0) -
        (oldStatus == CallupStatus.declined ? 1 : 0);

    // 1) Uppdatera statusen
    await docRef.update({'status': newStatus.toString().split('.').last});

    // 2) Kör bara ETT stats‑anrop med alla deltas
    await statsSvc.updateStats(
      userId: userId,
      season: season,
      teamId: teamId,
      deltaAcceptedCallupsForMatches: isMatch ? deltaAccepted : 0,
      deltaRejectedCallupsForMatches: isMatch ? deltaRejected : 0,
      deltaAcceptedCallupsForTrainings: isTraining ? deltaAccepted : 0,
      deltaRejectedCallupsForTrainings: isTraining ? deltaRejected : 0,
    );
  }

  Future<void> markParticipated({
    required String eventId,
    String? callupId,
    required String memberId,
  }) async {
    final batch = _db.batch();
    final eventSnap = await _db.collection('events').doc(eventId).get();
    final eventType = eventSnap.data()?['eventType'] as String? ?? '';

    final callupColl = _db.collection('callups');
    final eventRef = _db.collection('events').doc(eventId);
    final statsRef = _db.collection('playerStats').doc(memberId);

    late final String participatedField;
    late final String calledField;
    switch (eventType) {
      case 'Match':
        participatedField = 'matchesParticipated';
        calledField = 'matchesCalled';
        break;
      case 'Träning':
        participatedField = 'trainingsParticipated';
        calledField = 'trainingsCalled';
        break;
      case 'Möte':
        participatedField = 'meetingsParticipated';
        calledField = 'meetingsCalled';
        break;
      default:
        participatedField = 'otherParticipated';
        calledField = 'otherCalled';
    }

    if (callupId != null) {
      batch.update(callupColl.doc(callupId), {'participated': true});
    } else {
      final newDoc = callupColl.doc();
      batch.set(newDoc, {
        'eventId': eventId,
        'memberId': memberId,
        'status': CallupStatus.accepted.toString().split('.').last,
        'sentAt': FieldValue.serverTimestamp(),
        'participated': true,
      });
      batch.set(statsRef, {
        calledField: FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    batch.update(eventRef, {
      'attended': FieldValue.arrayUnion([memberId]),
    });
    batch.set(statsRef, {
      participatedField: FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> sendReminder({required String callupId}) {
    return _db.collection('callups').doc(callupId).update({
      'reminderSentAt': FieldValue.arrayUnion([Timestamp.now()]),
      'lastReminderAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Resource>> fetchResources(String eventId) async {
    final snap = await _db.collection('events/$eventId/resources').get();
    return snap.docs.map((d) => Resource.fromSnapshot(d)).toList();
  }

  Stream<Stats> streamStats(String eventId) {
    return _db
        .collection('events/$eventId/stats')
        .doc('summary')
        .snapshots()
        .map((snap) => Stats.fromSnapshot(snap));
  }

  Stream<Analysis?> streamAnalysis(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('analysis')
        .doc('summary')
        .snapshots()
        .map((snap) => snap.exists ? Analysis.fromSnapshot(snap) : null);
  }

  Future<Map<String, int>> getTrainingAttendance({
    required String userId,
    required String teamId,
  }) async {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final sixWeeksAgo = now.subtract(const Duration(days: 42));

    final trainingsSnap =
        await _db
            .collection('events')
            .where('teamId', isEqualTo: teamId)
            .where('eventType', isEqualTo: 'Training')
            .where('eventDate', isLessThan: now)
            .get();

    final trainings2w =
        trainingsSnap.docs.where((doc) {
          final start = (doc.data()['eventDate'] as Timestamp?)?.toDate();
          return start != null && start.isAfter(twoWeeksAgo);
        }).toList();

    final trainings6w =
        trainingsSnap.docs.where((doc) {
          final start = (doc.data()['eventDate'] as Timestamp?)?.toDate();
          return start != null && start.isAfter(sixWeeksAgo);
        }).toList();

    final callupsSnap =
        await _db
            .collection('callups')
            .where('userId', isEqualTo: userId)
            .where(
              'eventId',
              whereIn: trainingsSnap.docs.map((d) => d.id).toList(),
            )
            .get();

    final participatedMap = {
      for (var doc in callupsSnap.docs)
        doc.data()['eventId']: doc.data()['participated'] == true,
    };

    int count(List<QueryDocumentSnapshot> docs) =>
        docs.where((doc) => participatedMap[doc.id] == true).length;

    final pct2w =
        trainings2w.isEmpty
            ? 0
            : (count(trainings2w) / trainings2w.length * 100).round();
    final pct6w =
        trainings6w.isEmpty
            ? 0
            : (count(trainings6w) / trainings6w.length * 100).round();

    return {'2w': pct2w, '6w': pct6w};
  }

  Stream<Stats> streamTeamStats(
    String teamId,
    String period,
    String eventType,
  ) {
    final now = DateTime.now();
    late DateTime from, to;

    if (period.endsWith('d')) {
      final days = int.parse(period.replaceAll('d', ''));
      from = now.subtract(Duration(days: days));
      to = now;
    } else {
      final year = int.parse(period);
      from = DateTime(year, 1, 1);
      to =
          year.toString() == now.year.toString()
              ? now
              : DateTime(year + 1, 1, 1).subtract(const Duration(seconds: 1));
    }

    return _db
        .collection('events')
        .where('teamId', isEqualTo: teamId)
        .where('eventType', isEqualTo: eventType)
        .where('eventDate', isGreaterThanOrEqualTo: from)
        .where('eventDate', isLessThan: to)
        .snapshots()
        .map((snap) {
          final attendance = <AttendanceCount>[];
          final scores = <ScoreCount>[];

          for (final doc in snap.docs) {
            final data = doc.data();
            final attended = data['attended'] as List<dynamic>? ?? [];
            final eventDate = (data['eventDate'] as Timestamp).toDate();
            final dayIndex = eventDate.difference(from).inDays;
            attendance.add(
              AttendanceCount(dayIndex: dayIndex, count: attended.length),
            );

            final our = data['ourScore'] as int? ?? 0;
            final opp = data['opponentScore'] as int? ?? 0;
            scores.add(
              ScoreCount(dayIndex: dayIndex, ourScore: our, opponentScore: opp),
            );
          }

          return Stats(attendance: attendance, scores: scores);
        });
  }
}
