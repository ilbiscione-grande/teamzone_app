// lib/ui/pages/tools/tactics_board_page.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'widgets/toolbar.dart';
import 'widgets/tactics_stack.dart';
import 'widgets/bottom_player_list.dart';

class TacticsBoardPage extends StatefulWidget {
  const TacticsBoardPage({Key? key}) : super(key: key);
  @override
  _TacticsBoardPageState createState() => _TacticsBoardPageState();
}

class _TacticsBoardPageState extends State<TacticsBoardPage> {
  final GlobalKey _previewKey = GlobalKey();
  bool _saving = false;

  // Verktygsval
  ShapeType? _selectedShapeType;
  LineType? _selectedLineType;
  Color _selectedColor = Colors.blue.withValues(alpha: 0.7);
  double _selectedStrokeWidth = 4.0;

  // Ritade objekt
  List<Object> _drawables = [];
  int? _selectedDrawableIndex;

  // Draft‐variabler
  Offset? _shapeDragStart;
  Shape? _shapeDraft;
  Offset? _lineStartDraft;
  Offset? _lineEndDraft;
  List<Offset>? _freehandDraft;

  Offset? _selectionDragStart;

  // Spelare
  List<Player> _available = [];
  List<Player> _placed = [];

  // Overlay
  Color? _overlayTeam;
  Offset? _overlayTapPosition;

  /// spelar som ska visas i overlay
  List<Player> get _overlayPlayers =>
      _overlayTeam == null
          ? []
          : _available.where((p) => p.teamColor == _overlayTeam).toList();

  @override
  void initState() {
    super.initState();
    _resetPlayers();
  }

  void _resetPlayers() {
    _available = [
      for (var i = 1; i <= 20; i++)
        Player(number: i, teamColor: Colors.blue, relX: 0, relY: 0),
      for (var i = 1; i <= 20; i++)
        Player(number: i, teamColor: Colors.red, relX: 0, relY: 0),
    ];
    _placed.clear();
  }

  void _toggleOverlay(Color teamColor, Offset globalTap) {
    // om samma lag, stäng; annars öppna och spara position
    final newTeam = _overlayTeam == teamColor ? null : teamColor;
    setState(() {
      _overlayTeam = newTeam;
      _overlayTapPosition = newTeam != null ? globalTap : null;
    });
  }

  void _closeOverlay() {
    setState(() {
      _overlayTeam = null;
      _overlayTapPosition = null;
    });
  }

  void _resetAll() {
    setState(() {
      _shapeDraft = null;
      _lineStartDraft = _lineEndDraft = null;
      _freehandDraft = null;
      _drawables.clear();
      _selectedDrawableIndex = null;
      _resetPlayers();
      _closeOverlay();
    });
  }

  void _undo() {
    setState(() {
      if (_drawables.isNotEmpty) {
        _drawables.removeLast();
      } else if (_placed.isNotEmpty) {
        _available.add(_placed.removeLast());
      }
    });
  }

  void _deleteSelectedDrawable() {
    if (_selectedDrawableIndex != null) {
      setState(() {
        _drawables.removeAt(_selectedDrawableIndex!);
        _selectedDrawableIndex = null;
      });
    }
  }

  Future<void> _share() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes =
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/tactics.png').writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Taktiktavla');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fel vid delning: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickColor() async {
    final colors = [
      Colors.red.withValues(alpha: 0.7),
      Colors.orange.withValues(alpha: 0.7),
      Colors.yellow.withValues(alpha: 0.7),
      Colors.green.withValues(alpha: 0.7),
      Colors.blue.withValues(alpha: 0.7),
      Colors.purple.withValues(alpha: 0.7),
      Colors.black.withValues(alpha: 0.7),
      Colors.white.withValues(alpha: 0.7),
    ];
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Välj färg'),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var c in colors)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedColor = c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  /// 1) Markera vid long-press
  void _selectDrawableAt(Offset p, Size boardSize) {
    for (int i = _drawables.length - 1; i >= 0; i--) {
      final item = _drawables[i];
      if (item is Shape) {
        final rect = Rect.fromLTWH(
          item.relX * boardSize.width,
          item.relY * boardSize.height,
          item.relWidth * boardSize.width,
          item.relHeight * boardSize.height,
        );
        if (rect.contains(p)) {
          return setState(() => _selectedDrawableIndex = i);
        }
      } else if (item is StraightLine) {
        final a = item.start, b = item.end;
        final dist =
            ((p.dx - a.dx) * (b.dy - a.dy) - (p.dy - a.dy) * (b.dx - a.dx))
                .abs() /
            (b - a).distance;
        if (dist < 10) return setState(() => _selectedDrawableIndex = i);
      } else if (item is FreehandLine) {
        for (int j = 0; j < item.points.length - 1; j++) {
          final a = item.points[j], b = item.points[j + 1];
          final dist =
              ((p.dx - a.dx) * (b.dy - a.dy) - (p.dy - a.dy) * (b.dx - a.dx))
                  .abs() /
              (b - a).distance;
          if (dist < 10) return setState(() => _selectedDrawableIndex = i);
        }
      }
    }
    setState(() => _selectedDrawableIndex = null);
  }

  /// 2) Flytta markerat
  void _moveSelectedDrawable(Offset newPos) {
    final i = _selectedDrawableIndex!;
    final delta = newPos - _selectionDragStart!;
    final item = _drawables[i];
    setState(() {
      if (item is Shape) {
        item.relX += delta.dx / context.size!.width;
        item.relY += delta.dy / context.size!.height;
      } else if (item is StraightLine) {
        item.start += delta;
        item.end += delta;
      } else if (item is FreehandLine) {
        for (int k = 0; k < item.points.length; k++) item.points[k] += delta;
      }
      _selectionDragStart = newPos;
    });
  }

  /// 3) Drop spelar
  void _handlePlayerDrop(DragTargetDetails<Player> details) {
    _closeOverlay();
    final box = _previewKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.offset);
    final w = box.size.width, h = box.size.height;
    final rx = (local.dx / w).clamp(0.0, 1.0),
        ry = (local.dy / h).clamp(0.0, 1.0);

    setState(() {
      final p = details.data;
      final idx = _placed.indexWhere(
        (x) => x.number == p.number && x.teamColor == p.teamColor,
      );
      if (idx >= 0) {
        _placed[idx].relX = rx;
        _placed[idx].relY = ry;
      } else {
        _placed.add(
          Player(number: p.number, teamColor: p.teamColor, relX: rx, relY: ry),
        );
        _available.removeWhere(
          (x) => x.number == p.number && x.teamColor == p.teamColor,
        );
      }
    });
  }

  /// 4) Pan-start: draft eller move
  void _onPanStart(DragStartDetails d) {
    final box = _previewKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    final w = box.size.width, h = box.size.height;

    if (_selectedDrawableIndex != null) {
      _selectionDragStart = local;
      return;
    }
    if (_selectedLineType != null) {
      if (_selectedLineType!.index >= LineType.freeSolid.index) {
        _freehandDraft = [local];
      } else {
        _lineStartDraft = local;
        _lineEndDraft = local;
      }
    } else if (_selectedShapeType != null) {
      _shapeDraft = Shape(
        type: _selectedShapeType!,
        relX: local.dx / w,
        relY: local.dy / h,
        relWidth: local.dx / w,
        relHeight: local.dy / h,
        color: _selectedColor,
      );
      _shapeDragStart = local;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _previewKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    final w = box.size.width, h = box.size.height;

    if (_selectedDrawableIndex != null && _selectionDragStart != null) {
      return _moveSelectedDrawable(local);
    }
    if (_freehandDraft != null) {
      setState(() => _freehandDraft!.add(local));
    } else if (_lineStartDraft != null) {
      setState(() => _lineEndDraft = local);
    } else if (_shapeDraft != null && _shapeDragStart != null) {
      final s = _shapeDragStart!;
      final left = min(s.dx, local.dx), top = min(s.dy, local.dy);
      setState(() {
        _shapeDraft!
          ..relX = left / w
          ..relY = top / h
          ..relWidth = (local.dx - s.dx).abs() / w
          ..relHeight = (local.dy - s.dy).abs() / h;
      });
    }
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      if (_selectedDrawableIndex != null) {
        _selectionDragStart = null;
        return;
      }
      if (_freehandDraft != null) {
        _drawables.add(
          FreehandLine(
            points: _freehandDraft!,
            type: _selectedLineType!,
            color: _selectedColor,
            strokeWidth: _selectedStrokeWidth,
          ),
        );
        _freehandDraft = null;
      } else if (_lineStartDraft != null && _lineEndDraft != null) {
        _drawables.add(
          StraightLine(
            start: _lineStartDraft!,
            end: _lineEndDraft!,
            type: _selectedLineType!,
            color: _selectedColor,
            strokeWidth: _selectedStrokeWidth,
          ),
        );
        _lineStartDraft = _lineEndDraft = null;
      } else if (_shapeDraft != null) {
        _drawables.add(_shapeDraft!);
        _shapeDraft = null;
        _shapeDragStart = null;
      }
    });
  }

  Widget _buildPlayer(Player p) => Container(
    width: 40,
    height: 40,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(color: p.teamColor, shape: BoxShape.circle),
    child: Center(
      child: Text(
        '${p.number}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ─── Toolbar ───
                TacticsToolbar(
                  selectedShape: _selectedShapeType,
                  selectedLine: _selectedLineType,
                  selectedColor: _selectedColor,
                  strokeWidth: _selectedStrokeWidth,
                  onReset: _resetAll,
                  onUndo: _undo,
                  onPickColor: _pickColor,
                  onStrokeSelected:
                      (w) => setState(() => _selectedStrokeWidth = w),
                  onShapeSelected:
                      (s) => setState(() {
                        _selectedShapeType = s;
                        _selectedLineType = null;
                      }),
                  onLineSelected:
                      (l) => setState(() {
                        _selectedLineType = l;
                        _selectedShapeType = null;
                      }),
                  onDeleteSelected: _deleteSelectedDrawable,
                  onClearSelection:
                      () => setState(() => _selectedDrawableIndex = null),
                ),
                // ─── Rit-område ───
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeOverlay,
                    child: RepaintBoundary(
                      key: _previewKey,
                      child: TacticsStack(
                        previewKey: _previewKey,
                        drawables: _drawables,
                        selectedDrawableIndex: _selectedDrawableIndex,
                        onSelectDrawableAt: _selectDrawableAt,
                        onMoveSelectedDrawable: _moveSelectedDrawable,
                        onPlayerDrop: _handlePlayerDrop,
                        placed: _placed,
                        freehandDraft: _freehandDraft,
                        lineStartDraft: _lineStartDraft,
                        lineEndDraft: _lineEndDraft,
                        shapeDraft: _shapeDraft,
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        onClearSelection:
                            () => setState(() => _selectedDrawableIndex = null),
                      ),
                    ),
                  ),
                ),
                // ─── BottomPlayerList ───
                BottomPlayerList(
                  available: _available,
                  playerBuilder: _buildPlayer,
                  onOpenOverlay: _toggleOverlay,
                  onPlayerCancelled: (p) {
                    setState(() {
                      _placed.removeWhere(
                        (x) =>
                            x.number == p.number && x.teamColor == p.teamColor,
                      );
                      _available.add(p);
                      _closeOverlay();
                    });
                  },

                  // ITEMS
                  items: [
                    Item(id: 'ball', icon: Icon(Icons.sports_soccer, size: 24)),
                    Item(
                      id: 'cone',
                      icon: Icon(Icons.change_history, size: 24),
                    ),
                    // … fler …
                  ],
                  itemBuilder:
                      (it) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        child: Center(child: it.icon),
                      ),
                  onItemCancelled: (it) {
                    // om du vill kunna dra tillbaka items in i bottensheet
                    // annars kan du ta bort denna parameter
                  },
                ),
              ],
            ),
            // ─── Overlay ───
            if (_overlayTeam != null && _overlayTapPosition != null)
              Positioned(
                left: _overlayTapPosition!.dx - 34,
                bottom: 75,
                width: 60,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _overlayPlayers.map((p) {
                          return Draggable<Player>(
                            data: p,
                            onDragStarted: _closeOverlay,
                            feedback: _buildPlayer(p),
                            childWhenDragging: Opacity(
                              opacity: 0.5,
                              child: _buildPlayer(p),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: _buildPlayer(p),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _share,
        child:
            _saving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.share),
      ),
    );
  }
}
