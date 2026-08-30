import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four viewports Phase 9/10 verify every major customer screen against:
/// a small phone (iPhone SE class), a mid phone (iPhone 12/13/14 class), a
/// large phone (iPhone Pro Max class), and a tablet/small-desktop-web width.
/// Exact logical pixels via Flutter's own test framework -- not a browser
/// screenshot -- see the Phase 9/10 reports for why.
const kResponsiveViewportSizes = [
  Size(375, 812),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
];

/// Pumps a fresh [builder] widget at each of [sizes], asserting no layout
/// exception (e.g. a RenderFlex overflow) occurred, then runs [verify] so
/// the caller can assert its own screen-specific PASS conditions (a primary
/// CTA is visible, key text/values are present, long content didn't get
/// silently dropped) before the surface is reset for the next size.
///
/// [builder] is called once per size so each iteration gets its own
/// ProviderScope/controllers rather than reusing state across sizes.
Future<void> forEachViewport(
  WidgetTester tester,
  Widget Function() builder, {
  List<Size> sizes = kResponsiveViewportSizes,
  Future<void> Function(WidgetTester tester, Size size)? verify,
  bool settle = true,
}) async {
  for (final size in sizes) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(builder());
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }

    expect(tester.takeException(), isNull, reason: 'Unexpected exception at $size');

    if (verify != null) await verify(tester, size);

    // Unmount before the next size so any live Timer in this screen is
    // disposed rather than leaking into the next iteration.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }
}
