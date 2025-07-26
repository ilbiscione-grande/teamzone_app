// lib/features/home/presentation/widgets/team_image_uploader.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';

class TeamImageUploader extends ConsumerStatefulWidget {
  final String teamId;
  final bool isAdmin;
  const TeamImageUploader({
    Key? key,
    required this.teamId,
    required this.isAdmin,
  }) : super(key: key);

  @override
  ConsumerState<TeamImageUploader> createState() => _TeamImageUploaderState();
}

class _TeamImageUploaderState extends ConsumerState<TeamImageUploader> {
  bool _uploading = false;

  // remove the invalid db field initializer

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    final file = File(picked.path);
    final storageRef = FirebaseStorage.instance.ref().child(
      'team_images/${widget.teamId}.jpg',
    );

    try {
      final snapshot = await storageRef.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // now you can safely read db here
      final db = ref.read(firestoreProvider);
      await db.collection('teams').doc(widget.teamId).update({
        'imageUrl': downloadUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Misslyckades ladda upp bilden: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // you can also grab db here if you need
    final db = ref.read(firestoreProvider);
    final teamsRef = db.collection('teams');

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: teamsRef.doc(widget.teamId).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? {};
          final imageUrl = data['imageUrl'] as String? ?? '';
          final clubName = data['clubName'] as String? ?? '';
          final teamName = data['teamName'] as String? ?? '';

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: InkWell(
                  onTap: widget.isAdmin && !_uploading ? _pickAndUpload : null,
                  child:
                      imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(color: Colors.grey[300]),
                ),
              ),
              if (_uploading) const Center(child: CircularProgressIndicator()),
              const Align(
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SizedBox(height: 60),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.black26,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              clubName.isNotEmpty ? clubName : '–',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              teamName.isNotEmpty ? teamName : '–',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isAdmin && !_uploading)
                        IconButton(
                          icon: const Icon(Icons.camera_alt),
                          color: Colors.white,
                          onPressed: _pickAndUpload,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
