import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/purchase_stats.dart';

/// Bar chart of recorded purchases per bucket (`GET /purchases/stats`).
/// Hand-painted rather than a charting dependency: one series, one colour,
/// no interaction beyond reading it -- a package would be more code than
/// this painter.
class PurchaseTrendChart extends StatelessWidget {
  const PurchaseTrendChart({super.key, required this.points, this.height = 140});

  final List<PurchaseTrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final first = points.isNotEmpty ? _label(points.first.date) : '';
    final last = points.isNotEmpty ? _label(points.last.date) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Semantics(
            label: 'Purchases over time, peak $max in one period',
            child: CustomPaint(painter: _BarsPainter(points: points, max: max)),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(first, style: AppTypography.caption),
            Text(last, style: AppTypography.caption),
          ],
        ),
      ],
    );
  }

  static String _label(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({required this.points, required this.max});

  final List<PurchaseTrendPoint> points;
  final int max;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height - (size.height * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.isEmpty) return;

    final slot = size.width / points.length;
    final barWidth = (slot * 0.62).clamp(2.0, 28.0);
    final bar = Paint()..color = AppColors.businessInk;
    final barEmpty = Paint()..color = AppColors.businessTintStrong;

    for (var i = 0; i < points.length; i++) {
      final count = points[i].count;
      final ratio = max == 0 ? 0.0 : count / max;
      final barHeight = (size.height * ratio).clamp(count > 0 ? 3.0 : 2.0, size.height);
      final left = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, count > 0 ? bar : barEmpty);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.points != points || old.max != max;
}
