// lib/ui/pages/tools/painters.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../tactics_board/models.dart';

/// Ritar en triangel
class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});
  @override
  void paint(Canvas c, Size s) {
    final p =
        Path()
          ..moveTo(s.width / 2, 0)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close();
    c.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant TrianglePainter old) => false;
}

/// Enkel rak linje (utan pilar eller streck)
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

/// Rak linje med pilar och streckad stil, nu med konkav bas på pilspetsen
class StraightLinePainter extends CustomPainter {
  final Offset start, end;
  final LineType type;
  final Color color;
  final double strokeWidth;

  StraightLinePainter({
    required this.start,
    required this.end,
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

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

    // Streckad-teckning
    void drawDashed(Path p) {
      const dashWidth = 10.0, dashSpace = 5.0;
      for (final metric in p.computeMetrics()) {
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

    // Fylld pilspets med konkav bas
    if (<LineType>[
      LineType.solidArrow,
      LineType.dashedArrow,
      LineType.freeSolidArrow,
      LineType.freeDashedArrow,
    ].contains(type)) {
      // längd på spetsen
      final arrowLen = strokeWidth * 3 + 6;
      // halva basbredden
      final halfBase = strokeWidth * 1.5 + 4;
      // riktningen från start till end
      final angle = atan2(end.dy - start.dy, end.dx - start.dx);
      final ux = cos(angle), uy = sin(angle);
      // vektor vinkelrätt mot linjen
      final px = -uy, py = ux;

      // beräkna baspunkterna
      final baseLeft = Offset(end.dx + px * halfBase, end.dy + py * halfBase);
      final baseRight = Offset(end.dx - px * halfBase, end.dy - py * halfBase);
      // spetsen utanför end
      final tip = Offset(end.dx + ux * arrowLen, end.dy + uy * arrowLen);
      // mitt på basen
      final midBase = Offset(
        (baseLeft.dx + baseRight.dx) / 2,
        (baseLeft.dy + baseRight.dy) / 2,
      );
      // kurvans kontrollpunkt inåt mot spetsen
      final ctrl = Offset(
        midBase.dx + ux * (arrowLen * 0.4),
        midBase.dy + uy * (arrowLen * 0.4),
      );

      // bygg pilspetsen med kvadratisk Bézier
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
      old.start != start ||
      old.end != end ||
      old.type != type ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Frihandslinje med pilar och streckad stil, också med konkav bas
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

    // bygg path av punkterna
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points.skip(1)) path.lineTo(p.dx, p.dy);

    // streckad teckning
    void drawDashed(Path p) {
      const dashWidth = 10.0, dashSpace = 5.0;
      for (final metric in p.computeMetrics()) {
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

    // pilspets i frihand
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
