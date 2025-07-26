import 'package:cloud_firestore/cloud_firestore.dart';

/// Roller går att lagra per kallelse (om man vill)
enum MemberType { player, leader, guest }

/// Möjliga svar på en kallelse, inklusive "notCalled" som default för
/// de medlemmar som inte har någon kallelse sparad.
enum CallupStatus {
  notCalled, // ingen kallelse-dokument → inte kallad
  pending,   // kallelse skapad men inget svar
  accepted,
  declined,
}

class Callup {
  final String id;
  final String memberId;
  final String eventId;
  final MemberType type;
  final CallupStatus status;
  final bool participated;
  final String? profilePicture;

  Callup({
    required this.id,
    required this.memberId,
    required this.eventId,
    this.type = MemberType.player,
    this.status = CallupStatus.pending,
    required this.participated,
    this.profilePicture,
  });

  factory Callup.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};

    // Läs ut enkeldata
    final id = snap.id;
    final memberId = data['memberId'] as String? ?? '';
    final eventId = data['eventId'] as String? ?? '';
    final picRaw = data['profilePicture'] as String?;
    final profilePicture =
        (picRaw != null && picRaw.isNotEmpty) ? picRaw : null;

    // Parsar MemberType (player, leader, guest)
    final typeRaw = data['type'] as String? ?? '';
    final type = MemberType.values.firstWhere(
      (e) => e.toString().split('.').last == typeRaw,
      orElse: () => MemberType.player,
    );

    // Parsar CallupStatus
    final statusRaw = data['status'] as String? ?? '';
    final status = CallupStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusRaw,
      orElse: () => CallupStatus.notCalled,
    );

    // Parsar participated-flagga
    final participated = data['participated'] as bool? ?? false;

    return Callup(
      id: id,
      memberId: memberId,
      eventId: eventId,
      type: type,
      status: status,
      participated: participated,
      profilePicture: profilePicture,
    );
  }

  /// Konvertera till JSON för att skriva tillbaka till Firestore
  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'eventId': eventId,
        'profilePicture': profilePicture,
        // toString().split('.').last ger "player", "leader" eller "guest"
        'type': type.toString().split('.').last,
        'status': status.toString().split('.').last,
        'participated': participated,
      };
}
