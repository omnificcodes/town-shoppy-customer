import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/idempotency_key.dart';
import '../data/models/subscription_plan.dart';
import '../data/subscriptions_repository.dart';
import 'business_context.dart';

/// Android-only native subscription checkout (see the doc comment on
/// [SubscriptionsRepository]). Wraps the Razorpay Flutter SDK -- an
/// event-driven callback API, not a plain Future -- behind the same
/// request/response shape every other write flow in this app uses.

/// Whether this build can use native checkout at all -- Android only,
/// never iOS or the web build (see [SubscriptionsRepository]'s doc
/// comment for why). A provider rather than a bare top-level function
/// purely so a test can override it; the real check itself never changes
/// at runtime. `!kIsWeb` short-circuits before `Platform.isAndroid` runs,
/// which throws if actually evaluated on a web build.
final nativeCheckoutAvailableProvider = Provider<bool>((ref) => !kIsWeb && Platform.isAndroid);

enum SubscriptionCheckoutStatus { idle, creatingIntent, awaitingPayment, verifying, success, error }

class SubscriptionCheckoutState {
  const SubscriptionCheckoutState({this.status = SubscriptionCheckoutStatus.idle, this.planId, this.error, this.completedPlanName});

  final SubscriptionCheckoutStatus status;

  /// Which plan this state is about, so a screen with several plan cards
  /// can put the spinner/error on the right one instead of all of them.
  final int? planId;
  final AppException? error;

  /// Set only on [SubscriptionCheckoutStatus.success], for the screen's
  /// confirmation message.
  final String? completedPlanName;

  bool get isBusy => status == SubscriptionCheckoutStatus.creatingIntent || status == SubscriptionCheckoutStatus.awaitingPayment || status == SubscriptionCheckoutStatus.verifying;

  bool isBusyFor(int id) => planId == id && isBusy;

  bool isErrorFor(int id) => planId == id && status == SubscriptionCheckoutStatus.error;
}

class SubscriptionCheckoutController extends Notifier<SubscriptionCheckoutState> {
  late final Razorpay _razorpay;

  /// Set for the lifetime of one checkout attempt -- from [start] until the
  /// SDK's success/error callback fires. Not part of [SubscriptionCheckoutState]
  /// itself since nothing outside this controller ever needs to read it.
  int? _paymentId;
  SubscriptionPlan? _plan;

  @override
  SubscriptionCheckoutState build() {
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    ref.onDispose(_razorpay.clear);
    return const SubscriptionCheckoutState();
  }

  /// Creates the payment intent, then opens Razorpay's native checkout
  /// sheet. [contactNumber] prefills the sheet's phone field; Razorpay
  /// itself decides what else (card, UPI, wallet) to offer.
  Future<void> start(SubscriptionPlan plan, {required String contactNumber}) async {
    if (state.isBusy) return;

    _plan = plan;
    _paymentId = null;
    state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.creatingIntent, planId: plan.id);

    try {
      final intent = await ref.read(subscriptionsRepositoryProvider).createCheckoutIntent(planId: plan.id, idempotencyKey: generateIdempotencyKey());
      _paymentId = intent.paymentId;
      state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.awaitingPayment, planId: plan.id);

      _razorpay.open({
        'key': intent.key,
        'order_id': intent.orderId,
        'amount': intent.amountInPaise,
        'currency': intent.currency,
        'name': 'Town Shoppy',
        'description': '${plan.name} subscription — ${plan.billingCycle}',
        'prefill': {'contact': contactNumber},
        'theme': {'color': _themeColorHex},
      });
    } on AppException catch (e) {
      state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.error, planId: plan.id, error: e);
    }
  }

  /// Back to [SubscriptionCheckoutStatus.idle] -- called once the screen
  /// has shown whatever a terminal state (success or error) needed to say.
  void acknowledge() => state = const SubscriptionCheckoutState();

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = _paymentId;
    final plan = _plan;
    if (paymentId == null || plan == null) return;

    state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.verifying, planId: plan.id);
    try {
      await ref.read(subscriptionsRepositoryProvider).verifyPayment(
            paymentId: paymentId,
            razorpayPaymentId: response.paymentId ?? '',
            razorpayOrderId: response.orderId ?? '',
            signature: response.signature ?? '',
          );
      ref
        ..invalidate(mySubscriptionProvider)
        ..invalidate(merchantEntitlementProvider)
        ..invalidate(subscriptionPlansProvider);
      state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.success, planId: plan.id, completedPlanName: plan.name);
    } on AppException {
      // Payment succeeded at the gateway; only its confirmation to us
      // failed (a dropped response, a signature mismatch). The webhook
      // (see town-shoppy-api's PaymentController::webhook) reconciles this
      // independently, so this is never lost money -- just an app-side
      // "we're not sure yet" that support can resolve from the reference.
      state = SubscriptionCheckoutState(
        status: SubscriptionCheckoutStatus.error,
        planId: plan.id,
        error: const UnknownAppException("Payment succeeded, but we couldn't confirm it here. It will apply automatically once confirmed — contact support if it doesn't within a few minutes."),
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final plan = _plan;
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      // The merchant closed the sheet themselves -- back to idle with no
      // error banner, the same as dismissing the web checkout modal.
      state = const SubscriptionCheckoutState();
      return;
    }

    state = SubscriptionCheckoutState(
      status: SubscriptionCheckoutStatus.error,
      planId: plan?.id,
      error: UnknownAppException(response.message?.trim().isNotEmpty == true ? response.message!.trim() : 'Payment failed. Please try again.'),
    );
  }

  /// Razorpay's own sheet drives the external-wallet flow to completion by
  /// itself; the payment's outcome still arrives as the normal success/
  /// error event afterwards, so there is nothing to do here.
  void _onExternalWallet(ExternalWalletResponse response) {}

  static String get _themeColorHex {
    final c = AppColors.businessInk;
    return '#${c.toARGB32().toRadixString(16).substring(2)}';
  }
}

final subscriptionCheckoutControllerProvider = NotifierProvider.autoDispose<SubscriptionCheckoutController, SubscriptionCheckoutState>(
  SubscriptionCheckoutController.new,
);
