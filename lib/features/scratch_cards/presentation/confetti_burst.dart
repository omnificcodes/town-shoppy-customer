import 'dart:math';

import 'package:flutter/material.dart';

/// A one-shot shower of paper: ~140 pieces shot upwards from the centre,
/// falling under gravity and tumbling, fading in the last third. Drawn
/// with a CustomPainter so it needs no package. Drive it with an
/// [AnimationController] running 0 -> 1 over about two seconds.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.progress, this.colors = defaultColors});

  final Animation<double> progress;
  final List<Color> colors;

  static const defaultColors = [
    Color(0xFFFF4E6A),
    Color(0xFFFFC857),
    Color(0xFF38EF7D),
    Color(0xFF1FA2FF),
    Color(0xFFC13FA8),
    Color(0xFFFFFFFF),
  ];

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> {
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _pieces = List.generate(140, (i) {
      final angle = -pi / 2 + (random.nextDouble() - 0.5) * pi * 0.9;
      final speed = 0.9 + random.nextDouble() * 1.4;
      return _Piece(
        color: widget.colors[i % widget.colors.length],
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: 5 + random.nextDouble() * 6,
        spin: (random.nextDouble() - 0.5) * 14,
        wobble: random.nextDouble() * pi * 2,
        round: random.nextInt(4) == 0,
        delay: random.nextDouble() * 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.progress,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(pieces: _pieces, t: widget.progress.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.color,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.wobble,
    required this.round,
    required this.delay,
  });

  final Color color;
  final double vx;
  final double vy;
  final double size;
  final double spin;
  final double wobble;
  final bool round;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.t});

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final origin = Offset(size.width / 2, size.height * 0.45);
    final scale = size.shortestSide;
    final paint = Paint();

    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final time = local * 2.2;
      final x = origin.dx + p.vx * scale * 0.55 * time + sin(p.wobble + time * 6) * 8;
      final y = origin.dy + p.vy * scale * 0.55 * time + 0.5 * scale * 0.9 * time * time;
      final alpha = local < 0.66 ? 1.0 : (1 - (local - 0.66) / 0.34);
      paint.color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * time);
      // A tumbling piece looks narrower as it turns edge-on.
      canvas.scale(1, 0.35 + 0.65 * cos(time * 5 + p.wobble).abs());
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(1.5)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
