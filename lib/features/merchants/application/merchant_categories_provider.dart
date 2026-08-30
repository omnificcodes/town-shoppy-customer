import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchant_categories_repository.dart';
import '../data/models/merchant_category.dart';

/// Unlike every customer-scoped provider elsewhere in the app, this does
/// NOT watch `sessionEpochProvider` — merchant categories are fully public,
/// non-personalized reference data, identical for every caller regardless
/// of which account (or no account) is signed in, so there is no
/// cross-account cache-isolation concern for it to guard against.
final merchantCategoriesProvider = FutureProvider<List<MerchantCategory>>((ref) {
  return ref.watch(merchantCategoriesRepositoryProvider).list();
});
