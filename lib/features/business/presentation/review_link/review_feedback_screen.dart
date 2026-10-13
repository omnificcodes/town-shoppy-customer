import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../application/review_link_providers.dart';
import '../widgets/business_page_header.dart';
import 'review_link_widgets.dart';

/// Every rating given through the review link: the private notes from
/// 1-3 star ratings, or all ratings including those sent to Google.
class ReviewFeedbackScreen extends ConsumerStatefulWidget {
  const ReviewFeedbackScreen({super.key});

  @override
  ConsumerState<ReviewFeedbackScreen> createState() => _ReviewFeedbackScreenState();
}

class _ReviewFeedbackScreenState extends ConsumerState<ReviewFeedbackScreen> {
  bool _privateOnly = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reviewResponsesProvider(_privateOnly));

    return BusinessScaffold(
      title: 'Customer feedback',
      padded: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Private notes'), icon: Icon(Icons.lock_outline_rounded)),
                  ButtonSegment(value: false, label: Text('All ratings'), icon: Icon(Icons.star_outline_rounded)),
                ],
                selected: {_privateOnly},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.businessInk,
                  selectedForegroundColor: AppColors.onBusinessInk,
                ),
                onSelectionChanged: (v) => setState(() => _privateOnly = v.first),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingSkeletonList(),
              error: (e, _) => ErrorState(
                error: e is AppException ? e : const UnknownAppException(),
                title: 'Could not load feedback.',
                onRetry: () => ref.invalidate(reviewResponsesProvider(_privateOnly)),
              ),
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: _privateOnly ? Icons.sentiment_satisfied_alt_rounded : Icons.star_outline_rounded,
                      title: _privateOnly ? 'No private notes yet' : 'No ratings yet',
                      message: _privateOnly
                          ? 'Notes from customers who rate you 1 to 3 stars show here, only for you.'
                          : 'Ratings show here as soon as customers scan your review QR.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(reviewResponsesProvider(_privateOnly)),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xxl),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => ReviewResponseCard(response: items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
