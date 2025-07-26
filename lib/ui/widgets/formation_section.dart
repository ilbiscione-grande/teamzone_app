// lib/features/home/presentation/widgets/formation_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/core/providers/user_session.dart';
import '../screens/formation_editor.dart';
import '../screens/formation_viewer.dart';

class FormationSection extends ConsumerStatefulWidget {
  final String eventId;
  final int showOffsetHours;

  const FormationSection({
    Key? key,
    required this.eventId,
    this.showOffsetHours = 12,
  }) : super(key: key);

  @override
  ConsumerState<FormationSection> createState() => _FormationSectionState();
}

class _FormationSectionState extends ConsumerState<FormationSection> {
  late String _imageUrl;
  late Future<DateTime> _startTimeFuture;
  int? _visibleHoursOverride;

  @override
  void initState() {
    super.initState();
    _generateImageUrl();
    _startTimeFuture = _loadStartAndOffset();
  }

  void _generateImageUrl() {
    _imageUrl =
        'https://firebasestorage.googleapis.com/v0/b/teamzoneapp.firebasestorage.app'
        '/o/formation_images%2F${widget.eventId}.png'
        '?alt=media&ts=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<DateTime> _loadStartAndOffset() async {
    final db = ref.read(firestoreProvider);
    final doc = await db.collection('events').doc(widget.eventId).get();
    final data = doc.data();
    if (data == null || data['eventDate'] == null) {
      throw Exception('Event saknar startTime');
    }
    if (data['formationPublic'] != null) {
      _visibleHoursOverride = data['formationPublic'] as int?;
    }
    final original = (data['eventDate'] as Timestamp).toDate();
    // You had hardcoded 19:15 as release anchor; keep or adapt:
    return DateTime(original.year, original.month, original.day, 19, 15);
  }

  Future<void> _openEditor() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FormationEditorPage(eventId: widget.eventId),
      ),
    );
    setState(() {
      _generateImageUrl();
      _startTimeFuture = _loadStartAndOffset();
    });
  }

  Future<void> _openViewer() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => FormationViewerPage(eventId: widget.eventId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('yyyy-MM-dd');

    // Watch auth & session once per build:
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final isAdmin = session.isAdmin;

    return FutureBuilder<DateTime>(
      future: _startTimeFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return SizedBox(
            height: 250,
            child: Center(child: Text('Fel: ${snap.error}')),
          );
        }

        final start = snap.data!;
        final offset = _visibleHoursOverride ?? widget.showOffsetHours;
        final threshold = start.subtract(Duration(hours: offset));
        final now = DateTime.now();
        final canView = isAdmin || now.isAfter(threshold);
        final releaseTime = threshold.toLocal();
        final timeStr = timeFmt.format(releaseTime);
        final dateStr = dateFmt.format(releaseTime);

        return Column(
          children: [
            GestureDetector(
              onTap: canView ? (isAdmin ? _openEditor : _openViewer) : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 250,
                    child:
                        canView
                            ? Image.network(
                              _imageUrl,
                              key: ValueKey(_imageUrl),
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, __, ___) => Image.asset(
                                    'assets/football_pitch_vertical.png',
                                    fit: BoxFit.contain,
                                  ),
                            )
                            : Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  'assets/football_pitch_vertical.png',
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: 250,
                                ),
                                Text(
                                  'Formationen släpps kl $timeStr den $dateStr',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                    backgroundColor: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                  ),
                  if (isAdmin)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: _openEditor,
                        icon: const Icon(Icons.edit, color: Colors.white),
                      ),
                    ),
                  if (!isAdmin && canView)
                    const Icon(Icons.zoom_in, size: 32, color: Colors.white70),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
