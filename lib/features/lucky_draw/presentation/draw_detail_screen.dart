import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/draws_list_controller.dart';
import 'draw_story.dart';

/// A completed draw's full public story (BR-44): winners, prizes and their
/// units, sponsor shops, where the entries came from, every entry, and who
/// conducted the draw -- plus "Watch the draw", the animated replay.
///
/// "Did I win?" is deliberately NOT answered here from the winners list --
/// `DrawWinnerResource.winner_label` is a masked "Priya S." with no
/// customer id, so nothing the customer app receives ties a win to *this*
/// draw without guessing. The story's banner instead sends the customer to
/// My winnings, which is own-account-only and therefore authoritative.
class DrawDetailScreen extends ConsumerWidget {
  const DrawDetailScreen({super.key, required this.drawId});

  final int drawId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draw = ref.watch(drawDetailProvider(drawId));

    return AppScaffold(
      title: 'Draw results',
      padded: false,
      body: draw.when(
        loading: () => const LoadingSkeletonList(count: 2),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(drawDetailProvider(drawId)),
        ),
        data: (drawData) => DrawStoryBody(draw: drawData, watchPath: '/lucky-draw/$drawId/watch'),
      ),
    );
  }
}
