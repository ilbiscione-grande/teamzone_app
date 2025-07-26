import 'package:flutter/foundation.dart';

class Member {
  final String name;
  final String email;
  final String role;
  final String currentTeamId;
  final bool isAdmin;

  Member({
    required this.name,
    required this.email,
    required this.role,
    required this.currentTeamId,
    required this.isAdmin,
  });
}

class MemberProvider extends ChangeNotifier {
  final List<Member> _members = [];

  List<Member> get members => List.unmodifiable(_members);

  void addMember(Member m) {
    _members.add(m);
    notifyListeners();
  }
}
