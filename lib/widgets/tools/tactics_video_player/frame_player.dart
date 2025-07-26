// lib/ui/pages/tools/tactics_video_player/frame_player.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'painters.dart';

typedef Positionable = Object;

class FramePlayer extends StatefulWidget {
  final List<Frame> frames;
  final Duration interval;

  const FramePlayer({
    Key? key,
    required this.frames,
    this.interval = const Duration(seconds: 1),
  }) : super(key: key);

  @override
  _FramePlayerState createState() => _FramePlayerState();
}

class _FramePlayerState extends State<FramePlayer> {
  int _current = 0;
  Timer? _timer;
  bool _playing = false;

  void _play() {
    if (_playing || widget.frames.isEmpty) return;
    _playing = true;
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() => _current = (_current + 1) % widget.frames.length);
    });
  }

  void _pause() {
    _timer?.cancel();
    _playing = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) {
      return Center(
        child: Text(
          'Inga frames ännu.\nTryck + för att lägga till.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final frame = widget.frames[_current];
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Image.asset(
                'assets/football_pitch_vertical.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              CustomPaint(
                size: Size.infinite,
                painter: FramePainter(
                  shapes: frame.shapes,
                  straightLines: frame.straightLines,
                  freehandLines: frame.freehandLines,
                ),
              ),
              for (var p in frame.players)
                AnimatedPositioned(
                  key: ValueKey("player_${p.number}_$_current"),
                  duration: widget.interval,
                  left: p.relX * MediaQuery.of(context).size.width,
                  top: p.relY * MediaQuery.of(context).size.height,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.teamColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${p.number}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.skip_previous),
              onPressed: () {
                _pause();
                setState(() => _current = (_current - 1 + widget.frames.length) % widget.frames.length);
              },
            ),
            IconButton(
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              onPressed: _playing ? _pause : _play,
            ),
            IconButton(
              icon: Icon(Icons.skip_next),
              onPressed: () {
                _pause();
                setState(() => _current = (_current + 1) % widget.frames.length);
              },
            ),
          ],
        ),
        Slider(
          min: 0,
          max: (widget.frames.length - 1).toDouble(),
          divisions: widget.frames.length > 1 ? widget.frames.length - 1 : null,
          value: _current.toDouble(),
          onChanged: (v) {
            _pause();
            setState(() => _current = v.toInt());
          },
        ),
      ],
    );
  }
}
