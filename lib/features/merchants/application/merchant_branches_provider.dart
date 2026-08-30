import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchants_repository.dart';
import '../data/models/merchant_branch_ref.dart';

/// Deliberately does NOT watch `sessionEpochProvider` — same reasoning as
/// `merchantDetailProvider`/`merchantCategoriesProvider`: a merchant's
/// branch list is public, non-personalized data, identical for every caller.
final merchantBranchesProvider = FutureProvider.family<List<MerchantBranchRef>, int>((ref, merchantId) {
  return ref.watch(merchantsRepositoryProvider).getBranches(merchantId);
});
