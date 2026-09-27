import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/counter_redemption.dart';
import 'models/merchant_purchase_qr_resolution.dart';
import 'models/purchase.dart';
import 'models/purchase_request_target.dart';

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

  /// Method 1, step 2 — submits the bill amount against [target]: the SAME
  /// token that was scanned (so the backend re-resolves the merchant/
  /// branch itself, and the customer cannot end up requesting against a
  /// different one than they scanned), or the merchant chosen from its own
  /// profile, which the backend treats as unproven presence and settles on
  /// the merchant's approval instead.
  /// `Idempotency-Key` required, same pattern as RedemptionsRepository.initiate().
  /// With [redeem] true the server also spends this customer's Town Coins
  /// against the same bill, in the same call, and returns the resulting
  /// redemption in `meta`. How much is never sent from here -- the server
  /// derives it from the merchant's own rate and the wallet.
  Future<CounterPurchaseResult> requestPurchase({
    required PurchaseRequestTarget target,
    required double billAmount,
    required String idempotencyKey,
    bool redeem = false,
  }) async {
    try {
      final response = await _dio.post(
        '/purchases/requests',
        data: {...target.toRequestJson(), 'bill_amount': billAmount, if (redeem) 'redeem': true},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );

      final redemption = ApiEnvelope.meta(response)?['redemption'];

      return CounterPurchaseResult(
        purchase: Purchase.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>),
        redemption: redemption is Map
            ? CounterRedemption.fromJson(Map<String, dynamic>.from(redemption))
            : null,
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(apiClientProvider).dio);
});

/// What one counter purchase produced: always a [purchase], plus the
/// [redemption] when the customer chose to spend coins on the same bill.
class CounterPurchaseResult {
  const CounterPurchaseResult({required this.purchase, this.redemption});

  final Purchase purchase;
  final CounterRedemption? redemption;
}
