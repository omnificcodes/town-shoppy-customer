import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Shared screen wrapper — consistent app bar + safe-area + horizontal
/// padding for every top-level customer screen.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.padded = true,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool padded;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: padded
            ? Padding(padding: const EdgeInsets.all(AppSpacing.md), child: body)
            : body,
      ),
    );
  }
}
