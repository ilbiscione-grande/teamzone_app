import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FormationViewerPage extends StatelessWidget {
  final String eventId;
  const FormationViewerPage({Key? key, required this.eventId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hämta URL från Firebase Storage
    final futureUrl = FirebaseStorage.instance
        .ref('formation_images/$eventId.png')
        .getDownloadURL();

    return FutureBuilder<String>(
      future: futureUrl,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Kunde inte ladda bilden: ${snap.error}')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Formation')),
          body: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.network(snap.data!),
            ),
          ),
        );
      },
    );
  }
}
