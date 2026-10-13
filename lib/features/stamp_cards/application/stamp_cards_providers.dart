import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../business/application/business_context.dart';
import '../data/models/stamp_card.dart';
import '../data/stamp_cards_repository.dart';

/// The signed-in customer's stamp cards: full first, then collecting, then
/// rewarded history (the server orders them). Per account.
final myStampCardsProvider = FutureProvider<List<CustomerStampCard>>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(stampCardsRepositoryProvider).myCards();
});

final stampCardProvider = FutureProvider.autoDispose.family<CustomerStampCard, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(stampCardsRepositoryProvider).show(id);
});

/// The shop's programmes and what its plan allows -- the Business app's
/// Stamp cards screen, the counter and the approve flow.
final stampCardProgrammesProvider = FutureProvider<StampCardProgrammes>((ref) async {
  ref.watch(sessionEpochProvider);
  final merchantId = ref.watch(myMerchantIdProvider);
  if (merchantId == null) return const StampCardProgrammes(items: [], enabled: false, limit: 0, activeCount: 0);
  return ref.watch(stampCardsRepositoryProvider).programmes(merchantId);
});

/// A customer's live cards at this shop, by profile id -- what the counter
/// shows once it has looked the customer up.
final customerStampProgressProvider = FutureProvider.autoDispose.family<List<CustomerStampCard>, int>((ref, customerProfileId) async {
  ref.watch(sessionEpochProvider);
  final merchantId = ref.watch(myMerchantIdProvider);
  if (merchantId == null) return const [];
  final result = await ref.watch(stampCardsRepositoryProvider).lookup(merchantId: merchantId, customerProfileId: customerProfileId);
  return result.cards;
});

/// The programme chosen to stamp with the bill being entered at the
/// counter, or null for none. Beside the form state, like the scratch
/// card choice: it never changes the bill's signature.
class DirectPosStampController extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? programmeId) => state = programmeId;
}

final directPosStampProvider = NotifierProvider.autoDispose<DirectPosStampController, int?>(DirectPosStampController.new);
