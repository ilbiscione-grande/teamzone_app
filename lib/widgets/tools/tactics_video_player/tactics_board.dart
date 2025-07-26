// lib/ui/pages/tools/tactics_video_player/tactics_board.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'models.dart';
import 'painters.dart';

class TacticsBoard extends StatefulWidget {
  final List<Shape> shapes;
  final List<StraightLine> straightLines;
  final List<FreehandLine> freehandLines;
  final List<Player> players;
  final Duration animDuration;

  final void Function(int, double, double) onPlayerDragEnd;
  final void Function(int, double, double) onShapeDragEnd;
  final void Function(Offset, Offset) onStraightLineDrawn;
  final void Function(List<Offset>) onFreehandLineDrawn;
  final void Function(int) onDeleteStraightLine;
  final void Function(int) onDeleteFreehandLine;

  const TacticsBoard({
    Key? key,
    required this.shapes,
    required this.straightLines,
    required this.freehandLines,
    required this.players,
    required this.onPlayerDragEnd,
    required this.onShapeDragEnd,
    required this.onStraightLineDrawn,
    required this.onFreehandLineDrawn,
    required this.onDeleteStraightLine,
    required this.onDeleteFreehandLine,
    this.animDuration = const Duration(milliseconds: 1200),
  }) : super(key: key);

  @override
  _TacticsBoardState createState() => _TacticsBoardState();
}

class _TacticsBoardState extends State<TacticsBoard> {
  late List<Player> _localPlayers;
  late List<Shape> _localShapes;

  int? _draggingIdx;
  Offset? _dragOffset;
  bool _dragIsPlayer = false;

  List<Offset> _draftPoints = [];
  Offset? _draftStraightTo;

  @override
  void initState() {
    super.initState();
    _localPlayers = widget.players.map((p) => p.clone()).toList();
    _localShapes = widget.shapes.map((s) => s.clone()).toList();
  }

  @override
  void didUpdateWidget(covariant TacticsBoard old) {
    super.didUpdateWidget(old);
    if (old.players != widget.players)
      _localPlayers = widget.players.map((p) => p.clone()).toList();
    if (old.shapes != widget.shapes)
      _localShapes = widget.shapes.map((s) => s.clone()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cons) {
        final w = cons.maxWidth, h = cons.maxHeight;

        final normal = <Shape>[], balls = <Shape>[];
        for (var s in _localShapes) {
          if (s.type == ShapeType.circle && s.color == Colors.white)
            balls.add(s);
          else
            normal.add(s);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanDown: _handlePanDown,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onLongPressStart: _handleLongPress,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/football_pitch_vertical.png',
                  fit: BoxFit.contain,
                ),
              ),
              CustomPaint(
                size: Size(w, h),
                painter: FramePainter(
                  shapes: normal,
                  straightLines: widget.straightLines,
                  freehandLines: widget.freehandLines,
                ),
              ),
              for (int i = 0; i < _localPlayers.length; i++)
                _buildPlayer(_localPlayers[i], i, w, h),
              for (int i = 0; i < balls.length; i++)
                _buildBall(balls[i], i, w, h),
              if (_draftStraightTo != null)
                CustomPaint(
                  size: Size(w, h),
                  painter: StraightLinePainter(
                    start: _draftPoints.first,
                    end: _draftStraightTo!,
                    type: LineType.solid,
                    color: Colors.yellow.withOpacity(.6),
                    strokeWidth: 4.0,
                  ),
                ),
              if (_draftPoints.length > 1)
                CustomPaint(
                  size: Size(w, h),
                  painter: FreehandLinePainter(
                    points: _draftPoints,
                    type: LineType.freeSolid,
                    color: Colors.yellow.withOpacity(.6),
                    strokeWidth: 2.0,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handlePanDown(DragDownDetails details) {
    final local = details.localPosition;
    const padding = 10.0;
    bool hit = false;

    // Ball hit
    for (int i = 0; i < _localShapes.length; i++) {
      final s = _localShapes[i];
      if (s.type == ShapeType.circle && s.color == Colors.white) {
        final bx = s.relX * context.size!.width;
        final by = s.relY * context.size!.height;
        final dia = min(
          s.relWidth * context.size!.width,
          s.relHeight * context.size!.height,
        );
        final rect = Rect.fromCenter(
          center: Offset(bx, by),
          width: dia + padding * 2,
          height: dia + padding * 2,
        );
        if (rect.contains(local)) {
          _draggingIdx = i;
          _dragOffset = local - Offset(bx, by);
          _dragIsPlayer = false;
          hit = true;
          break;
        }
      }
    }
    if (hit) return;

    // Player hit
    for (int i = 0; i < _localPlayers.length; i++) {
      final p = _localPlayers[i];
      final px = p.relX * context.size!.width;
      final py = p.relY * context.size!.height;
      final rect = Rect.fromCenter(
        center: Offset(px, py),
        width: 40 + padding * 2,
        height: 40 + padding * 2,
      );
      if (rect.contains(local)) {
        _draggingIdx = i;
        _dragOffset = local - Offset(px, py);
        _dragIsPlayer = true;
        hit = true;
        break;
      }
    }
    if (!hit) {
      _draftPoints = [local];
      _draftStraightTo = local;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final local = details.localPosition;
    if (_draftPoints.isNotEmpty) {
      setState(() {
        _draftPoints.add(local);
        _draftStraightTo = local;
      });
    } else if (_draggingIdx != null) {
      setState(() {
        final newLocal = local - _dragOffset!;
        final rx = (newLocal.dx / context.size!.width).clamp(0.0, 1.0);
        final ry = (newLocal.dy / context.size!.height).clamp(0.0, 1.0);
        if (_dragIsPlayer) {
          final p = _localPlayers[_draggingIdx!];
          _localPlayers[_draggingIdx!] = p.copyWith(relX: rx, relY: ry);
        } else {
          final s = _localShapes[_draggingIdx!];
          _localShapes[_draggingIdx!] = s.copyWith(relX: rx, relY: ry);
        }
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draftPoints.isNotEmpty) {
      final start = _draftPoints.first;
      final end = _draftPoints.last;
      final w = context.size!.width;
      final h = context.size!.height;

      // Justerade trösklar för rak vs frihand:
      const int maxStraightPoints = 8; // högst 3 punkter → straight
      const double straightThreshold = 15; // px-tolerans från linjen

      final isStraight =
          _draftPoints.length <= maxStraightPoints ||
          _draftPoints.every(
            (p) => _distanceToLine(start, end, p) < straightThreshold,
          );

      if (isStraight) {
        widget.onStraightLineDrawn(
          Offset(start.dx / w, start.dy / h),
          Offset(end.dx / w, end.dy / h),
        );
      } else {
        widget.onFreehandLineDrawn(
          _draftPoints.map((p) => Offset(p.dx / w, p.dy / h)).toList(),
        );
      }

      setState(() {
        _draftPoints = [];
        _draftStraightTo = null;
      });
    } else if (_draggingIdx != null) {
      if (_dragIsPlayer) {
        final p = _localPlayers[_draggingIdx!];
        widget.onPlayerDragEnd(_draggingIdx!, p.relX, p.relY);
      } else {
        final s = _localShapes[_draggingIdx!];
        widget.onShapeDragEnd(_draggingIdx!, s.relX, s.relY);
      }
      _draggingIdx = null;
    }
  }

  void _handleLongPress(LongPressStartDetails details) {
    final local = details.localPosition;
    final w = context.size!.width;
    final h = context.size!.height;
    const threshold = 8.0;

    // Check straight lines
    for (int i = 0; i < widget.straightLines.length; i++) {
      final L = widget.straightLines[i];
      final a = Offset(L.start.dx * w, L.start.dy * h);
      final b = Offset(L.end.dx * w, L.end.dy * h);
      if (_distanceToLine(a, b, local) < threshold) {
        _confirmDelete(context, 'Ta bort rak linje?', () {
          widget.onDeleteStraightLine(i);
        });
        return;
      }
    }
    // Check freehand lines
    for (int i = 0; i < widget.freehandLines.length; i++) {
      final pts =
          widget.freehandLines[i].points
              .map((p) => Offset(p.dx * w, p.dy * h))
              .toList();
      for (int j = 0; j < pts.length - 1; j++) {
        if (_distanceToLine(pts[j], pts[j + 1], local) < threshold) {
          _confirmDelete(context, 'Ta bort frihandslinje?', () {
            widget.onDeleteFreehandLine(i);
          });
          return;
        }
      }
    }
  }

  void _confirmDelete(BuildContext ctx, String title, VoidCallback onYes) {
    showDialog<bool>(
      context: ctx,
      builder:
          (dctx) => AlertDialog(
            title: Text(title),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: Text('Avbryt'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dctx).pop(true);
                  onYes();
                },
                child: Text('Ta bort'),
              ),
            ],
          ),
    );
  }

  double _distanceToLine(Offset a, Offset b, Offset p) {
    final num =
        ((p.dx - a.dx) * (b.dy - a.dy) - (p.dy - a.dy) * (b.dx - a.dx)).abs();
    final den = sqrt(pow(b.dx - a.dx, 2) + pow(b.dy - a.dy, 2));
    return num / den;
  }

  Widget _buildBall(Shape s, int idx, double w, double h) {
    final left = s.relX * w;
    final top = s.relY * h;
    final dia = min(s.relWidth * w / 2, s.relHeight * h / 2);
    final dragging = (!_dragIsPlayer && _draggingIdx == idx);
    return dragging
        ? Positioned(
          left: left,
          top: top,
          width: dia,
          height: dia,
          child: _ballChild(dia),
        )
        : AnimatedPositioned(
          key: ValueKey('ball_$idx'),
          duration: widget.animDuration,
          curve: Curves.easeInOut,
          left: left,
          top: top,
          width: dia,
          height: dia,
          child: _ballChild(dia),
        );
  }

  Widget _ballChild(double dia) => Container(
    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    child: Icon(Icons.sports_soccer, size: dia, color: Colors.black),
  );

  Widget _buildPlayer(Player p, int idx, double w, double h) {
    final left = p.relX * w;
    final top = p.relY * h;
    final dragging = (_dragIsPlayer && _draggingIdx == idx);

    final child = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: p.teamColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('${p.number}', style: TextStyle(color: Colors.white)),
    );

    return dragging
        ? Positioned(left: left, top: top, child: child)
        : AnimatedPositioned(
          key: ValueKey('player_$idx'),
          duration: widget.animDuration,
          curve: Curves.easeInOut,
          left: left,
          top: top,
          width: 40,
          height: 40,
          child: child,
        );
  }
}
