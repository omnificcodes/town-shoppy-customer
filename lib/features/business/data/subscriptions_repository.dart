import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/merchant_entitlement.dart';
import 'models/merchant_subscription.dart';
import 'models/subscription_checkout.dart';
import 'models/subscription_plan.dart';

/// The subscription domain: reading plans/entitlement/the current
/// subscription, plus (Android only -- see `subscription_checkout_
/// controller.dart`) creating and verifying a native Razorpay payment
/// intent. iOS and the web build never call [createCheckoutIntent] /
/// [verifyPayment]; checkout there stays a hand-off to the merchant web
/// app (see `Env.merchantWebUrl`).
class SubscriptionsRepository {
  SubscriptionsRepository(this._dio);

  final Dio _dio;

  /// `GET /subscriptions/plans` -- public, active plans, cheapest first.
  Future<List<SubscriptionPlan>> plans() async {
    try {
      final response = await _dio.get('/subscriptions/plans');
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .where((p) => p.isActive)
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /subscriptions/entitlement` -- Owner and Staff.
  Future<MerchantEntitlement> entitlement() async {
    try {
      final response = await _dio.get('/subscriptions/entitlement');
      return MerchantEntitlement.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /subscriptions/me` -- Owner only (403 for staff, which callers
  /// must avoid by not asking). `null` when the shop never subscribed.
  Future<MerchantSubscription?> mine() async {
    try {
      final response = await _dio.get('/subscriptions/me');
      final data = ApiEnvelope.data(response);
      return data is Map ? MerchantSubscription.fromJson(Map<String, dynamic>.from(data)) : null;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /subscriptions/start-trial` -- Owner only (BR-43): starts a
  /// plan's free trial without payment, once per shop.
  Future<MerchantSubscription> startTrial(int planId) async {
    try {
      final response = await _dio.post('/subscriptions/start-trial', data: {'subscription_plan_id': planId});
      return MerchantSubscription.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /payments/subscriptions/intent` -- Owner only. `planId` is the
  /// only input; the amount charged is derived server-side from that
  /// plan's price. `Idempotency-Key` matches the same header every other
  /// write endpoint in this app sends: retrying with the same key after a
  /// dropped response replays the original payment rather than creating a
  /// second one.
  Future<SubscriptionCheckoutIntent> createCheckoutIntent({required int planId, required String idempotencyKey}) async {
    try {
      final response = await _dio.post(
        '/payments/subscriptions/intent',
        data: {'subscription_plan_id': planId},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return SubscriptionCheckoutIntent.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /payments/{id}/verify` -- confirms the Razorpay checkout
  /// signature server-side and, on success, activates the subscription
  /// and issues its invoice. `paymentId` is this app's own Payment record
  /// id (from [createCheckoutIntent]); the other three fields are exactly
  /// what the Razorpay SDK's success callback hands back.
  Future<void> verifyPayment({
    required int paymentId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String signature,
  }) async {
    try {
      await _dio.post(
        '/payments/$paymentId/verify',
        data: {'payment_id': razorpayPaymentId, 'order_id': razorpayOrderId, 'signature': signature},
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return SubscriptionsRepository(ref.watch(apiClientProvider).dio);
});
