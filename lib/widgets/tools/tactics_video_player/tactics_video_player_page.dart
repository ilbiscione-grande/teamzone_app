// lib/ui/pages/tools/tactics_video_player/tactics_video_player_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'tactics_board.dart';
import 'bottom_menu.dart';

class BallData {}

class TacticsVideoPlayerPage extends StatefulWidget {
  const TacticsVideoPlayerPage({Key? key}) : super(key: key);

  @override
  _TacticsVideoPlayerPageState createState() => _TacticsVideoPlayerPageState();
}

class _TacticsVideoPlayerPageState extends State<TacticsVideoPlayerPage> {
  late final List<Player> _bluePlayers;
  late final List<Player> _redPlayers;
  List<Frame> _frames = [];
  int _current = 0;
  bool _playing = false;
  Timer? _playTimer;

  // NYTT: Rörelselinjer att visa mellan frames
  List<StraightLine> _movementLines = [];

  // Nu dynamisk animations-duration
  Duration _frameAnimDuration = const Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _bluePlayers = List.generate(
      11,
      (i) => Player(
        number: i + 1,
        teamColor: const Color.fromARGB(255, 33, 15, 198),
        relX: 0.5,
        relY: 0.5,
      ),
    );
    _redPlayers = List.generate(
      11,
      (i) => Player(
        number: i + 1,
        teamColor: const Color.fromARGB(255, 153, 16, 75),
        relX: 0.5,
        relY: 0.5,
      ),
    );
    _frames = [
      Frame(shapes: [], straightLines: [], freehandLines: [], players: []),
    ];
  }

  // --------------------------------------------------
  // 1) Spara frames som JSON
  Future<void> _saveFrames() async {
    try {
      // 1) Hämta appens documents-katalog och existerande .json-filer
      final dir = await getApplicationDocumentsDirectory();
      final files =
          Directory(dir.path)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.json'))
              .toList();
      final existingNames =
          files.map((f) => p.basenameWithoutExtension(f.path)).toList();

      // 2) Visa dialog med lista + textfält
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String name =
              existingNames.isNotEmpty
                  ? existingNames.first
                  : 'tactics_${DateTime.now().millisecondsSinceEpoch}';
          // Använd en lokal TextEditingController
          final controller = TextEditingController(text: name);

          return StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: Text('Välj fil eller ange nytt namn'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existingNames.isNotEmpty)
                      DropdownButton<String>(
                        isExpanded: true,
                        value: name,
                        items:
                            existingNames
                                .map(
                                  (n) => DropdownMenuItem<String>(
                                    value: n,
                                    child: Text(n),
                                  ),
                                )
                                .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setState(() {
                              name = v;
                              controller.text = v;
                            });
                          }
                        },
                      ),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'filnamn (utan .json)',
                      ),
                      controller: controller,
                      onChanged: (v) => name = v,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Avbryt'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(name.trim()),
                    child: Text('Spara'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (result == null || result.isEmpty) return;
      final fileName = result;

      // 3) Skriv filen (skrivs över om redan finns)
      final path = '${dir.path}/$fileName.json';
      final jsonStr = jsonEncode(_frames.map((f) => f.toJson()).toList());
      await File(path).writeAsString(jsonStr);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sparat till: $fileName.json')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Misslyckades spara: $e')));
    }
  }

  // 2) Ladda frames från tidigare sparad JSON
  Future<void> _loadFrames() async {
    try {
      // 1) Hämta katalogen
      final dir = await getApplicationDocumentsDirectory();
      final files =
          Directory(dir.path)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.json'))
              .toList();

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inga sparade JSON-filer hittades.')),
        );
        return;
      }

      // 2) Visa dialog med filnamn
      final selected = await showDialog<File?>(
        context: context,
        builder:
            (ctx) => SimpleDialog(
              title: Text('Välj fil att öppna'),
              children:
                  files.map((file) {
                    final name = file.uri.pathSegments.last;
                    return SimpleDialogOption(
                      child: Text(name),
                      onPressed: () => Navigator.of(ctx).pop(file),
                    );
                  }).toList(),
            ),
      );
      if (selected == null) return; // användaren avbröt

      // 3) Läs och deserialisera
      final str = await selected.readAsString();
      final list = jsonDecode(str) as List<dynamic>;
      setState(() {
        _frames =
            list
                .cast<Map<String, dynamic>>()
                .map((m) => Frame.fromJson(m))
                .toList();
        _current = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laddade ${_frames.length} frames')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Misslyckades läsa in: $e')));
    }
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  // Uppdaterad goTo med rörelselinjer
  void _goTo(int idx) {
    if (idx < 0 || idx >= _frames.length) return;

    final oldIndex = _current;
    final oldF = _frames[oldIndex];
    final newF = _frames[idx];

    final lines = <StraightLine>[];

    // Bara om vi går framåt exakt ett steg
    if (idx == oldIndex + 1) {
      for (int i = 0; i < newF.players.length; i++) {
        final pOld = oldF.players[i];
        final pNew = newF.players[i];
        if (pOld.relX != pNew.relX || pOld.relY != pNew.relY) {
          lines.add(
            StraightLine(
              start: Offset(pOld.relX, pOld.relY),
              end: Offset(pNew.relX, pNew.relY),
              type: LineType.solid,
              color: pNew.teamColor.withOpacity(0.6),
              strokeWidth: 6.0,
            ),
          );
        }
      }
    }

    setState(() {
      _movementLines = lines;
      _current = idx;
    });
  }

  void _play() {
    if (_playing || _frames.isEmpty) return;
    setState(() => _playing = true);
    _playTimer = Timer.periodic(_frameAnimDuration, (_) {
      if (_current >= _frames.length - 1)
        _pause();
      else
        _goTo(_current + 1);
    });
  }

  void _pause() {
    _playTimer?.cancel();
    setState(() => _playing = false);
  }

  void _onPlayerDropped(Player p, Offset pos, Size size) {
    final rx = (pos.dx / size.width).clamp(0.0, 1.0);
    final ry = (pos.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _frames =
          _frames.map((f) {
            if (f.players.any(
              (q) => q.number == p.number && q.teamColor == p.teamColor,
            ))
              return f;
            return Frame(
              shapes: f.shapes,
              straightLines: f.straightLines,
              freehandLines: f.freehandLines,
              players: [...f.players, p.copyWith(relX: rx, relY: ry)],
            );
          }).toList();
    });
  }

  void _onBallDropped(Offset pos, Size size) {
    final rx = (pos.dx / size.width).clamp(0.0, 1.0);
    final ry = (pos.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _frames =
          _frames.map((f) {
            final exists = f.shapes.any(
              (s) =>
                  s.type == ShapeType.circle &&
                  (s.relX - rx).abs() < 1e-6 &&
                  (s.relY - ry).abs() < 1e-6,
            );
            if (exists) return f;
            return Frame(
              shapes: [
                ...f.shapes,
                Shape(
                  type: ShapeType.circle,
                  relX: rx,
                  relY: ry,
                  relWidth: 0.07,
                  relHeight: 0.07,
                  color: Colors.white,
                ),
              ],
              straightLines: f.straightLines,
              freehandLines: f.freehandLines,
              players: f.players,
            );
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final has = _frames.isNotEmpty;
    final maxIdx = has ? _frames.length - 1 : 0;
    final frame = _frames[_current];

    final unplacedBlue =
        _bluePlayers
            .where(
              (p) => frame.players.every(
                (q) => q.number != p.number || q.teamColor != p.teamColor,
              ),
            )
            .toList();
    final unplacedRed =
        _redPlayers
            .where(
              (p) => frame.players.every(
                (q) => q.number != p.number || q.teamColor != p.teamColor,
              ),
            )
            .toList();

    return Scaffold(
      backgroundColor: Colors.green,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── ÖVRE RAD ───
            Container(
              height: 60,
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var p in unplacedBlue)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Draggable<Player>(
                        data: p,
                        feedback: _buildPlayerIcon(p, 0.8),
                        child: _buildPlayerIcon(p, 1.0),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _buildPlayerIcon(p, 1.0),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Draggable<BallData>(
                      data: BallData(),
                      feedback: _buildBallIcon(32, 0.8),
                      child: _buildBallIcon(32, 1.0),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildBallIcon(32, 1.0),
                      ),
                    ),
                  ),
                  for (var p in unplacedRed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Draggable<Player>(
                        data: p,
                        feedback: _buildPlayerIcon(p, 0.8),
                        child: _buildPlayerIcon(p, 1.0),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _buildPlayerIcon(p, 1.0),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── PLAN + DRAGTARGET ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: DragTarget<Object>(
                  onAcceptWithDetails: (dt) {
                    final rb = context.findRenderObject() as RenderBox;
                    final local = rb.globalToLocal(dt.offset);
                    if (dt.data is Player)
                      _onPlayerDropped(dt.data as Player, local, rb.size);
                    else
                      _onBallDropped(local, rb.size);
                  },
                  builder:
                      (_, __, ___) => TacticsBoard(
                        shapes: frame.shapes,
                        straightLines: [
                          ...frame.straightLines,
                          ..._movementLines,
                        ],
                        freehandLines: frame.freehandLines,
                        players: frame.players,
                        animDuration: _frameAnimDuration,

                        onPlayerDragEnd: (i, x, y) {
                          final f2 = _frames[_current];
                          final ps = List<Player>.from(f2.players);
                          ps[i] = ps[i].copyWith(relX: x, relY: y);
                          setState(
                            () =>
                                _frames[_current] = Frame(
                                  shapes: f2.shapes,
                                  straightLines: f2.straightLines,
                                  freehandLines: f2.freehandLines,
                                  players: ps,
                                ),
                          );
                        },
                        onShapeDragEnd: (i, x, y) {
                          final f2 = _frames[_current];
                          final ss = List<Shape>.from(f2.shapes);
                          ss[i] = ss[i].copyWith(relX: x, relY: y);
                          setState(
                            () =>
                                _frames[_current] = Frame(
                                  shapes: ss,
                                  straightLines: f2.straightLines,
                                  freehandLines: f2.freehandLines,
                                  players: f2.players,
                                ),
                          );
                        },

                        onStraightLineDrawn: (s, e) {
                          setState(() {
                            final f2 = _frames[_current];
                            final ln = StraightLine(
                              start: s,
                              end: e,
                              type: LineType.solid,
                              color: Colors.white,
                              strokeWidth: 4.0,
                            );
                            _frames[_current] = Frame(
                              shapes: f2.shapes,
                              straightLines: [...f2.straightLines, ln],
                              freehandLines: f2.freehandLines,
                              players: f2.players,
                            );
                          });
                        },
                        onFreehandLineDrawn: (pts) {
                          setState(() {
                            final f2 = _frames[_current];
                            final fr = FreehandLine(
                              points: pts,
                              type: LineType.freeSolid,
                              color: Colors.white,
                              strokeWidth: 2.0,
                            );
                            _frames[_current] = Frame(
                              shapes: f2.shapes,
                              straightLines: f2.straightLines,
                              freehandLines: [...f2.freehandLines, fr],
                              players: f2.players,
                            );
                          });
                        },

                        onDeleteStraightLine: (i) {
                          setState(() {
                            final f2 = _frames[_current];
                            final list = List<StraightLine>.from(
                              f2.straightLines,
                            )..removeAt(i);
                            _frames[_current] = Frame(
                              shapes: f2.shapes,
                              straightLines: list,
                              freehandLines: f2.freehandLines,
                              players: f2.players,
                            );
                          });
                        },
                        onDeleteFreehandLine: (i) {
                          setState(() {
                            final f2 = _frames[_current];
                            final list = List<FreehandLine>.from(
                              f2.freehandLines,
                            )..removeAt(i);
                            _frames[_current] = Frame(
                              shapes: f2.shapes,
                              straightLines: f2.straightLines,
                              freehandLines: list,
                              players: f2.players,
                            );
                          });
                        },
                      ),
                ),
              ),
            ), // ─── NY NEDRE MENY ───
            BottomMenu(
              hasFrames: has,
              currentIndex: _current,
              maxIndex: maxIdx,
              isPlaying: _playing,
              onSave: _saveFrames,
              onLoad: _loadFrames,
              onFirst: () => _goTo(0),
              onPrevious: () => _goTo(_current - 1),
              onPlayPause: _playing ? _pause : _play,
              onNext: () => _goTo(_current + 1),
              onLast: () => _goTo(maxIdx),

              onAddFrame: () {
                setState(() {
                  final f = _frames[_current];
                  final newFrame = Frame(
                    shapes: f.shapes.map((s) => s.clone()).toList(),
                    straightLines: [],
                    freehandLines: [],
                    players: f.players.map((p) => p.clone()).toList(),
                  );
                  // Insertar direkt efter current
                  _frames.insert(_current + 1, newFrame);
                });
                // Flytta markören till den nya framen
                _goTo(_current + 1);
              },
              onRemoveFrame: () async {
                if (_frames.length < 2) return; // behåll minst en frame
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: Text('Ta bort frame?'),
                        content: Text(
                          'Är du säker på att du vill ta bort den aktuella framen?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text('Avbryt'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text('Ta bort'),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  setState(() {
                    _frames.removeAt(_current);
                    if (_current >= _frames.length) {
                      _current = _frames.length - 1;
                    }
                  });
                }
              },

              onSlide: (i) => _goTo(i),
              currentSpeed: _frameAnimDuration,
              onSpeedChange: (d) {
                setState(() => _frameAnimDuration = d);
                if (_playing) {
                  _playTimer?.cancel();
                  _play();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBallIcon(double size, double scale) => Transform.scale(
    scale: scale,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(Icons.sports_soccer, size: size * 0.8, color: Colors.black),
    ),
  );

  Widget _buildPlayerIcon(Player p, double scale) => Transform.scale(
    scale: scale,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: p.teamColor, shape: BoxShape.circle),
      child: Center(
        child: Text('${p.number}', style: TextStyle(color: Colors.white)),
      ),
    ),
  );
}
