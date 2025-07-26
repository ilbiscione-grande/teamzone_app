// lib/ui/pages/tools/tactics_video_player/bottom_menu.dart

import 'package:flutter/material.dart';

typedef PageControlCallback = void Function(int);
typedef PlayPauseCallback = void Function();

class BottomMenu extends StatelessWidget {
  final bool hasFrames;
  final int currentIndex;
  final int maxIndex;
  final bool isPlaying;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback onAddFrame;
  final VoidCallback onRemoveFrame;
  final ValueChanged<int> onSlide;
  final Duration currentSpeed;
  final ValueChanged<Duration> onSpeedChange;
  final VoidCallback onLoad;
  final VoidCallback onSave;

  const BottomMenu({
    Key? key,
    required this.hasFrames,
    required this.currentIndex,
    required this.maxIndex,
    required this.isPlaying,
    required this.onFirst,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onLast,
    required this.onAddFrame,
    required this.onRemoveFrame,
    required this.onSlide,
    required this.currentSpeed,
    required this.onSpeedChange,
    required this.onLoad,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          // ─ VÄNSTER ─
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.save, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: onSave,
              ),
              IconButton(
                icon: Icon(Icons.folder_open, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: onLoad,
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.first_page, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: hasFrames ? onFirst : null,
              ),
              IconButton(
                icon: Icon(Icons.skip_previous, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: hasFrames ? onPrevious : null,
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: hasFrames ? onPlayPause : null,
              ),
              IconButton(
                icon: Icon(Icons.skip_next, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: hasFrames ? onNext : null,
              ),
              IconButton(
                icon: Icon(Icons.last_page, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 2),
                onPressed: hasFrames ? onLast : null,
              ),
            ],
          ),

          // ─ SLIDER ─
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                tickMarkShape: const BorderedTickMarkShape(
                  tickRadius: 6,
                  borderColor: Colors.black,
                  borderWidth: 2,
                ),
                activeTickMarkColor: Colors.yellow,
                inactiveTickMarkColor: Colors.white60,
                activeTrackColor: Colors.yellow,
                inactiveTrackColor: Colors.white38,
                thumbColor: Colors.yellow,
              ),
              child: Slider(
                value: currentIndex.toDouble(),
                min: 0,
                max: maxIndex.toDouble(),
                divisions: hasFrames && maxIndex > 0 ? maxIndex : null,
                onChanged: hasFrames ? (v) => onSlide(v.toInt()) : null,
              ),
            ),
          ),

          // ─ HÖGER ─
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.add, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 0),
                onPressed: onAddFrame,
              ),
              IconButton(
                icon: Icon(Icons.remove, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 0),
                onPressed: hasFrames ? onRemoveFrame : null,
              ),
              PopupMenuButton<Duration>(
                icon: Icon(Icons.speed, color: Colors.white),
                tooltip:
                    'Animationshastighet (${currentSpeed.inMilliseconds} ms)',
                onSelected: onSpeedChange,
                itemBuilder:
                    (_) => [
                      PopupMenuItem<Duration>(
                        enabled: false,
                        child: Text(
                          'Animationshastighet',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const PopupMenuDivider(),
                      // Snabbast
                      PopupMenuItem<Duration>(
                        value: Duration(milliseconds: 500),
                        child: Row(
                          children: [
                            if (currentSpeed == Duration(milliseconds: 500))
                              Icon(Icons.check, size: 20, color: Colors.black),
                            if (currentSpeed == Duration(milliseconds: 500))
                              SizedBox(width: 8),
                            Text('Snabbast'),
                          ],
                        ),
                      ),
                      // Snabbare
                      PopupMenuItem<Duration>(
                        value: Duration(milliseconds: 850),
                        child: Row(
                          children: [
                            if (currentSpeed == Duration(milliseconds: 850))
                              Icon(Icons.check, size: 20, color: Colors.black),
                            if (currentSpeed == Duration(milliseconds: 850))
                              SizedBox(width: 8),
                            Text('Snabbare'),
                          ],
                        ),
                      ),
                      // Standard
                      PopupMenuItem<Duration>(
                        value: Duration(milliseconds: 1200),
                        child: Row(
                          children: [
                            if (currentSpeed == Duration(milliseconds: 1200))
                              Icon(Icons.check, size: 20, color: Colors.black),
                            if (currentSpeed == Duration(milliseconds: 1200))
                              SizedBox(width: 8),
                            Text('Standard'),
                          ],
                        ),
                      ),
                      // Långsammare
                      PopupMenuItem<Duration>(
                        value: Duration(milliseconds: 1500),
                        child: Row(
                          children: [
                            if (currentSpeed == Duration(milliseconds: 1500))
                              Icon(Icons.check, size: 20, color: Colors.black),
                            if (currentSpeed == Duration(milliseconds: 1500))
                              SizedBox(width: 8),
                            Text('Långsammare'),
                          ],
                        ),
                      ),
                      // Långsammast
                      PopupMenuItem<Duration>(
                        value: Duration(milliseconds: 1800),
                        child: Row(
                          children: [
                            if (currentSpeed == Duration(milliseconds: 1800))
                              Icon(Icons.check, size: 20, color: Colors.black),
                            if (currentSpeed == Duration(milliseconds: 1800))
                              SizedBox(width: 8),
                            Text('Långsammast'),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BorderedTickMarkShape extends RoundSliderTickMarkShape {
  final double tickRadius;
  final Color borderColor;
  final double borderWidth;

  const BorderedTickMarkShape({
    this.tickRadius = 6,
    this.borderColor = Colors.black,
    this.borderWidth = 2,
  });

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    bool isEnabled = false,
    bool isOnActiveTrack = false,
    TextDirection? textDirection,
  }) {
    final Canvas canvas = context.canvas;

    // Räkna ut om detta center motsvarar currentIndex:
    // isOnActiveTrack är bara sant för de tick‐marks till vänster om thumb,
    // inkl. själva thumb‐positionen, så vi kan använda det.
    final bool isCurrent = (center.dx - thumbCenter.dx).abs() < 0.1;

    // Grund‐cirkeln
    final Paint fillPaint =
        Paint()
          ..color =
              isOnActiveTrack
                  ? sliderTheme.activeTickMarkColor!
                  : sliderTheme.inactiveTickMarkColor!;
    canvas.drawCircle(center, tickRadius, fillPaint);

    // Om det är *just* den aktuella tick‐marken, rita border
    if (isCurrent) {
      final Paint borderPaint =
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth;
      canvas.drawCircle(center, tickRadius, borderPaint);
    }
  }
}
