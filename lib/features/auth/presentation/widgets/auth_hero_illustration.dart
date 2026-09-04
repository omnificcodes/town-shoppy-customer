import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'auth_widgets.dart';

enum AuthHeroVariant { login, register }

/// The auth screens' hero art: a hand-drawn SVG (shopping bag, leaves,
/// and — on Login — a storefront, cloud and sparkles) with its lettering
/// overlaid by Flutter so the script uses the bundled Caveat font instead
/// of relying on SVG `<text>` support. Overlays are placed by mapping
/// viewBox coordinates to [Alignment], which is exact because the SVG is
/// drawn inside an [AspectRatio] matching its own viewBox.
class AuthHeroIllustration extends StatelessWidget {
  const AuthHeroIllustration({super.key, required this.variant});

  final AuthHeroVariant variant;

  static const _viewBoxWidth = 330.0;
  static const _viewBoxHeight = 260.0;

  static Alignment _at(double x, double y) => Alignment(x / _viewBoxWidth * 2 - 1, y / _viewBoxHeight * 2 - 1);

  @override
  Widget build(BuildContext context) {
    final asset = switch (variant) {
      AuthHeroVariant.login => 'assets/illustrations/auth_hero_login.svg',
      AuthHeroVariant.register => 'assets/illustrations/auth_hero_register.svg',
    };

    // Decorative art: pinned text scale + no semantics, same rationale as
    // AuthScriptText.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: _viewBoxWidth / _viewBoxHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / _viewBoxWidth;
              return Stack(
                fit: StackFit.expand,
                children: [
                  SvgPicture.asset(asset, fit: BoxFit.fill),
                  // Lettering on the bag.
                  Align(
                    alignment: _at(156, 176),
                    child: AuthScriptText(
                      'Local Shops\nBrighter\nCommunities',
                      size: 21 * scale,
                      color: AuthPalette.brownInk,
                      align: TextAlign.center,
                      angle: -0.06,
                      lineHeight: 0.98,
                    ),
                  ),
                  if (variant == AuthHeroVariant.login)
                    // The storefront's sign board.
                    Align(
                      alignment: _at(278, 137),
                      child: Text(
                        'SHOP\nLOCAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AuthPalette.brown,
                          fontSize: 15.5 * scale,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
