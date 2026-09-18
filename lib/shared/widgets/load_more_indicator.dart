import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The row at the foot of a paginated list while its next page loads.
///
/// Every list screen used to inline its own copy of this -- some twenty of
/// them -- as a bare, full-size `CircularProgressIndicator`. Two things were
/// wrong with that beyond the repetition: the default 36dp spinner is sized
/// for a whole-screen wait, so it shouted at the bottom of a list where a
/// quiet "more is coming" is all that's needed; and only about half the
/// copies carried a `semanticsLabel`, so a screen reader announced a load on
/// some lists and said nothing on the rest.
///
/// [label] names what is loading ("Loading more purchases") for assistive
/// tech; it is never shown.
class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({super.key, this.label = 'Loading more'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: AppIconSize.lg,
          height: AppIconSize.lg,
          child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: label),
        ),
      ),
    );
  }
}
