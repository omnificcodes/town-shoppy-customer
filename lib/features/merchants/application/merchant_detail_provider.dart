import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchants_repository.dart';
import '../data/models/merchant.dart';

/// Deliberately does NOT watch `sessionEpochProvider` — see
/// `merchantCategoriesProvider`'s docblock for why: a merchant's public
/// profile is identical regardless of which account is asking.
final merchantDetailProvider = FutureProvider.family<Merchant, int>((ref, id) {
  return ref.watch(merchantsRepositoryProvider).show(id);
});
