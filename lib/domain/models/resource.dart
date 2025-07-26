// lib/models/resource.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ResourceType { pdf, image }

class Resource {
  final String id;
  final String name;
  final String url;
  final ResourceType type;

  Resource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
  });

  factory Resource.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return Resource(
      id: snap.id,
      name: data['name'] as String,
      url: data['url'] as String,
      type: ResourceType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'] as String,
        orElse: () => ResourceType.pdf,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'type': type.toString().split('.').last,
    };
  }
}
