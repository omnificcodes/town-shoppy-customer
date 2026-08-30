import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_colors.dart';

/// WCAG 2.x relative luminance / contrast ratio, computed directly from the
/// real `AppColors` values -- not a snapshot of a rendered pixel, so this
/// stays accurate even if the app's theme/rendering changes, and fails loud
/// if a future palette edit silently regresses a token below AA again (the
/// exact scenario Phase 10 found undetected).
double _relativeLuminance(Color color) {
  double channel(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // WCAG AA for normal text. StatusBadge/InfoBox render status text at
  // ~11sp/bold, which does not qualify for the 3:1 "large text" exception
  // (requires ~18.7px / 14pt-bold or larger) -- see design-principles.md's
  // "Semantic status colors" section for the full reasoning and the
  // before/after table this test guards.
  const kMinContrast = 4.5;

  group('Semantic status color contrast (WCAG AA, normal text)', () {
    test('success on successBg', () {
      expect(contrastRatio(AppColors.success, AppColors.successBg), greaterThanOrEqualTo(kMinContrast));
    });

    test('pending on pendingBg', () {
      expect(contrastRatio(AppColors.pending, AppColors.pendingBg), greaterThanOrEqualTo(kMinContrast));
    });

    test('error on errorBg', () {
      expect(contrastRatio(AppColors.error, AppColors.errorBg), greaterThanOrEqualTo(kMinContrast));
    });

    test('info on infoBg', () {
      expect(contrastRatio(AppColors.info, AppColors.infoBg), greaterThanOrEqualTo(kMinContrast));
    });

    test('textPrimary on white surface', () {
      expect(contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(kMinContrast));
    });

    test('textSecondary on white surface', () {
      expect(contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(kMinContrast));
    });
  });
}
