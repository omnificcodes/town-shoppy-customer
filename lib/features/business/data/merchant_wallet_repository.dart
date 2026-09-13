import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/merchant_wallet.dart';

/// `GET /merchant-wallet` and `POST /merchant-wallet/blue-coin/redeem`
/// (both Owner or Staff, package-gated; merchant resolved server-side).
/// There is no merchant ledger endpoint on the backend yet.
class MerchantWalletRepository {
  MerchantWalletRepository(this._dio);

  final Dio _dio;

  Future<MerchantWallet> wallet() async {
    try {
      final response = await _dio.get('/merchant-wallet');
      return MerchantWallet.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Spends Blue Coin against a bill at [redeemingMerchantId]. Settles
  /// immediately; `Idempotency-Key` makes a retry return the same row.
  /// The backend maps its business rejections (own shop, target does not
  /// take Town Coin, no discount rate, zero balance) to a 500, so the
  /// caller pre-validates and treats a `ServerException` as "not
  /// possible", not as a crash.
  Future<MerchantBlueRedemption> redeemBlueCoin({required int redeemingMerchantId, required double billAmount, required String idempotencyKey}) async {
    try {
      final response = await _dio.post(
        '/merchant-wallet/blue-coin/redeem',
        data: {'redeeming_merchant_id': redeemingMerchantId, 'bill_amount': billAmount},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return MerchantBlueRedemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final merchantWalletRepositoryProvider = Provider<MerchantWalletRepository>((ref) {
  return MerchantWalletRepository(ref.watch(apiClientProvider).dio);
});
