import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_spacing.dart';
import 'auth_widgets.dart';

/// Full-screen cream ground with soft peach corner blobs and a warm glow
/// behind the hero art. Meant to sit as the first child of a [Stack]
/// under the screen's SafeArea so the blobs bleed behind the status bar.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, this.cornerBlobs = true});

  final bool cornerBlobs;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: CustomPaint(painter: _BackdropPainter(cornerBlobs: cornerBlobs)));
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.cornerBlobs});

  final bool cornerBlobs;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AuthPalette.cream, AuthPalette.creamDeep],
        ).createShader(rect),
    );

    // Warm glow behind the illustration (upper right).
    final glowCenter = Offset(w * 0.8, h * 0.22);
    canvas.drawCircle(
      glowCenter,
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [AuthPalette.peachSoft.withValues(alpha: 0.75), AuthPalette.peachSoft.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: w * 0.42)),
    );

    if (!cornerBlobs) return;

    final blob = Paint()..color = AuthPalette.peach;
    final blobSoft = Paint()..color = AuthPalette.peachSoft;

    // Corner blobs: each edge is a convex bulge (control points pushed out
    // past the chord toward the screen centre), not a straight diagonal.
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w * 0.3, 0)
        ..cubicTo(w * 0.29, h * 0.06, w * 0.13, h * 0.115, 0, h * 0.12)
        ..close(),
      blob,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h)
        ..lineTo(w, h * 0.84)
        ..cubicTo(w * 0.9, h * 0.855, w * 0.76, h * 0.93, w * 0.66, h)
        ..close(),
      blobSoft,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.94)
        ..cubicTo(w * 0.08, h * 0.935, w * 0.16, h * 0.965, w * 0.2, h)
        ..close(),
      blob,
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => oldDelegate.cornerBlobs != cornerBlobs;
}

/// Login's footer: the line-art town skyline with the community caption
/// under it.
class AuthLoginFooter extends StatelessWidget {
  const AuthLoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 400 / 110,
              child: SvgPicture.asset('assets/illustrations/auth_skyline.svg', fit: BoxFit.fill),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Local People   |   Local Shops   |   Stronger Communities',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AuthPalette.mutedText),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Register's footer: hills, a little town with a location pin, and the
/// "Support Local / Grow Together" script (overlaid in Caveat).
class AuthRegisterFooter extends StatelessWidget {
  const AuthRegisterFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 400 / 130,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / 400;
            return Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.asset('assets/illustrations/auth_footer_register.svg', fit: BoxFit.fill),
                Align(
                  alignment: const Alignment(0.7, -0.62),
                  child: AuthScriptText('Support Local\nGrow Together', size: 20 * scale, angle: -0.14),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
