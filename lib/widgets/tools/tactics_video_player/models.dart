// lib/ui/pages/tools/tactics_video_player/models.dart

import 'dart:ui';
import 'package:flutter/material.dart';

/// Former på planen
enum ShapeType { circle, square, triangle, line }

/// Linjetyper
enum LineType {
  solid,
  solidArrow,
  dashed,
  dashedArrow,
  freeSolid,
  freeSolidArrow,
  freeDashed,
  freeDashedArrow,
}

/// En generisk shape
class Shape {
  final ShapeType type;
  final double relX, relY, relWidth, relHeight;
  final Color color;

  Shape({
    required this.type,
    required this.relX,
    required this.relY,
    required this.relWidth,
    required this.relHeight,
    required this.color,
  });

  /// Djupt klonad kopia
  Shape clone() => Shape(
    type: type,
    relX: relX,
    relY: relY,
    relWidth: relWidth,
    relHeight: relHeight,
    color: color,
  );

  /// Bygger ny instans baserat på denna
  Shape copyWith({
    ShapeType? type,
    double? relX,
    double? relY,
    double? relWidth,
    double? relHeight,
    Color? color,
  }) {
    return Shape(
      type: type ?? this.type,
      relX: relX ?? this.relX,
      relY: relY ?? this.relY,
      relWidth: relWidth ?? this.relWidth,
      relHeight: relHeight ?? this.relHeight,
      color: color ?? this.color,
    );
  }

  /// JSON-serialisering
  Map<String, dynamic> toJson() => {
    'type': type.index,
    'relX': relX,
    'relY': relY,
    'relWidth': relWidth,
    'relHeight': relHeight,
    'color': color.value,
  };

  factory Shape.fromJson(Map<String, dynamic> m) => Shape(
    type: ShapeType.values[m['type'] as int],
    relX: (m['relX'] as num).toDouble(),
    relY: (m['relY'] as num).toDouble(),
    relWidth: (m['relWidth'] as num).toDouble(),
    relHeight: (m['relHeight'] as num).toDouble(),
    color: Color(m['color'] as int),
  );
}

/// En spelare
class Player {
  final int number;
  final Color teamColor;
  final double relX, relY;

  Player({
    required this.number,
    required this.teamColor,
    required this.relX,
    required this.relY,
  });

  Player clone() =>
      Player(number: number, teamColor: teamColor, relX: relX, relY: relY);

  Player copyWith({int? number, Color? teamColor, double? relX, double? relY}) {
    return Player(
      number: number ?? this.number,
      teamColor: teamColor ?? this.teamColor,
      relX: relX ?? this.relX,
      relY: relY ?? this.relY,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'teamColor': teamColor.value,
    'relX': relX,
    'relY': relY,
  };

  factory Player.fromJson(Map<String, dynamic> m) => Player(
    number: m['number'] as int,
    teamColor: Color(m['teamColor'] as int),
    relX: (m['relX'] as num).toDouble(),
    relY: (m['relY'] as num).toDouble(),
  );
}

/// Rak linje
class StraightLine {
  final Offset start, end;
  final LineType type;
  final Color color;
  final double strokeWidth;

  StraightLine({
    required this.start,
    required this.end,
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  StraightLine clone() => StraightLine(
    start: start,
    end: end,
    type: type,
    color: color,
    strokeWidth: strokeWidth,
  );

  StraightLine copyWith({
    Offset? start,
    Offset? end,
    LineType? type,
    Color? color,
    double? strokeWidth,
  }) {
    return StraightLine(
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }

  Map<String, dynamic> toJson() => {
    'startX': start.dx,
    'startY': start.dy,
    'endX': end.dx,
    'endY': end.dy,
    'type': type.index,
    'color': color.value,
    'strokeWidth': strokeWidth,
  };

  factory StraightLine.fromJson(Map<String, dynamic> m) => StraightLine(
    start: Offset(
      (m['startX'] as num).toDouble(),
      (m['startY'] as num).toDouble(),
    ),
    end: Offset((m['endX'] as num).toDouble(), (m['endY'] as num).toDouble()),
    type: LineType.values[m['type'] as int],
    color: Color(m['color'] as int),
    strokeWidth: (m['strokeWidth'] as num).toDouble(),
  );
}

/// Frihandslinje
class FreehandLine {
  final List<Offset> points;
  final LineType type;
  final Color color;
  final double strokeWidth;

  FreehandLine({
    required List<Offset> points,
    required this.type,
    required this.color,
    required this.strokeWidth,
  }) : points = List.of(points);

  FreehandLine clone() => FreehandLine(
    points: List.of(points),
    type: type,
    color: color,
    strokeWidth: strokeWidth,
  );

  FreehandLine copyWith({
    List<Offset>? points,
    LineType? type,
    Color? color,
    double? strokeWidth,
  }) {
    return FreehandLine(
      points: points ?? List.of(this.points),
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }

  Map<String, dynamic> toJson() => {
    'points': points.map((o) => {'dx': o.dx, 'dy': o.dy}).toList(),
    'type': type.index,
    'color': color.value,
    'strokeWidth': strokeWidth,
  };

  factory FreehandLine.fromJson(Map<String, dynamic> m) => FreehandLine(
    points:
        (m['points'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(
              (o) => Offset(
                (o['dx'] as num).toDouble(),
                (o['dy'] as num).toDouble(),
              ),
            )
            .toList(),
    type: LineType.values[m['type'] as int],
    color: Color(m['color'] as int),
    strokeWidth: (m['strokeWidth'] as num).toDouble(),
  );
}

/// En “snapshot” av allt på planen
class Frame {
  final List<Shape> shapes;
  final List<StraightLine> straightLines;
  final List<FreehandLine> freehandLines;
  final List<Player> players;

  Frame({
    required this.shapes,
    required this.straightLines,
    required this.freehandLines,
    required this.players,
  });

  Map<String, dynamic> toJson() => {
    'shapes': shapes.map((s) => s.toJson()).toList(),
    'straightLines': straightLines.map((l) => l.toJson()).toList(),
    'freehandLines': freehandLines.map((l) => l.toJson()).toList(),
    'players': players.map((p) => p.toJson()).toList(),
  };

  factory Frame.fromJson(Map<String, dynamic> m) => Frame(
    shapes:
        (m['shapes'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((s) => Shape.fromJson(s))
            .toList(),
    straightLines:
        (m['straightLines'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((l) => StraightLine.fromJson(l))
            .toList(),
    freehandLines:
        (m['freehandLines'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((l) => FreehandLine.fromJson(l))
            .toList(),
    players:
        (m['players'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((p) => Player.fromJson(p))
            .toList(),
  );
}

/// Lägg till ett fält i BallData så vi vet vilken boll vi drar
class BallData {
  final int index;
  BallData(this.index);
}
