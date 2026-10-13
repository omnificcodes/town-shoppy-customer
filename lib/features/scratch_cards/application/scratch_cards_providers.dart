import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../business/application/business_context.dart';
import '../data/models/scratch_card.dart';
import '../data/scratch_cards_repository.dart';

/// The signed-in customer's scratch cards, unscratched first (the server
/// orders them). Per account, so it watches the session epoch.
final myScratchCardsProvider = FutureProvider<List<CustomerScratchCard>>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(scratchCardsRepositoryProvider).myCards();
});

/// How many cards are waiting to be scratched -- Home's banner reads this.
final unscratchedScratchCardCountProvider = Provider<int>((ref) {
  return ref.watch(myScratchCardsProvider).value?.where((c) => c.isUnscratched).length ?? 0;
});

final scratchCardProvider = FutureProvider.autoDispose.family<CustomerScratchCard, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(scratchCardsRepositoryProvider).show(id);
});

/// The shop's designs and what its plan allows -- the Business app's
/// Scratch cards screen, the counter's picker and the approve flow.
final scratchCardDesignsProvider = FutureProvider<ScratchCardDesigns>((ref) async {
  ref.watch(sessionEpochProvider);
  final merchantId = ref.watch(myMerchantIdProvider);
  if (merchantId == null) return const ScratchCardDesigns(items: [], enabled: false, remaining: 0);
  return ref.watch(scratchCardsRepositoryProvider).designs(merchantId);
});
