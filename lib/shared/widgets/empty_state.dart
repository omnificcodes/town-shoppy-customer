import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'state_panel.dart';

/// Friendly, contextual empty state (section 35) — every list screen in the
/// app uses this instead of a bare "No data" label. [secondaryAction] is
/// for the states that need a real recovery step *and* a retry (e.g. "Open
/// location settings" + "Try again").
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.secondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StatePanel(
      icon: icon,
      iconColor: AppColors.textDisabled,
      title: title,
      message: message,
      action: action,
      secondaryAction: secondaryAction,
      compact: compact,
    );
  }
}
