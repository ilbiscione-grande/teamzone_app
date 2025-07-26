// lib/core/providers/invite_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';

/// Invite‐modell
class Invite {
  final String id, teamId, email, code, status, invitedBy;
  final int sentCount;
  final DateTime invitedAt, lastSentAt;
  final DateTime? acceptedAt;

  Invite({
    required this.id,
    required this.teamId,
    required this.email,
    required this.code,
    required this.status,
    required this.invitedBy,
    required this.sentCount,
    required this.invitedAt,
    required this.lastSentAt,
    this.acceptedAt,
  });

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Invite(
      id: doc.id,
      teamId: d['teamId'] as String,
      email: d['email'] as String,
      code: d['code'] as String,
      status: d['status'] as String,
      invitedBy: d['invitedBy'] as String,
      sentCount: (d['sentCount'] as int?) ?? 1,
      invitedAt: (d['invitedAt'] as Timestamp).toDate(),
      lastSentAt: (d['lastSentAt'] as Timestamp).toDate(),
      acceptedAt: d['acceptedAt'] != null
          ? (d['acceptedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Typedef för Reader‐funktionen från Riverpod
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// InviteProvider som använder den konfigurerade Firestore‐instansen
class InviteProvider extends ChangeNotifier {
  final Reader read;
  InviteProvider(this.read);

  /// Hämta rätt 'invites'‐kollektion via din firestoreProvider
  CollectionReference<Map<String, dynamic>> get _coll =>
      read(firestoreProvider).collection('invites');

  List<Invite> _invites = [];
  List<Invite> get invites => List.unmodifiable(_invites);

  /// Hämtar invites för ett givet team
  Future<void> fetchForTeam(String teamId) async {
    final snap = await _coll
        .where('teamId', isEqualTo: teamId)
        .orderBy('invitedAt', descending: true)
        .get();
    _invites = snap.docs.map((d) => Invite.fromDoc(d)).toList();
    notifyListeners();
  }

  /// Skapar en ny invite (admin)
  Future<void> createInvite({
    required String teamId,
    required String email,
    required String invitedBy,
  }) async {
    final now = FieldValue.serverTimestamp();
    final docRef = _coll.doc();
    final code = docRef.id;
    await docRef.set({
      'teamId': teamId,
      'email': email,
      'code': code,
      'status': 'pending',
      'invitedBy': invitedBy,
      'invitedAt': now,
      'lastSentAt': now,
      'sentCount': 1,
    });
    await fetchForTeam(teamId);
  }

  /// Skickar om en invite
  Future<void> resendInvite(Invite inv) async {
    final now = FieldValue.serverTimestamp();
    await _coll.doc(inv.id).update({
      'lastSentAt': now,
      'sentCount': inv.sentCount + 1,
    });
    await fetchForTeam(inv.teamId);
  }

  /// Accepterar en invite (användarflöde)
  Future<void> acceptInvite(String inviteId) async {
    final now = FieldValue.serverTimestamp();
    await _coll.doc(inviteId).update({
      'status': 'accepted',
      'acceptedAt': now,
    });
    // ingen automatisk fetch här
  }
}

/// Riverpod‐provider för InviteProvider
final inviteProvider =
    ChangeNotifierProvider<InviteProvider>((ref) => InviteProvider(ref.read));
