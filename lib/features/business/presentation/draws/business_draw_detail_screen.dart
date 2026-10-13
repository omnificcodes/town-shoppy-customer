import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../lucky_draw/application/draws_list_controller.dart';
import '../../../lucky_draw/presentation/draw_story.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// One draw's full story in Business mode (BR-44). The same shared body as
/// the customer page; the backend adds the real name, number and coupon
/// code of the winners of THIS shop's own sponsored prizes, so the shop
/// can hand the gift over.
class BusinessDrawDetailScreen extends ConsumerWidget {
  const BusinessDrawDetailScreen({super.key, required this.drawId});

  final int drawId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draw = ref.watch(drawDetailProvider(drawId));

    return BusinessScaffold(
      title: 'Draw results',
      padded: false,
      body: draw.when(
        loading: () => const LoadingSkeletonList(count: 2),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(drawDetailProvider(drawId)),
        ),
        data: (drawData) => DrawStoryBody(
          draw: drawData,
          watchPath: '${BusinessRoutes.draws}/$drawId/watch',
          business: true,
        ),
      ),
    );
  }
}
