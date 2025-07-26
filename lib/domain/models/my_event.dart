// lib/models/my_event.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Definierar typer av aktiviteter
enum EventType { match, training, other }

class MyEvent {
  /// Unikt ID
  final String id;

  /// Hur vi kategoriserar internt (Match, Training eller Other)
  final EventType type;

  /// Spara den råa strängen som stod i Firestore (t.ex. "Match", "Training", "Meeting")
  final String rawType;

  /// Starttid
  final DateTime start;

  /// Längd i minuter (från Firestore)
  final int durationMinutes;

  /// Område, bana och ort för eventets plats
  final String area;
  final String pitch;
  final String town;

  /// Valfri beskrivning
  final String description;

  /// Samlingstid (för träning och match)
  final DateTime? gatheringTime;

  /// Plan/fält (för träning och match)
  final String? field;

  /// Coachens notering (för träning och match)
  final String? coachNote;

  /// Motståndare (endast för match)
  final String opponent;

  /// Typ av match, t.ex. 'Ligamatch', 'Cupmatch'
  final String? matchType;

  /// Hemma (true) eller borta (false)
  final bool isHome;

  /// Vårt lags mål
  final int? ourGoals;

  /// Motståndarlagets mål
  final int? opponentGoals;

  MyEvent({
    required this.id,
    required this.type,
    required this.rawType,
    required this.start,
    required this.durationMinutes,
    required this.area,
    required this.pitch,
    required this.town,
    required this.description,
    this.gatheringTime,
    this.field,
    this.coachNote,
    this.opponent = '',
    this.matchType,
    this.isHome = true,
    this.ourGoals,
    this.opponentGoals,
  });

  /// Beräknad längd som Duration
  Duration get duration => Duration(minutes: durationMinutes);

  /// Konverterar sträng från Firestore till enum
  static EventType _parseEventType(String raw) {
    switch (raw.toLowerCase()) {
      case 'match':
        return EventType.match;
      case 'training':
      case 'träning':
        return EventType.training;
      default:
        return EventType.other;
    }
  }

  /// Skapar en instans från ett Firestore-dokument
  factory MyEvent.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    final raw = data['eventType'] as String? ?? '';
    final startTs = data['eventDate'] as Timestamp;
    final gatheringTs = data['gatheringTime'] as Timestamp?;

    // Check if its a match and then set the match length to duration +15 min for half time break
    final durationMin =
        data['eventType'] == 'Match'
            ? data['duration'] + 15
            : data['duration'] as int? ?? 60;

    return MyEvent(
      id: snap.id,
      type: _parseEventType(raw),
      rawType: raw,
      start: startTs.toDate(),
      durationMinutes: durationMin,
      area: data['area'] as String? ?? '',
      pitch: data['pitch'] as String? ?? '',
      town: data['town'] as String? ?? '',
      description: data['description'] as String? ?? '',
      gatheringTime: gatheringTs?.toDate(),
      field: data['field'] as String?,
      coachNote: data['coachNote'] as String?,
      opponent: data['opponent'] as String? ?? '',
      matchType: data['matchType'] as String?,
      isHome: data['isHome'] as bool? ?? true,
      ourGoals: data.containsKey('ourScore') ? data['ourScore'] as int? : null,
      opponentGoals:
          data.containsKey('opponentScore')
              ? data['opponentScore'] as int?
              : null,
    );
  }

  /// Konverterar till karta för Firestore
  Map<String, dynamic> toDocument() {
    final data = {
      'eventType': rawType,
      'eventDate': Timestamp.fromDate(start),
      'duration': durationMinutes,
      'area': area,
      'pitch': pitch,
      'town': town,
      'description': description,
      'gatheringTime':
          gatheringTime != null ? Timestamp.fromDate(gatheringTime!) : null,
      'field': field,
      'coachNote': coachNote,
      'opponent': opponent,
      'matchType': matchType,
      'isHome': isHome,
    };

    if (ourGoals != null) data['ourScore'] = ourGoals;
    if (opponentGoals != null) data['opponentScore'] = opponentGoals;

    return data;
  }
}
