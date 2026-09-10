import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/offer.dart';
import '../data/offers_repository.dart';

/// Deliberately does NOT watch `sessionEpochProvider` -- same reasoning as
/// `merchantDetailProvider`: a public offer's detail is identical
/// regardless of which account is asking.
final offerDetailProvider = FutureProvider.family<Offer, int>((ref, id) {
  return ref.watch(offersRepositoryProvider).show(id);
});
