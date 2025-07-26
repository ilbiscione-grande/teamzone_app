// lib/models/analysis.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum AnalysisType { pdf, image }

class Analysis {
  final String id;
  final String name;
  final String url;
  final AnalysisType type;

  Analysis({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
  });

  factory Analysis.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return Analysis(
      id: snap.id,
      name: data['name'] as String,
      url: data['url'] as String,
      type: AnalysisType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'] as String,
        orElse: () => AnalysisType.pdf,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'url': url, 'type': type.toString().split('.').last};
  }
}
