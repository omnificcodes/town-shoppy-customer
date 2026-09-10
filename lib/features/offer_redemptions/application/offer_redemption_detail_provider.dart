import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/offer_redemption.dart';
import '../data/offer_redemptions_repository.dart';

final offerRedemptionDetailProvider = FutureProvider.family<OfferRedemption, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(offerRedemptionsRepositoryProvider).show(id);
});
