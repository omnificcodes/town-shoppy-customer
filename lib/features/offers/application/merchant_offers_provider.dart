import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/offer.dart';
import '../data/offers_repository.dart';

/// One merchant's currently running offers (`GET /offers?merchant_id=`), for
/// the offers section on that merchant's detail page. The first page is
/// enough: a single shop rarely runs more than a handful at once.
final merchantOffersProvider = FutureProvider.family<List<Offer>, int>((ref, merchantId) async {
  ref.watch(sessionEpochProvider);
  final page = await ref.watch(offersRepositoryProvider).list(merchantId: merchantId);
  return page.items;
});
