// lib/ui/pages/tools/models.dart
import 'package:flutter/material.dart';

enum ShapeType { circle, square, triangle, line }
enum LineType {
  solid, solidArrow, dashed, dashedArrow,
  freeSolid, freeSolidArrow, freeDashed, freeDashedArrow,
}

class Shape {
  ShapeType type;
  double relX, relY, relWidth, relHeight;
  Color color;
  Shape({
    required this.type,
    required this.relX,
    required this.relY,
    required this.relWidth,
    required this.relHeight,
    required this.color,
  });
}

class Player {
  int number;
  Color teamColor;
  double relX, relY;
  Player({
    required this.number,
    required this.teamColor,
    required this.relX,
    required this.relY,
  });
}

class StraightLine {
  Offset start, end;
  LineType type;
  Color color;
  double strokeWidth;
  StraightLine({
    required this.start,
    required this.end,
    required this.type,
    required this.color,
    required this.strokeWidth,
  });
}

class FreehandLine {
  List<Offset> points;
  LineType type;
  Color color;
  double strokeWidth;
  FreehandLine({
    required this.points,
    required this.type,
    required this.color,
    required this.strokeWidth,
  });
}

