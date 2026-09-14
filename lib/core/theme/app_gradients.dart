import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Named gradients for the Stitch-era screens. A gradient is a surface
/// treatment, so it lives here beside [AppColors] instead of being rebuilt
/// inline in each widget -- one place to retune the app's warm sweep.
class AppGradients {
  AppGradients._();

  /// Home's promo hero. Holds [AppColors.orangeDeep] across the left half,
  /// where the white headline and copy sit, and only brightens to the brand
  /// orange under the decorative right side, so the text stays on the shade
  /// that clears WCAG AA.
  static const promoHero = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.orangeDeep, AppColors.orangeDeep, AppColors.orange],
    stops: [0, 0.5, 1],
  );

  /// A soft cream-to-honey wash for a highlighted panel, such as Home's
  /// association partners. Dark text only.
  static const warmWash = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.orangeTint, AppColors.goldLight],
  );
}
