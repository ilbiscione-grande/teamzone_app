// lib/ui/pages/tools/tactics_video_player/painters.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

/// Ritar basic shapes
class ShapePainter {
  static void paintShape(Canvas canvas, Size size, Shape s) {
    final rect = Rect.fromLTWH(
      s.relX * size.width,
      s.relY * size.height,
      s.relWidth * size.width,
      s.relHeight * size.height,
    );
    final paint = Paint()..color = s.color;
    switch (s.type) {
      case ShapeType.circle:
        // Gör om till en perfekt cirkel
        final diameter = min(rect.width, rect.height);
        final center = rect.center;
        final squareRect = Rect.fromCenter(
          center: center,
          width: diameter,
          height: diameter,
        );
        canvas.drawOval(squareRect, paint);
        break;
      case ShapeType.square:
        canvas.drawRect(rect, paint);
        break;
      case ShapeType.triangle:
        final path =
            Path()
              ..moveTo(rect.center.dx, rect.top)
              ..lineTo(rect.bottomRight.dx, rect.bottomRight.dy)
              ..lineTo(rect.bottomLeft.dx, rect.bottomLeft.dy)
              ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.line:
        canvas.drawLine(rect.topLeft, rect.bottomRight, paint..strokeWidth = 2);
        break;
    }
  }
}

/// Enkel rak linje­painter (utan pilar eller streck)
class LinePainter extends CustomPainter {
  final Offset start, end;
  final Color color;
  final double strokeWidth;

  LinePainter({
    required this.start,
    required this.end,
    this.color = Colors.black,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas c, Size s) {
    c.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant LinePainter old) =>
      old.start != start ||
      old.end != end ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Rak linje med pilar och streckad stil
class StraightLinePainter extends LinePainter {
  final LineType type;

  StraightLinePainter({
    required Offset start,
    required Offset end,
    required this.type,
    required Color color,
    required double strokeWidth,
  }) : super(start: start, end: end, color: color, strokeWidth: strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;
    final path =
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);

    // Streckad?
    void drawDashed(Path p) {
      const dashWidth = 10.0, dashSpace = 5.0;
      for (var metric in p.computeMetrics()) {
        double d = 0;
        while (d < metric.length) {
          final len = min(dashWidth, metric.length - d);
          canvas.drawPath(metric.extractPath(d, d + len), paint);
          d += dashWidth + dashSpace;
        }
      }
    }

    if (type == LineType.dashed || type == LineType.dashedArrow) {
      drawDashed(path);
    } else {
      canvas.drawPath(path, paint);
    }

    // Pilspets?
    if ([
      LineType.solidArrow,
      LineType.dashedArrow,
      LineType.freeSolidArrow,
      LineType.freeDashedArrow,
    ].contains(type)) {
      final arrowLen = strokeWidth * 3 + 6;
      final halfBase = strokeWidth * 1.5 + 4;
      final angle = atan2(end.dy - start.dy, end.dx - start.dx);
      final ux = cos(angle), uy = sin(angle);
      final px = -uy, py = ux;

      final baseLeft = Offset(end.dx + px * halfBase, end.dy + py * halfBase);
      final baseRight = Offset(end.dx - px * halfBase, end.dy - py * halfBase);
      final tip = Offset(end.dx + ux * arrowLen, end.dy + uy * arrowLen);
      final midBase = Offset(
        (baseLeft.dx + baseRight.dx) / 2,
        (baseLeft.dy + baseRight.dy) / 2,
      );
      final ctrl = Offset(
        midBase.dx + ux * (arrowLen * 0.4),
        midBase.dy + uy * (arrowLen * 0.4),
      );

      final arrowPath =
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(baseLeft.dx, baseLeft.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, baseRight.dx, baseRight.dy)
            ..close();

      canvas.drawPath(
        arrowPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StraightLinePainter old) =>
      super.shouldRepaint(old) || old.type != type;
}

/// Frihandslinje med pilar/streck
class FreehandLinePainter extends CustomPainter {
  final List<Offset> points;
  final LineType type;
  final Color color;
  final double strokeWidth;

  FreehandLinePainter({
    required this.points,
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points.skip(1)) path.lineTo(p.dx, p.dy);

    void drawDashed(Path p) {
      const dashWidth = 10.0, dashSpace = 5.0;
      for (var metric in p.computeMetrics()) {
        double d = 0;
        while (d < metric.length) {
          final len = min(dashWidth, metric.length - d);
          canvas.drawPath(metric.extractPath(d, d + len), paint);
          d += dashWidth + dashSpace;
        }
      }
    }

    if (type == LineType.freeDashed || type == LineType.freeDashedArrow) {
      drawDashed(path);
    } else {
      canvas.drawPath(path, paint);
    }

    if (type == LineType.freeSolidArrow || type == LineType.freeDashedArrow) {
      final end = points.last;
      final prev = points[points.length - 2];
      final angle = atan2(end.dy - prev.dy, end.dx - prev.dx);
      final arrowLen = strokeWidth * 3 + 6;
      final halfBase = strokeWidth * 1.5 + 4;
      final ux = cos(angle), uy = sin(angle);
      final px = -uy, py = ux;

      final baseLeft = Offset(end.dx + px * halfBase, end.dy + py * halfBase);
      final baseRight = Offset(end.dx - px * halfBase, end.dy - py * halfBase);
      final tip = Offset(end.dx + ux * arrowLen, end.dy + uy * arrowLen);
      final midBase = Offset(
        (baseLeft.dx + baseRight.dx) / 2,
        (baseLeft.dy + baseRight.dy) / 2,
      );
      final ctrl = Offset(
        midBase.dx + ux * (arrowLen * 0.4),
        midBase.dy + uy * (arrowLen * 0.4),
      );

      final arrowPath =
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(baseLeft.dx, baseLeft.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, baseRight.dx, baseRight.dy)
            ..close();

      canvas.drawPath(
        arrowPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FreehandLinePainter old) =>
      old.points != points ||
      old.type != type ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Sammanställer en hel frame
class FramePainter extends CustomPainter {
  final List<Shape> shapes;
  final List<StraightLine> straightLines;
  final List<FreehandLine> freehandLines;

  FramePainter({
    required this.shapes,
    required this.straightLines,
    required this.freehandLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw shapes
    for (final shape in shapes) {
      ShapePainter.paintShape(canvas, size, shape);
    }

    // Draw straight lines with outline, main line, and arrowhead
    for (final line in straightLines) {
      final p1 = Offset(
        line.start.dx * size.width,
        line.start.dy * size.height,
      );
      final p2 = Offset(line.end.dx * size.width, line.end.dy * size.height);

      final outlinePaint =
          Paint()
            ..color = line.color.withOpacity(
              0.0,
            ) // utgå från linjans egen color
            ..strokeWidth = line.strokeWidth * 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      final mainPaint =
          Paint()
            ..color =
                line
                    .color // linjans egen color
            ..strokeWidth = line.strokeWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, outlinePaint);
      canvas.drawLine(p1, p2, mainPaint);

      // Arrowhead
      final arrowSize = line.strokeWidth * 1.5;
      final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      final path =
          Path()
            ..moveTo(p2.dx, p2.dy)
            ..lineTo(
              p2.dx - arrowSize * cos(angle - pi / 6),
              p2.dy - arrowSize * sin(angle - pi / 6),
            )
            ..moveTo(p2.dx, p2.dy)
            ..lineTo(
              p2.dx - arrowSize * cos(angle + pi / 6),
              p2.dy - arrowSize * sin(angle + pi / 6),
            );

      canvas.drawPath(path, outlinePaint);
      canvas.drawPath(path, mainPaint);
    }

    // Draw freehand lines with same outline + main line
    for (final free in freehandLines) {
      final outlinePaint =
          Paint()
            ..color = free.color.withOpacity(0.4)
            ..strokeWidth = free.strokeWidth * 5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      final mainPaint =
          Paint()
            ..color = free.color
            ..strokeWidth = free.strokeWidth * 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      final path = Path();
      if (free.points.isNotEmpty) {
        final first = free.points.first;
        path.moveTo(first.dx * size.width, first.dy * size.height);
        for (var point in free.points.skip(1)) {
          path.lineTo(point.dx * size.width, point.dy * size.height);
        }
      }

      canvas.drawPath(path, outlinePaint);
      canvas.drawPath(path, mainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FramePainter old) {
    return old.shapes != shapes ||
        old.straightLines != straightLines ||
        old.freehandLines != freehandLines;
  }
}
