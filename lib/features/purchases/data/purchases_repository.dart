import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/merchant_purchase_qr_resolution.dart';
import 'models/purchase.dart';

/// `GET /purchases` / `GET /purchases/{id}` — for a customer account,
/// `PurchaseController` scopes both to `customer_profile_id === own`
/// server-side (see the controller's own docblock); this client never adds
/// an equivalent filter itself, the backend already only returns what the
/// caller owns.
class PurchasesRepository {
  PurchasesRepository(this._dio);

  final Dio _dio;

  Future<List<Purchase>> recent({int limit = 3}) async {
    try {
      final response = await _dio.get('/purchases', queryParameters: {'per_page': limit});
      return (ApiEnvelope.data(response) as List<dynamic>).map((e) => Purchase.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/purchases', queryParameters: {'page': page, 'per_page': perPage});
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
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

  Future<Purchase> show(int id) async {
    try {
      final response = await _dio.get('/purchases/$id');
      return Purchase.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Method 1, step 1 — resolves a scanned merchant/branch Purchase QR for
  /// display, before the customer types a bill amount. A 404
  /// (`NotFoundException`) means the QR is invalid or revoked.
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async {
    try {
      final response = await _dio.post('/purchases/qr/resolve', data: {'token': token});
      return MerchantPurchaseQrResolution.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Method 1, step 2 — submits the bill amount against the SAME token
  /// that was scanned (never merchant_id/branch_id) so the backend
  /// re-resolves the target itself; the customer cannot end up requesting
  /// against a different merchant/branch than the one they scanned.
  /// `Idempotency-Key` required, same pattern as RedemptionsRepository.initiate().
  Future<Purchase> requestPurchase({
    required String token,
    required double billAmount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '/purchases/requests',
        data: {'token': token, 'bill_amount': billAmount},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return Purchase.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(apiClientProvider).dio);
});
