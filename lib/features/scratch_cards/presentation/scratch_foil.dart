import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The silver foil over a scratch card, rubbed away with a finger (or the
/// mouse on web). Reports how much has been cleared so the screen can
/// finish the reveal once enough is gone. Built with a CustomPainter and
/// a BlendMode.clear brush -- no package.
class ScratchFoil extends StatefulWidget {
  const ScratchFoil({
    super.key,
    required this.enabled,
    required this.onFirstTouch,
    required this.onProgress,
    this.revealProgress = 0,
    this.tint = const Color(0xFFC9CDD6),
    this.label = 'SCRATCH HERE',
  });

  /// False once the card is revealed: the foil stops taking touches.
  final bool enabled;

  /// Fires once, on the first stroke -- the screen asks the server to
  /// scratch the card so the reward is known before the foil is gone.
  final VoidCallback onFirstTouch;

  /// 0..1, how much of the foil the user has cleared.
  final ValueChanged<double> onProgress;

  /// 0..1, fades the remaining foil out when the screen finishes the reveal.
  final double revealProgress;

  final Color tint;
  final String label;

  @override
  State<ScratchFoil> createState() => _ScratchFoilState();
}

class _ScratchFoilState extends State<ScratchFoil> {
  static const _brush = 26.0;
  static const _cols = 24;
  static const _rows = 15;

  /// Stroke points; a null separates one stroke from the next, so a line
  /// is only ever drawn within a stroke.
  final List<Offset?> _points = [];
  final List<bool> _cleared = List.filled(_cols * _rows, false);
  bool _touched = false;
  Size _size = Size.zero;

  void _start(Offset position) {
    if (!widget.enabled) return;
    if (!_touched) {
      _touched = true;
      widget.onFirstTouch();
    }
    if (_points.isNotEmpty && _points.last != null) _points.add(null);
    _add(position);
  }

  void _add(Offset position) {
    if (!widget.enabled || _size == Size.zero) return;
    setState(() {
      // A fast drag (a mouse on web most of all) reports few points far
      // apart; the band between them is cleared too, so the rub always
      // matches the finger's path.
      final previous = _points.isEmpty ? null : _points.last;
      _points.add(position);
      if (previous == null) {
        _markCleared(position);
      } else {
        final distance = (position - previous).distance;
        final steps = (distance / (_brush / 2)).ceil().clamp(1, 200);
        for (var i = 1; i <= steps; i++) {
          _markCleared(Offset.lerp(previous, position, i / steps)!);
        }
      }
    });
    widget.onProgress(_cleared.where((v) => v).length / _cleared.length);
  }

  /// Marks the grid cells under the brush at [position] as cleared.
  void _markCleared(Offset position) {
    final cellW = _size.width / _cols;
    final cellH = _size.height / _rows;
    final c0 = ((position.dx - _brush) / cellW).floor().clamp(0, _cols - 1);
    final c1 = ((position.dx + _brush) / cellW).floor().clamp(0, _cols - 1);
    final r0 = ((position.dy - _brush) / cellH).floor().clamp(0, _rows - 1);
    final r1 = ((position.dy + _brush) / cellH).floor().clamp(0, _rows - 1);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        _cleared[r * _cols + c] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _start(d.localPosition),
          onPanUpdate: (d) => _add(d.localPosition),
          onTapDown: (d) => _start(d.localPosition),
          child: Opacity(
            opacity: (1 - widget.revealProgress).clamp(0.0, 1.0),
            child: CustomPaint(
              // A fresh list each build: the painter decides whether to
              // repaint by comparing lists, which the same instance mutated
              // in place would defeat.
              painter: _FoilPainter(points: List.of(_points), brush: _brush, tint: widget.tint, label: widget.label),
              size: _size,
            ),
          ),
        );
      },
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter({required this.points, required this.brush, required this.tint, required this.label});

  final List<Offset?> points;
  final double brush;
  final Color tint;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());

    // Brushed metal: a light sweep, then fine diagonal lines.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [Color.lerp(tint, Colors.white, 0.55)!, tint, Color.lerp(tint, Colors.black, 0.25)!, Color.lerp(tint, Colors.white, 0.4)!],
          const [0, 0.4, 0.75, 1],
        ),
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }

    // A few sparkles so the foil reads as something to rub.
    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final random = Random(7);
    for (var i = 0; i < 14; i++) {
      final c = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final r = 2 + random.nextDouble() * 3;
      canvas.drawLine(c - Offset(r * 2, 0), c + Offset(r * 2, 0), sparkle..strokeWidth = 1);
      canvas.drawLine(c - Offset(0, r * 2), c + Offset(0, r * 2), sparkle);
    }

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Color.lerp(tint, Colors.black, 0.55),
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset((size.width - text.width) / 2, (size.height - text.height) / 2));

    final hint = TextPainter(
      text: TextSpan(
        text: 'Rub with your finger to reveal your prize',
        style: TextStyle(color: Color.lerp(tint, Colors.black, 0.45), fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hint.paint(canvas, Offset((size.width - hint.width) / 2, (size.height + text.height) / 2 + 6));

    // The rubbed-away strokes.
    final eraser = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeWidth = brush * 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p == null) continue;
      final previous = i > 0 ? points[i - 1] : null;
      if (previous != null) {
        canvas.drawLine(previous, p, eraser);
      } else {
        canvas.drawCircle(p, brush, eraser..style = PaintingStyle.fill);
        eraser.style = PaintingStyle.stroke;
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FoilPainter old) => old.points.length != points.length || old.tint != tint;
}
