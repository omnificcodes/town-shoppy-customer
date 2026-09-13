import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/merchant_entitlement.dart';
import 'models/merchant_subscription.dart';
import 'models/subscription_plan.dart';

/// Read side of the subscription domain. Payment itself is deliberately not
/// here -- checkout happens on the merchant web app (see `Env.merchantWebUrl`).
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
}

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return SubscriptionsRepository(ref.watch(apiClientProvider).dio);
});
