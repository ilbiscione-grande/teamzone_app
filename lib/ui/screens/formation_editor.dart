import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:teamzone_app/core/providers/event_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/domain/models/member_callup.dart';
import 'package:teamzone_app/domain/models/member.dart';
import 'package:teamzone_app/application/services/player_stats_service.dart';
import 'package:teamzone_app/domain/models/callup.dart';         // for CallupStatus
import 'package:teamzone_app/core/providers/team_providers.dart'; 

class FormationEditorPage extends ConsumerStatefulWidget {
  final String eventId;
  const FormationEditorPage({super.key, required this.eventId});

  @override
  ConsumerState<FormationEditorPage> createState() =>
      _FormationEditorPageState();
}

class _FormationEditorPageState extends ConsumerState<FormationEditorPage> {
  final GlobalKey _previewKey = GlobalKey();
  bool _saving = false;
  MemberInfo? _currentlyDragging;
  int _visibleOffsetHours = 12;

  List<MemberInfo> availablePlayers = [];
  List<PlayerOnPitch> placedPlayers = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPlayersAndFormation();
  }

  Future<void> _shareFormation() async {
    try {
      setState(() => _saving = true);

      RenderRepaintBoundary boundary =
          _previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/formation.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Här är vår formation!');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunde inte dela: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _loadPlayersAndFormation() async {
    final db = ref.read(firestoreProvider);

    final callupsSnapshot =
        await db
            .collection('callups')
            .where('eventId', isEqualTo: widget.eventId)
            .where('status', whereIn: ['accepted', 'pending'])
            .get();

    // Gör en mapp från memberId -> callupId
    final callupMap = {
      for (var doc in callupsSnapshot.docs)
        (doc.data()['memberId'] as String): doc.id,
    };

    final memberIds =
        callupsSnapshot.docs
            .map((doc) => doc['memberId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

    final futures =
        memberIds.map((uid) async {
          final db = ref.read(firestoreProvider);

          final userDoc =
              await db
                  .collection('users')
                  .where('uid', isEqualTo: uid)
                  .limit(1)
                  .get();

          if (userDoc.docs.isNotEmpty) {
            final data = userDoc.docs.first.data();
            final uid = data['uid'];
            if (uid == null || uid.isEmpty) {
              print('⚠️ Användare utan uid i Firestore: ${data['name']}');
              return null;
            }
            return MemberInfo(
              uid: uid,
              name: data['name'] ?? 'Okänd',
              imageUrl: data['profilePicture'],
              callupId: callupMap[uid]!,
            );
          }
          return null;
        }).toList();

    final allPlayers =
        (await Future.wait(futures)).whereType<MemberInfo>().toList();

    final formationSnapshot =
        await db
            .collection('events')
            .doc(widget.eventId)
            .collection('formation')
            .get();

    final placed =
        formationSnapshot.docs.map((doc) {
          final data = doc.data();
          return PlayerOnPitch(
            uid: data['uid'] ?? '',
            name: data['name'],
            imageUrl: data['imageUrl'],
            callupId: doc.id,
            relX: (data['x'] as num).toDouble(),
            relY: (data['y'] as num).toDouble(),
          );
        }).toList();

    final eventDoc = await db.collection('events').doc(widget.eventId).get();

    if (mounted) {
      setState(() {
        placedPlayers = placed;
        availablePlayers =
            allPlayers
                .where((p) => !placed.any((pp) => pp.uid == p.uid))
                .toList();

        _visibleOffsetHours = eventDoc.data()?['formationPublic'] ?? 12;
      });
    }
  }

  void _resetPlayers() {
    setState(() {
      // Flytta tillbaka alla placerade till available
      for (final p in placedPlayers) {
        availablePlayers.add(
          MemberInfo(
            uid: p.uid,
            name: p.name,
            imageUrl: p.imageUrl,
            callupId: p.callupId,
          ),
        );
      }
      placedPlayers.clear();
    });
  }

  Future<void> _confirmDeletePlayer(
    MemberInfo info, {
    required bool onPitch,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ta bort kallelse'),
            content: Text('Vill du ta bort kallelsen för ${info.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Avbryt'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ta bort'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
await ref.read(eventRepositoryProvider).deleteCallupAndRollback(
  eventId:      widget.eventId,
  callupId:     info.callupId,
  memberId:     info.uid,
  participated: false,
  statsSvc:     ref.read(playerStatsServiceProvider),
);
         setState(() {
        if (onPitch) {
          placedPlayers.removeWhere((p) => p.uid == info.uid);
          availablePlayers.add(info);
        } else {
          availablePlayers.removeWhere((p) => p.uid == info.uid);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kallelsen för ${info.name} togs bort.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte ta bort kallelsen: $e')),
      );
    }
  }

  Future<void> _saveFormationToFirestore() async {
    final db = ref.read(firestoreProvider);

    final batch = db.batch();
    final formationRef = db
        .collection('events')
        .doc(widget.eventId)
        .collection('formation');

    final old = await formationRef.get();
    for (final doc in old.docs) {
      batch.delete(doc.reference);
    }

    for (final player in placedPlayers) {
      if (player.uid.isEmpty) {
        print('⚠️ Försöker spara spelare med tom uid: ${player.name}');
        continue;
      }
      final docRef = formationRef.doc(player.uid);
      batch.set(docRef, {
        'uid': player.uid,
        'name': player.name,
        'imageUrl': player.imageUrl,
        'x': player.relX,
        'y': player.relY,
      });
    }

    await batch.commit();
  }

  Future<void> _saveSnapshot() async {
    try {
      setState(() => _saving = true);
      await _saveFormationToFirestore();

      RenderRepaintBoundary boundary =
          _previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final ref = FirebaseStorage.instance
          .ref()
          .child('formation_images')
          .child('${widget.eventId}.png');

      await ref.putData(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Formationen sparad!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fel: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Anta pitch-bilden är 2:3 i förhållande
    const pitchRatio = 2 / 3;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1) Hela huvud-UI:n längst ner
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Tillbaka',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        DropdownButton<int>(
                          value: _visibleOffsetHours,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.timer),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              final db = ref.read(firestoreProvider);

                              setState(() => _visibleOffsetHours = newValue);
                              db
                                  .collection('events')
                                  .doc(widget.eventId)
                                  .update({'formationPublic': newValue});
                            }
                          },
                          items:
                              [
                                    0,
                                    1,
                                    2,
                                    3,
                                    4,
                                    5,
                                    6,
                                    7,
                                    8,
                                    9,
                                    10,
                                    11,
                                    12,
                                    13,
                                    14,
                                    15,
                                    16,
                                    17,
                                    18,
                                    19,
                                    20,
                                    21,
                                    22,
                                    23,
                                    24,
                                    25,
                                    26,
                                    27,
                                    28,
                                    29,
                                    30,
                                    31,
                                    32,
                                    33,
                                    34,
                                    35,
                                    36,
                                  ]
                                  .map(
                                    (val) => DropdownMenuItem(
                                      value: val,
                                      child: Text('$val h'),
                                    ),
                                  )
                                  .toList(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Nollställ',
                          onPressed: _resetPlayers,
                        ),
                        IconButton(
                          icon: const Icon(Icons.save),
                          tooltip: 'Spara',
                          onPressed: _saving ? null : _saveSnapshot,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: 'Dela formation',
                          onPressed: _saving ? null : _shareFormation,
                        ),
                      ],
                    ),
                  ),
                ),

                // Pitch + spelare
                Expanded(
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: AspectRatio(
                      aspectRatio: pitchRatio,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          return Stack(
                            children: [
                              // Bakgrunden
                              Image.asset(
                                'assets/football_pitch_vertical.png',
                                fit: BoxFit.fill,
                                width: w,
                                height: h,
                              ),

                              // Rendera spelare
                              for (var player in placedPlayers)
                                Positioned(
                                  left: player.relX * w,
                                  top: player.relY * h,
                                  child: Draggable<MemberInfo>(
                                    data: MemberInfo(
                                      uid: player.uid,
                                      name: player.name,
                                      imageUrl: player.imageUrl,
                                      callupId: player.callupId,
                                    ),
                                    feedback: _buildDragFeedback(
                                      MemberInfo(
                                        uid: player.uid,
                                        name: player.name,
                                        imageUrl: player.imageUrl,
                                        callupId: player.callupId,
                                      ),
                                    ),
                                    childWhenDragging: const SizedBox.shrink(),
                                    onDragStarted: () {
                                      setState(() {
                                        _currentlyDragging = MemberInfo(
                                          uid: player.uid,
                                          name: player.name,
                                          imageUrl: player.imageUrl,
                                          callupId: player.callupId,
                                        );
                                      });
                                    },
                                    onDragEnd: (_) {
                                      setState(() {
                                        _currentlyDragging = null;
                                      });
                                    },
                                    onDraggableCanceled: (velocity, offset) {
                                      // Flytta om på pitch via relativa coords
                                      final box =
                                          _previewKey.currentContext!
                                                  .findRenderObject()
                                              as RenderBox;
                                      final local = box.globalToLocal(offset);
                                      final relX = local.dx / w;
                                      final relY = local.dy / h;
                                      setState(() {
                                        player.relX = relX.clamp(0.0, 1.0);
                                        player.relY = relY.clamp(0.0, 1.0);
                                      });
                                      setState(() {
                                        _currentlyDragging = null;
                                      });
                                    },
                                    onDragCompleted: () {
                                      // om du vill ta bort också
                                      setState(() {
                                        _currentlyDragging = null;
                                      });
                                    },
                                    child: _buildPlayerWidget(
                                      MemberInfo(
                                        uid: player.uid,
                                        name: player.name,
                                        imageUrl: player.imageUrl,
                                        callupId: player.callupId,
                                      ),
                                      onPitch: true,
                                    ),
                                  ),
                                ),

                              // DragTarget för pitch
                              Positioned.fill(
                                child: DragTarget<MemberInfo>(
                                  onWillAccept: (_) => true,
                                  onAcceptWithDetails: (details) {
                                    final member = details.data;
                                    final box =
                                        _previewKey.currentContext!
                                                .findRenderObject()
                                            as RenderBox;
                                    final local = box.globalToLocal(
                                      details.offset,
                                    );
                                    final relX = local.dx / w;
                                    final relY = local.dy / h;

                                    setState(() {
                                      final idx = placedPlayers.indexWhere(
                                        (p) => p.uid == member.uid,
                                      );
                                      if (idx != -1) {
                                        // Omplacera
                                        placedPlayers[idx].relX = relX.clamp(
                                          0.0,
                                          1.0,
                                        );
                                        placedPlayers[idx].relY = relY.clamp(
                                          0.0,
                                          1.0,
                                        );
                                      } else {
                                        // Ny spelare
                                        placedPlayers.add(
                                          PlayerOnPitch(
                                            uid: member.uid,
                                            name: member.name,
                                            imageUrl: member.imageUrl,
                                            callupId: member.callupId,
                                            relX: relX.clamp(0.0, 1.0),
                                            relY: relY.clamp(0.0, 1.0),
                                          ),
                                        );
                                        availablePlayers.removeWhere(
                                          (p) => p.uid == member.uid,
                                        );
                                      }
                                    });
                                  },
                                  builder:
                                      (c, cand, rej) => const SizedBox.expand(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Divider(height: 1, color: Colors.grey.shade300),
                Text('Spelare', style: Theme.of(context).textTheme.titleSmall),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Column(
                    children: [
                      // Botten‐listan med två zoner
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 75,
                              child: Row(
                                children: [
                                  // 1) Den scrollbara zonen
                                  Expanded(
                                    child: DragTarget<MemberInfo>(
                                      onWillAccept: (_) => true,
                                      onAccept: (member) {
                                        // Lägg tillbaka spelaren när sparar i vänsterzon
                                        if (!availablePlayers.any(
                                          (p) => p.uid == member.uid,
                                        )) {
                                          setState(() {
                                            availablePlayers.add(member);
                                            placedPlayers.removeWhere(
                                              (p) => p.uid == member.uid,
                                            );
                                          });
                                        }
                                      },
                                      builder: (
                                        context,
                                        candidateData,
                                        rejectedData,
                                      ) {
                                        final isActive =
                                            candidateData.isNotEmpty;
                                        return Container(
                                          decoration:
                                              isActive
                                                  ? BoxDecoration(
                                                    color: Colors.blue
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  )
                                                  : null,
                                          child: ListView.builder(
                                            controller: _scrollController,
                                            scrollDirection: Axis.horizontal,
                                            itemCount: availablePlayers.length,
                                            itemBuilder: (context, index) {
                                              final player =
                                                  availablePlayers[index];
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 3.0,
                                                  left: 3.0,
                                                  right: 3.0,
                                                ),
                                                child: LongPressDraggable<
                                                  MemberInfo
                                                >(
                                                  data: player,
                                                  dragAnchorStrategy:
                                                      pointerDragAnchorStrategy,
                                                  onDragStarted:
                                                      () => setState(() {
                                                        _currentlyDragging =
                                                            player;
                                                      }),
                                                  onDraggableCanceled: (
                                                    velocity,
                                                    offset,
                                                  ) {
                                                    // din befintliga flytta‐logik...
                                                    setState(() {
                                                      _currentlyDragging = null;
                                                    });
                                                  },
                                                  onDragCompleted: () {
                                                    // om du vill ta bort också
                                                    setState(() {
                                                      _currentlyDragging = null;
                                                    });
                                                  },
                                                  onDragEnd:
                                                      (_) => setState(() {
                                                        _currentlyDragging =
                                                            null;
                                                      }),
                                                  feedback: _buildDragFeedback(
                                                    player,
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.3,
                                                    child: _buildPlayer(
                                                      player.name,
                                                      player.imageUrl,
                                                    ),
                                                  ),
                                                  child: _buildPlayer(
                                                    player.name,
                                                    player.imageUrl,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // 2) Soptunnan bara om någon drar
                                  if (_currentlyDragging != null) ...[
                                    DragTarget<MemberInfo>(
                                      onWillAccept: (_) => true,
                                      onAccept: (member) async {
                                        // Bekräfta och radera som tidigare
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Ta bort kallelse?',
                                                ),
                                                content: Text(
                                                  'Vill du ta bort kallelsen för ${member.name}?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Avbryt'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Ta bort',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        );
                                        if (confirm != true) return;

                                        try {
await ref.read(eventRepositoryProvider).deleteCallupAndRollback(
  eventId:      widget.eventId,
  callupId:     member.callupId,
  memberId:     member.uid,
  participated: false,
  statsSvc:     ref.read(playerStatsServiceProvider),
);                                         setState(() {
                                            availablePlayers.removeWhere(
                                              (p) => p.uid == member.uid,
                                            );
                                            placedPlayers.removeWhere(
                                              (p) => p.uid == member.uid,
                                            );
                                            _currentlyDragging = null;
                                          });
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Kallelsen för ${member.name} togs bort',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Kunde inte ta bort: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      builder: (
                                        context,
                                        candidateData,
                                        rejectedData,
                                      ) {
                                        final isActive =
                                            candidateData.isNotEmpty;
                                        return Container(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.4,
                                          height: double.infinity,
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isActive
                                                    ? Colors.red.withOpacity(
                                                      0.2,
                                                    )
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            size: 32,
                                            color:
                                                isActive
                                                    ? Colors.red
                                                    : Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2) Overlay när sparar
            if (_saving)
              Positioned.fill(
                child: Container(
                  color: Colors.grey.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save, size: 48, color: Colors.white),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sparar formation…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragFeedback(MemberInfo player) {
    return Material(
      elevation: 4,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24, // större avatar
              backgroundImage:
                  player.imageUrl != null
                      ? NetworkImage(player.imageUrl!)
                      : null,
              child:
                  player.imageUrl == null
                      ? const Icon(Icons.person, size: 24)
                      : null,
            ),
            const SizedBox(height: 20),
            Text(
              player.name, // hela namnet
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerWidget(MemberInfo info, {bool onPitch = false}) {
    return GestureDetector(
      onDoubleTap: () => _confirmDeletePlayer(info, onPitch: onPitch),
      child: _buildPlayer(info.name, info.imageUrl), // din befintliga
    );
  }

  Widget _buildPlayer(String name, String? imageUrl) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 4, bottom: 4, left: 3, right: 3),
          decoration: BoxDecoration(
            color: Color.fromARGB(225, 255, 255, 255),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black87,
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    (imageUrl != null && imageUrl.isNotEmpty)
                        ? NetworkImage(imageUrl)
                        : null,
                child:
                    (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 50,
                child: Text(
                  // Visa bara fornamnet
                  name.split(' ').first,
                  // Visa hela namnet över flera rader
                  // name.replaceAll(' ', '\n'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MemberInfo {
  final String uid;
  final String name;
  final String? imageUrl;
  final String callupId;

  MemberInfo({
    required this.uid,
    required this.name,
    this.imageUrl,
    required this.callupId,
  });
}

class PlayerOnPitch {
  final String uid;
  final String name;
  final String? imageUrl;
  final String callupId;
  double relX;
  double relY;

  PlayerOnPitch({
    required this.uid,
    required this.name,
    this.imageUrl,
    required this.callupId,
    required this.relX,
    required this.relY,
  });
}
