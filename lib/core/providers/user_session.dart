import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserSession extends ChangeNotifier {
  final String uid;
  final FirebaseFirestore _db;

  bool _isAdmin = false;
  String? _currentTeamId;
  String? _currentClubId;
  String? _clubLogoUrl;
  String? _clubName;
  String? _teamName;
  String _userRole = 'Medlem';
  String? _userName;
  String? _userPhotoUrl;
  Map<String, List<String>> _teamRolesMap = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _teamSub;

  UserSession(this.uid, this._db) {
    if (uid.isEmpty) return;

    // 1) Lyssna på users‐kollektionen
    _userSub = _db
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((q) {
      if (q.docs.isEmpty) return;
      final d = q.docs.first.data();

      _currentTeamId = d['currentTeamId'] as String?;
      _userName = d['name'] as String?;
      _userPhotoUrl = d['profilePicture'] as String?;

      final raw = d['teamRoles'] as Map<String, dynamic>? ?? {};
      _teamRolesMap = raw.map((k, v) =>
        MapEntry(k, (v as List).cast<String>())
      );

      _updateUserRole();
      notifyListeners();

      // 2) (Re)starta lyssning på det valda laget
      _teamSub?.cancel();
      if (_currentTeamId?.isNotEmpty == true) {
        _teamSub = _db
            .collection('teams')
            .doc(_currentTeamId)
            .snapshots()
            .listen(_onTeamUpdate);
      }
    });
  }

  void _onTeamUpdate(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return;
    final d = snap.data()!;

    _clubLogoUrl = d['clubLogo'] as String?;
    _currentClubId = d['clubId'] as String?;
    _clubName = d['clubName'] as String?;
    _teamName = d['teamName'] as String?;

    final admins = (d['teamAdmins'] as List<dynamic>?)?.cast<String>() ?? [];
    _isAdmin = admins.contains(uid);

    _updateUserRole();
    notifyListeners();
  }

  void _updateUserRole() {
    final tid = _currentTeamId;
    if (tid != null && _teamRolesMap.containsKey(tid)) {
      _userRole = _teamRolesMap[tid]!.join(', ');
    }
  }

  bool get isAdmin => _isAdmin;
  String get currentTeamId => _currentTeamId ?? '';
  String get currentClubId => _currentClubId ?? '';
  String get clubLogoUrl => _clubLogoUrl ?? '';
  String get clubName => _clubName ?? '';
  String get teamName => _teamName ?? '';
  String get userRole => _userRole;
  String get userName => _userName ?? '';
  String get userPhotoUrl => _userPhotoUrl ?? '';
  Map<String, List<String>> get teamRoles => _teamRolesMap;

  @override
  void dispose() {
    _userSub?.cancel();
    _teamSub?.cancel();
    super.dispose();
  }
}
