import '../../../core/app_mode/app_mode.dart';
import '../../business/presentation/business_routes.dart';

/// Where tapping a notification should take the user, and which
/// [AppMode] that destination lives in -- a single inbox can hold both
/// customer notifications (a purchase, a redemption) and business ones (a
/// payment, an invoice) for an account that runs a shop, so the tap
/// handler must be ready to switch modes before navigating, not just push.
class NotificationTarget {
  const NotificationTarget(this.path, this.mode);

  final String path;
  final AppMode mode;

  @override
  bool operator ==(Object other) => other is NotificationTarget && other.path == path && other.mode == mode;

  @override
  int get hashCode => Object.hash(path, mode);
}

/// None of the 29 `NotificationType` values the backend can send carry the
/// underlying record's id in their `data` payload (only display fields --
/// amounts, names, counts; see each dispatch call site in town-shoppy-api).
/// So every target here is the closest existing screen that already shows
/// that notification's kind of event, not a specific record by id -- the
/// customer/merchant still lands on exactly the right list (almost always
/// with the relevant item at or near the top, newest-first) rather than
/// nowhere at all. Route strings mirror `app_router.dart`'s own private
/// path constants for the customer tree (there is no public routes class
/// there, unlike `BusinessRoutes`) -- keep the two in sync if either moves.
///
/// Takes the bare type string (not an `AppNotification`) so both the
/// in-app tap handler (`NotificationsScreen`) and an FCM push tap can
/// share it -- a push message's `data` payload carries `type` (see
/// PushNotificationChannel on the backend) but has no reason to carry a
/// full notification resource.
NotificationTarget? notificationTarget(String type) {
  return switch (type) {
    'purchase.recorded' ||
    'purchase.coupon_generated' ||
    'purchase.submitted' ||
    'purchase.rejected' =>
      const NotificationTarget('/purchases', AppMode.customer),
    'redemption.initiated' ||
    'redemption.completed' ||
    'redemption.cancelled' ||
    'redemption.expired' =>
      const NotificationTarget('/redemptions', AppMode.customer),
    // Both fired for the merchant, never the customer: a customer is
    // waiting to be verified at the counter, or a redemption they already
    // verified has now settled (Coin Economy V2 §8). A customer's coins
    // always ride on a purchase now -- scanned either way, or entered by
    // phone at Direct POS -- so Purchases is where the merchant acts.
    'redemption.awaiting_verification' || 'redemption.merchant_settled' =>
      const NotificationTarget(BusinessRoutes.purchases, AppMode.business),
    'referral.qualified' || 'referral.reward_received' || 'referral.milestone_reached' =>
      const NotificationTarget('/referrals', AppMode.customer),
    'subscription.activated' ||
    'subscription.cancelled' ||
    'subscription.grace_period' ||
    'subscription.expired_suspended' =>
      const NotificationTarget(BusinessRoutes.subscriptions, AppMode.business),
    'payment.successful' || 'payment.failed' || 'payment.refund_confirmed' =>
      const NotificationTarget(BusinessRoutes.payments, AppMode.business),
    'payment.invoice_available' => const NotificationTarget(BusinessRoutes.invoices, AppMode.business),
    // The two moments a merchant applicant is waiting to hear about --
    // both land on the profile screen, which shows the resulting status
    // (Active / Rejected) either way.
    'merchant.approved' || 'merchant.rejected' => const NotificationTarget(BusinessRoutes.profile, AppMode.business),
    // Sent to the merchant owner (a customer requested a coin discount on
    // one of their offers), not the customer.
    'offer_redemption.requested' => const NotificationTarget(BusinessRoutes.offerRedemptions, AppMode.business),
    'offer_redemption.approved' || 'offer_redemption.rejected' =>
      const NotificationTarget('/offer-redemptions', AppMode.customer),
    // Product coupons: the shop's queue for the request; the customer's
    // coupons once accepted, or the catalog to ask again once declined.
    'product_coupon.requested' => const NotificationTarget(BusinessRoutes.productCouponRequests, AppMode.business),
    'product_coupon.approved' => const NotificationTarget('/coupons', AppMode.customer),
    'product_coupon.rejected' => const NotificationTarget('/shopping', AppMode.customer),
    // A shop gave the customer a scratch card with their bill.
    'scratch_card.received' => const NotificationTarget('/scratch-cards', AppMode.customer),
    // A stamp landed, the card is full, or the reward was claimed.
    'stamp_card.stamped' || 'stamp_card.full' || 'stamp_card.rewarded' =>
      const NotificationTarget('/stamp-cards', AppMode.customer),
    // A customer rated the shop 1-3 stars and left a private note.
    'review_link.feedback' => const NotificationTarget(BusinessRoutes.reviewLinkFeedback, AppMode.business),
    // The winning customer's own wins list.
    'draw.won' => const NotificationTarget('/lucky-draw/my-wins', AppMode.customer),
    // The sponsoring merchant, never the winning customer.
    'prize.won' => const NotificationTarget(BusinessRoutes.prizes, AppMode.business),
    'wallet.shop_exclusive_coin_expiring' => const NotificationTarget('/wallet', AppMode.customer),
    _ => null,
  };
}
