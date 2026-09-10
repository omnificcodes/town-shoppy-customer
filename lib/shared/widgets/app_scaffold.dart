import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Shared screen wrapper — one app bar treatment, safe-area, and the
/// standard page margin for every secondary (pushed) screen. Top-level tab
/// screens with a custom header (Home) build their own chrome; everything
/// else should go through this so back buttons, titles and margins match.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.bottom,
    this.padded = true,
    this.floatingActionButton,
    this.bottomBar,
    this.backgroundColor,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  /// Wraps [body] in the page margin. Pass false for scrolling lists that
  /// apply their own padding (so the scrollbar/overscroll reach the edge).
  final bool padded;

  final Widget? floatingActionButton;

  /// A persistent bar pinned under the body (e.g. a primary CTA that must
  /// stay visible while a form scrolls).
  final Widget? bottomBar;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: Text(title), actions: actions, leading: leading, bottom: bottom),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
                child: bottomBar,
              ),
            ),
      body: SafeArea(
        bottom: bottomBar == null,
        child: padded ? Padding(padding: const EdgeInsets.all(AppSpacing.page), child: body) : body,
      ),
    );
  }
}
