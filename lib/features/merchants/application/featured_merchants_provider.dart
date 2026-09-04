import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchants_repository.dart';
import '../data/models/merchant.dart';

/// Home's "Featured Businesses" section — `GET /merchants?featured=1`,
/// Super-Admin-curated (`MerchantPolicy::feature()`). A handful is enough
/// for a Home carousel, so this is a flat one-shot fetch, not a paginated
/// controller like `MerchantsListController`.
final featuredMerchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final page = await ref.watch(merchantsRepositoryProvider).list(perPage: 10, featured: true);
  return page.items;
});
