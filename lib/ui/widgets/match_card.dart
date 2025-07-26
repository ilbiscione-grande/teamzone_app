import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const MatchCard({Key? key, required this.match}) : super(key: key);

  factory MatchCard.fromMap(Map<String, dynamic> data) {
    return MatchCard(match: data);
  }

  @override
  Widget build(BuildContext context) {
    // Datum
    final ts = match['eventDate'] as Timestamp;
    final date = ts.toDate();

    // Motståndare
    final opponent = match['opponent'] as String? ?? '';

    // Hämta de råa värdena (null om fältet inte finns)
    final dynamic ourScoreVal =
        match.containsKey('ourScore') ? match['ourScore'] : null;
    final dynamic opponentScoreVal =
        match.containsKey('opponentScore') ? match['opponentScore'] : null;

    late final String scoreText;
    late final Color scoreColor;

    if (ourScoreVal != null && opponentScoreVal != null) {
      // Båda poängen finns – konvertera till int
      final int ourScore =
          ourScoreVal is num
              ? ourScoreVal.toInt()
              : int.tryParse(ourScoreVal.toString()) ?? 0;
      final int oppScore =
          opponentScoreVal is num
              ? opponentScoreVal.toInt()
              : int.tryParse(opponentScoreVal.toString()) ?? 0;

      scoreText = '$ourScore – $oppScore';
      scoreColor =
          ourScore > oppScore
              ? Colors.green.shade300
              : ourScore < oppScore
              ? Colors.red.shade300
              : Colors.grey.shade300;
    } else {
      // Saknas poäng
      scoreText = 'N/A';
      scoreColor = Colors.grey.shade300;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const Icon(Icons.sports_soccer),
        title: Text(
          opponent,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${date.day}/${date.month}/${date.year}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: scoreColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            scoreText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
