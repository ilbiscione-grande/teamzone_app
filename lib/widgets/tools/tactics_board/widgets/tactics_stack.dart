// lib/ui/pages/tools/widgets/tactics_stack.dart

import 'package:flutter/material.dart';
import '../models.dart';
import '../painters.dart';

class TacticsStack extends StatefulWidget {
  final GlobalKey previewKey;
  final List<Object> drawables;
  final int? selectedDrawableIndex;
  final void Function(Offset, Size) onSelectDrawableAt;
  final void Function(Offset) onMoveSelectedDrawable;
  final void Function(DragTargetDetails<Player>) onPlayerDrop;
  final List<Player> placed;

  final List<Offset>? freehandDraft;
  final Offset? lineStartDraft;
  final Offset? lineEndDraft;
  final Shape? shapeDraft;

  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  /// Called when a move‐gesture ends, to clear the current selection.
  final VoidCallback onClearSelection;

  const TacticsStack({
    Key? key,
    required this.previewKey,
    required this.drawables,
    required this.selectedDrawableIndex,
    required this.onSelectDrawableAt,
    required this.onMoveSelectedDrawable,
    required this.onPlayerDrop,
    required this.placed,
    this.freehandDraft,
    this.lineStartDraft,
    this.lineEndDraft,
    this.shapeDraft,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onClearSelection,
  }) : super(key: key);

  @override
  _TacticsStackState createState() => _TacticsStackState();
}

class _TacticsStackState extends State<TacticsStack> {
  Offset? _selectionDragStart;
  Offset? _dragOffsetInDrawable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth, h = cons.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          // 1) Direkt vid nedslag – markera ev. drawable
          // 1) När fingret går ned – bara räkna ut drag-offset för den valda shape
          onPanDown: (DragDownDetails details) {
            final local = details.localPosition;
            widget.onSelectDrawableAt(local, Size(w, h));

            final idx = widget.selectedDrawableIndex;
            if (idx != null && widget.drawables[idx] is Shape) {
              final shape = widget.drawables[idx] as Shape;
              // Spara den inre offseten: var i formen du tryckte
              _dragOffsetInDrawable =
                  local - Offset(shape.relX * w, shape.relY * h);
            } else {
              _dragOffsetInDrawable = null;
            }
          },

          // 2) Om inget objekt är valt startar drafting precis som förut
          onPanStart: (DragStartDetails details) {
            if (widget.selectedDrawableIndex != null) return;
            widget.onPanStart(details);
          },

          // 2b) Om shape är vald, flytta den – annars drafting-logik
          onPanUpdate: (details) {
            final idx = widget.selectedDrawableIndex;
            if (idx != null && _dragOffsetInDrawable != null) {
              final box =
                  widget.previewKey.currentContext!.findRenderObject()
                      as RenderBox;
              final local = box.globalToLocal(details.globalPosition);

              // beräkna nya vänster/topp i pixlar
              final newLeftPx = local.dx - _dragOffsetInDrawable!.dx;
              final newTopPx = local.dy - _dragOffsetInDrawable!.dy;

              setState(() {
                final shape = widget.drawables[idx] as Shape;
                shape.relX = newLeftPx / w;
                shape.relY = newTopPx / h;
              });
              return;
            }

            // annars fortsätt med drafting-logiken
            widget.onPanUpdate(details);
          },
          // 3) Släpp: antingen avsluta MOVE eller avsluta drafting
          onPanEnd: (details) {
            if (widget.selectedDrawableIndex != null &&
                _dragOffsetInDrawable != null) {
              _dragOffsetInDrawable = null;
              return;
            }
            widget.onPanEnd(details);
          },
          child: Stack(
            children: [
              // Bakgrund
              Image.asset(
                'assets/football_pitch_vertical.png',
                fit: BoxFit.contain,
                width: w,
                height: h,
              ),

              // Draft-linjer
              if (widget.lineStartDraft != null && widget.lineEndDraft != null)
                CustomPaint(
                  size: Size(w, h),
                  painter: StraightLinePainter(
                    start: widget.lineStartDraft!,
                    end: widget.lineEndDraft!,
                    type: LineType.solid,
                    color: Colors.black.withOpacity(0.5),
                    strokeWidth: 4.0,
                  ),
                ),

              if (widget.freehandDraft != null &&
                  widget.freehandDraft!.length > 1)
                CustomPaint(
                  size: Size(w, h),
                  painter: FreehandLinePainter(
                    points: widget.freehandDraft!,
                    type: LineType.freeSolid,
                    color: Colors.black.withOpacity(0.5),
                    strokeWidth: 2.0,
                  ),
                ),

              // Draft-form
              if (widget.shapeDraft != null)
                Positioned(
                  left: widget.shapeDraft!.relX * w,
                  top: widget.shapeDraft!.relY * h,
                  width: widget.shapeDraft!.relWidth * w,
                  height: widget.shapeDraft!.relHeight * h,
                  child: Opacity(
                    opacity: 0.5,
                    child: Builder(
                      builder: (_) {
                        switch (widget.shapeDraft!.type) {
                          case ShapeType.circle:
                            return ClipOval(
                              child: Container(color: widget.shapeDraft!.color),
                            );
                          case ShapeType.square:
                            return Container(color: widget.shapeDraft!.color);
                          case ShapeType.triangle:
                            return CustomPaint(
                              painter: TrianglePainter(
                                color: widget.shapeDraft!.color,
                              ),
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                ),
              // Permanenta objekt
              for (int i = 0; i < widget.drawables.length; i++)
                _buildDrawableWidget(widget.drawables[i], i, w, h),

              // Spelardrag-target
              DragTarget<Player>(
                onWillAccept: (_) => true,
                onAcceptWithDetails: widget.onPlayerDrop,
                builder: (c, a, b) => const SizedBox.expand(),
              ),

              // Placerade spelare som Draggable
              for (var p in widget.placed)
                Positioned(
                  left: p.relX * w,
                  top: p.relY * h,
                  child: Draggable<Player>(
                    data: p,
                    feedback: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.teamColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${p.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: p.teamColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${p.number}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.teamColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${p.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawableWidget(Object item, int idx, double w, double h) {
    final isSel = idx == widget.selectedDrawableIndex;

    // 1) Shape (alla typer utom line)
    if (item is Shape && item.type != ShapeType.line) {
      // själva formen
      Widget shapeWidget;
      switch (item.type) {
        case ShapeType.circle:
          shapeWidget = ClipOval(child: Container(color: item.color));
          break;
        case ShapeType.square:
          shapeWidget = Container(color: item.color);
          break;
        case ShapeType.triangle:
          shapeWidget = CustomPaint(
            painter: TrianglePainter(color: item.color),
          );
          break;
        default:
          shapeWidget = SizedBox.shrink();
      }

      // packa in i Positioned
      return Stack(
        children: [
          Positioned(
            left: item.relX * w,
            top: item.relY * h,
            width: item.relWidth * w,
            height: item.relHeight * h,
            child: shapeWidget,
          ),

          // om markerad, rita en gul ram runt
          if (isSel)
            Positioned(
              left: item.relX * w - 4,
              top: item.relY * h - 4,
              width: item.relWidth * w + 8,
              height: item.relHeight * h + 8,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 3),
                ),
              ),
            ),
        ],
      );
    }
    if (item is StraightLine) {
      return CustomPaint(
        size: Size(w, h),
        painter: StraightLinePainter(
          start: item.start,
          end: item.end,
          type: item.type,
          color: item.color,
          strokeWidth: item.strokeWidth,
        ),
        foregroundPainter:
            isSel
                ? StraightLinePainter(
                  start: item.start,
                  end: item.end,
                  type: item.type,
                  color: Colors.yellow.withOpacity(0.6),
                  strokeWidth: item.strokeWidth + 4,
                )
                : null,
      );
    }

    if (item is FreehandLine) {
      return CustomPaint(
        size: Size(w, h),
        painter: FreehandLinePainter(
          points: item.points,
          type: item.type,
          color: item.color,
          strokeWidth: item.strokeWidth,
        ),
        foregroundPainter:
            isSel
                ? FreehandLinePainter(
                  points: item.points,
                  type: item.type,
                  color: Colors.yellow.withOpacity(0.6),
                  strokeWidth: item.strokeWidth + 4,
                )
                : null,
      );
    }

    return const SizedBox.shrink();
  }
}
