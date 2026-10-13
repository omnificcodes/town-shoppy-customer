import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/direct_pos.dart';

/// Direct POS -- the merchant records a bill at the counter and, in the
/// same call, spends the customer's Town Coins against it
/// (`DirectPosRedemptionService`). Three endpoints:
///
/// * `GET /purchases/customer-lookup` -- who a typed mobile number is.
/// * `POST /purchases/direct-pos/preview` -- read-only discount maths.
/// * `POST /purchases/direct-pos` -- the commit; `Idempotency-Key` required.
///   Same key + same (merchant, customer, amount) replays the original
///   purchase; same key + different context is a 409.
class DirectPosRepository {
  DirectPosRepository(this._dio);

  final Dio _dio;

  Future<CustomerLookupResult> lookupCustomer({required int merchantId, required String mobileNumber}) async {
    try {
      final response = await _dio.get(
        '/purchases/customer-lookup',
        queryParameters: {'merchant_id': merchantId, 'mobile_number': mobileNumber.trim()},
      );
      return CustomerLookupResult.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<DirectPosPreview> preview({
    required int merchantId,
    required DirectPosIdentity identity,
    required double billAmount,
    int? branchId,
  }) async {
    try {
      final response = await _dio.post(
        '/purchases/direct-pos/preview',
        data: {
          'merchant_id': merchantId,
          if (branchId != null) 'branch_id': branchId,
          'bill_amount': billAmount,
          ...identity.toJson(),
        },
      );
      return DirectPosPreview.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<DirectPosResult> submit({
    required int merchantId,
    required DirectPosIdentity identity,
    required double billAmount,
    required bool redeem,
    required String idempotencyKey,
    int? branchId,
    String? billReference,
    int? scratchCardId,
    int? stampCardId,
  }) async {
    try {
      final response = await _dio.post(
        '/purchases/direct-pos',
        data: {
          'merchant_id': merchantId,
          if (branchId != null) 'branch_id': branchId,
          // A scratch card design to give with the bill (a plan feature).
          if (scratchCardId != null) 'scratch_card_id': scratchCardId,
          // A loyalty stamp card to stamp with the bill (a plan feature).
          if (stampCardId != null) 'stamp_card_id': stampCardId,
          'bill_amount': billAmount,
          'redeem': redeem,
          if (billReference != null && billReference.trim().isNotEmpty) 'bill_reference': billReference.trim(),
          ...identity.toJson(),
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return DirectPosResult.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>, meta: ApiEnvelope.meta(response));
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final directPosRepositoryProvider = Provider<DirectPosRepository>((ref) {
  return DirectPosRepository(ref.watch(apiClientProvider).dio);
});
