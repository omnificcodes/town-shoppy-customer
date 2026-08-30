import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/redemption.dart';
import 'models/redemption_initiation_result.dart';

/// `GET /redemptions` / `GET /redemptions/{id}` — `RedemptionController`
/// scopes both to the caller's own `customer_profile_id` server-side for a
/// customer account (see the controller's own docblock); this client never
/// adds an equivalent filter itself.
class RedemptionsRepository {
  RedemptionsRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/redemptions', queryParameters: {'page': page, 'per_page': perPage});
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Redemption.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = ApiEnvelope.meta(response) ?? const {};
      return OffsetPage(
        items: items,
        currentPage: meta['current_page'] as int? ?? page,
        lastPage: meta['last_page'] as int? ?? page,
        total: meta['total'] as int? ?? items.length,
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<Redemption> show(int id) async {
    try {
      final response = await _dio.get('/redemptions/$id');
      return Redemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /redemptions` — always sends an explicit `branch_id`, chosen by
  /// the customer (or auto-selected when the merchant has exactly one),
  /// rather than relying on the backend's own primary-branch fallback.
  /// `Idempotency-Key` is required by `InitiateRedemptionRequest`; the
  /// caller is responsible for keeping it stable across a retry of the same
  /// (merchant, branch, amount) and generating a fresh one for a genuinely
  /// different request (see `RedemptionInitiationController`).
  Future<RedemptionInitiationResult> initiate({
    required int merchantId,
    required int branchId,
    required double billAmount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '/redemptions',
        data: {'merchant_id': merchantId, 'branch_id': branchId, 'bill_amount': billAmount},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return RedemptionInitiationResult.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final redemptionsRepositoryProvider = Provider<RedemptionsRepository>((ref) {
  return RedemptionsRepository(ref.watch(apiClientProvider).dio);
});
