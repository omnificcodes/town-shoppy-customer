import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/cursor_page.dart';
import 'models/offer_redemption.dart';

/// `POST /offer-redemptions`, `GET /offer-redemptions`,
/// `GET /offer-redemptions/{id}` -- `OfferRedemptionController` scopes the
/// list to the caller's own `customer_profile_id` for a customer account
/// (see that controller's own docblock, same "server scopes, client never
/// adds an equivalent filter" contract as `RedemptionsRepository`).
class OfferRedemptionsRepository {
  OfferRedemptionsRepository(this._dio);

  final Dio _dio;

  Future<CursorPage<OfferRedemption>> list({String? cursor}) async {
    try {
      final response = await _dio.get(
        '/offer-redemptions',
        queryParameters: {if (cursor != null) 'cursor': cursor},
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => OfferRedemption.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = ApiEnvelope.meta(response);
      return CursorPage(items: items, nextCursor: meta?['next_cursor'] as String?);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<OfferRedemption> show(int id) async {
    try {
      final response = await _dio.get('/offer-redemptions/$id');
      return OfferRedemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `Idempotency-Key` is required by `RequestOfferRedemptionRequest`; the
  /// caller keeps it stable across a retry of the same (offer, branch,
  /// amount) and generates a fresh one for a genuinely different request
  /// -- same contract as `RedemptionsRepository.initiate()`.
  Future<OfferRedemption> request({
    required int offerId,
    int? branchId,
    required double billAmount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '/offer-redemptions',
        data: {'offer_id': offerId, if (branchId != null) 'branch_id': branchId, 'bill_amount': billAmount},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return OfferRedemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final offerRedemptionsRepositoryProvider = Provider<OfferRedemptionsRepository>((ref) {
  return OfferRedemptionsRepository(ref.watch(apiClientProvider).dio);
});
