import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/review_link.dart';
import '../data/review_link_repository.dart';
import 'business_context.dart';

/// The shop's review link, its results and whether the plan includes it.
final reviewLinkProvider = FutureProvider<ReviewLinkOverview>((ref) async {
  ref.watch(sessionEpochProvider);
  final merchantId = ref.watch(myMerchantIdProvider);
  if (merchantId == null) return const ReviewLinkOverview(enabled: false, link: null, stats: ReviewStats.empty);
  return ref.watch(reviewLinkRepositoryProvider).overview(merchantId);
});

/// Ratings given through the link, newest first. `true` keeps only the
/// private notes from 1-3 star ratings.
final reviewResponsesProvider = FutureProvider.autoDispose.family<List<ReviewResponse>, bool>((ref, privateOnly) async {
  ref.watch(sessionEpochProvider);
  final merchantId = ref.watch(myMerchantIdProvider);
  if (merchantId == null) return const [];
  return ref.watch(reviewLinkRepositoryProvider).responses(merchantId, privateOnly: privateOnly);
});
