import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../purchases/data/models/purchase.dart';
import '../data/business_activity_repository.dart';
import '../data/business_merchant_repository.dart';
import '../data/models/business_merchant.dart';
import '../data/models/merchant_entitlement.dart';
import '../data/models/merchant_subscription.dart';
import '../data/models/purchase_stats.dart';
import '../data/models/subscription_plan.dart';
import '../data/subscriptions_repository.dart';

/// Which merchant this account operates, straight from `/auth/me` (owner
/// profile wins over staff; one merchant per account). `null` outside
/// Business mode's reach -- the router never lets a `null` here into a
/// `/business` route, so screens may treat it as non-null after a guard.
final myMerchantIdProvider = Provider<int?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated ? auth.account.activeMerchantId : null;
});

/// Owner vs Staff decides what Business mode shows: staff never see
/// billing, prize sponsorship, or profile/offer/branch editing -- the same
/// split the backend policies enforce and the merchant web app draws.
final isBusinessOwnerProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated && auth.account.isMerchantOwner;
});

/// The shop itself (`MerchantPrivateResource`). Every Business screen that
/// needs the name/logo/status reads this one cached value; editing the
/// profile invalidates it.
final myMerchantProvider = FutureProvider<BusinessMerchant>((ref) {
  ref.watch(sessionEpochProvider);
  final id = ref.watch(myMerchantIdProvider);
  if (id == null) throw const ForbiddenException('This account does not operate a business.');
  return ref.watch(businessMerchantRepositoryProvider).show(id);
});

/// Package gate input. Fails OPEN on any error, exactly like the merchant
/// web app -- the backend still returns 402 on every gated call, so a
/// transient failure here can never grant anything, only avoid a false
/// "locked" screen for a shop that has paid.
final merchantEntitlementProvider = FutureProvider<MerchantEntitlement>((ref) async {
  ref.watch(sessionEpochProvider);
  try {
    return await ref.watch(subscriptionsRepositoryProvider).entitlement();
  } on AppException {
    return MerchantEntitlement.failOpen;
  }
});

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) {
  return ref.watch(subscriptionsRepositoryProvider).plans();
});

/// `GET /subscriptions/me` is Owner-only -- resolves to `null` for staff
/// without ever asking (a 403 would be noise, not information).
final mySubscriptionProvider = FutureProvider<MerchantSubscription?>((ref) {
  ref.watch(sessionEpochProvider);
  if (!ref.watch(isBusinessOwnerProvider)) return null;
  return ref.watch(subscriptionsRepositoryProvider).mine();
});

final purchaseStatsProvider = FutureProvider.family<PurchaseStats, String>((ref, range) {
  ref.watch(sessionEpochProvider);
  return ref.watch(businessActivityRepositoryProvider).stats(range: range);
});

final dashboardRecentPurchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  ref.watch(sessionEpochProvider);
  return (await ref.watch(businessActivityRepositoryProvider).purchases(perPage: 5)).items;
});

/// `meta.total` of a one-item page -- the cheapest "how many pending" the
/// backend offers (same trick as the web dashboard).
final dashboardPendingPurchasesCountProvider = FutureProvider<int>((ref) async {
  ref.watch(sessionEpochProvider);
  return (await ref.watch(businessActivityRepositoryProvider).purchases(perPage: 1, status: 'pending')).total;
});
