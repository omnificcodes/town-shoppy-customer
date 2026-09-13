import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// On a wide browser window (laptop/desktop), letterboxes the whole app
/// into a centered phone-width card instead of stretching every screen
/// edge-to-edge -- this app's layouts are all designed and tested at phone
/// widths (see `kResponsiveViewportSizes`), never for a 1440px-wide
/// `Scaffold`. Every other target is untouched:
///
/// * Android and iOS builds: `kIsWeb` is false, so this returns [child] as
///   the very first check, before anything else runs.
/// * The web build opened on an actual mobile browser (a narrow window):
///   already phone-width, so framing it again would just shrink it further
///   for no reason -- returns [child] unchanged below [_desktopBreakpoint].
///
/// Wraps the framed [child] in a fresh [MediaQuery] reporting the frame's
/// own size, so every descendant's own responsive/breakpoint logic (built
/// and tested only against real phone dimensions) sees a phone viewport
/// too, not the outer browser window.
class WebPhoneFrame extends StatelessWidget {
  const WebPhoneFrame({super.key, required this.child});

  final Widget? child;

  /// Below this window width, the browser itself is already phone-sized
  /// (a real mobile browser, or a narrow desktop window) -- don't frame.
  static const double _desktopBreakpoint = 640;

  /// Matches the widest phone this app's own responsive tests cover
  /// (`kResponsiveViewportSizes`'s Pro-Max-class entry), so every screen
  /// renders inside the frame exactly as already designed and tested.
  static const double _frameWidth = 430;

  /// Caps how tall the frame gets on a very tall monitor -- a phone screen
  /// is never actually this size in real life either.
  static const double _maxFrameHeight = 900;

  @override
  Widget build(BuildContext context) {
    final content = child;
    if (!kIsWeb || content == null) return content ?? const SizedBox.shrink();

    final window = MediaQuery.sizeOf(context);
    if (window.width < _desktopBreakpoint) return content;

    final frameHeight = window.height < _maxFrameHeight ? window.height : _maxFrameHeight;
    final outerMediaQuery = MediaQuery.of(context);

    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: SizedBox(
          width: _frameWidth,
          height: frameHeight,
          child: PhysicalModel(
            color: AppColors.surface,
            elevation: 24,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            clipBehavior: Clip.antiAlias,
            child: MediaQuery(
              // Everything below this point (every screen's own responsive
              // logic, safe-area insets, text scaling) now measures against
              // the frame, not the real browser window.
              data: outerMediaQuery.copyWith(
                size: Size(_frameWidth, frameHeight),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
