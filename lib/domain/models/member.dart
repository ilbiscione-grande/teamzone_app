// lib/models/member.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'callup.dart'; // där enum MemberType ligger

class Member {
  final String id;
  final String uid;
  final String name;
  final String email;
  final String position;
  final String? profilePicture;
  final bool isAccepted;
  final MemberType userType;

  // Aggregerad statistik (från playerStats)
  final int matchesCalled;
  final int trainingsCalled;
  final int meetingsCalled;
  final int matchesParticipated;
  final int trainingsParticipated;
  final int meetingsParticipated;
  final int trainingsLast2WeeksPct;
  final int trainingsLast6WeeksPct;

  Member({
    required this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.position,
    this.profilePicture,
    this.isAccepted = false,
    this.userType = MemberType.player,
    this.matchesCalled = 0,
    this.trainingsCalled = 0,
    this.meetingsCalled = 0,
    this.matchesParticipated = 0,
    this.trainingsParticipated = 0,
    this.meetingsParticipated = 0,
    this.trainingsLast2WeeksPct = 0,
    this.trainingsLast6WeeksPct = 0,
  });

  Member copyWith({
    String? id,
    String? uid,
    String? name,
    String? email,
    String? position,
    String? profilePicture,
    bool? isAccepted,
    MemberType? userType,
    int? matchesCalled,
    int? trainingsCalled,
    int? meetingsCalled,
    int? matchesParticipated,
    int? trainingsParticipated,
    int? meetingsParticipated,
    int? trainingsLast2WeeksPct,
    int? trainingsLast6WeeksPct,
  }) {
    return Member(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      position: position ?? this.position,
      profilePicture: profilePicture ?? this.profilePicture,
      isAccepted: isAccepted ?? this.isAccepted,
      userType: userType ?? this.userType,
      matchesCalled: matchesCalled ?? this.matchesCalled,
      trainingsCalled: trainingsCalled ?? this.trainingsCalled,
      meetingsCalled: meetingsCalled ?? this.meetingsCalled,
      matchesParticipated: matchesParticipated ?? this.matchesParticipated,
      trainingsParticipated:
          trainingsParticipated ?? this.trainingsParticipated,
      meetingsParticipated: meetingsParticipated ?? this.meetingsParticipated,
      trainingsLast2WeeksPct:
          trainingsLast2WeeksPct ?? this.trainingsLast2WeeksPct,
      trainingsLast6WeeksPct:
          trainingsLast6WeeksPct ?? this.trainingsLast6WeeksPct,
    );
  }

  factory Member.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};

    final uid = data['uid'] as String? ?? snap.id;
    final name = (data['name'] as String?)?.trim() ?? 'Okänt namn';
    final email = (data['email'] as String?)?.trim() ?? '';

    final rawRoles = data['roles'];
    String position;
    if (rawRoles is List && rawRoles.isNotEmpty && rawRoles.first is String) {
      position = (rawRoles.first as String).trim();
    } else {
      position = '';
    }

    final rawType = data['userType'] as String?;
    final userType = _parseUserType(rawType);

    final picRaw = data['profilePicture'] as String?;
    final profilePicture =
        (picRaw != null && picRaw.isNotEmpty) ? picRaw : null;

    return Member(
      id: snap.id,
      uid: uid,
      name: name,
      email: email,
      position: position,
      profilePicture: profilePicture,
      isAccepted: data['isAccepted'] as bool? ?? false,
      userType: userType,
      matchesCalled: data['matchesCalled'] ?? 0,
      trainingsCalled: data['trainingsCalled'] ?? 0,
      meetingsCalled: data['meetingsCalled'] ?? 0,
      matchesParticipated: data['matchesParticipated'] ?? 0,
      trainingsParticipated: data['trainingsParticipated'] ?? 0,
      meetingsParticipated: data['meetingsParticipated'] ?? 0,

      // Dessa rader saknades!
      trainingsLast2WeeksPct: data['trainingsLast2WeeksPct'] ?? 0,
      trainingsLast6WeeksPct: data['trainingsLast6WeeksPct'] ?? 0,
    );
  }

Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'roles': [position],
      // Använd guest för nyinlagda gäster
      'userType': userType == MemberType.leader
          ? 'ledare'
          : userType == MemberType.guest
              ? 'gäst'
              : 'spelare',
      'profilePicture': profilePicture,
      'isAccepted': isAccepted,
      'matchesCalled': matchesCalled,
      'trainingsCalled': trainingsCalled,
      'meetingsCalled': meetingsCalled,
      'matchesParticipated': matchesParticipated,
      'trainingsParticipated': trainingsParticipated,
      'meetingsParticipated': meetingsParticipated,
      'trainingsLast2WeeksPct': trainingsLast2WeeksPct,
      'trainingsLast6WeeksPct': trainingsLast6WeeksPct,
    };
  }
  static MemberType _parseUserType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'spelare':
        return MemberType.player;
      case 'ledare':
        return MemberType.leader;
      default:
        return MemberType.player;
    }
  }
}
