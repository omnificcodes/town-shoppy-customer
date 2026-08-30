import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/silver_wallet_balance.dart';

/// `GET /town-coins`, `GET /town-coins/transactions` — always a live read,
/// never cached server-side either (`WalletController`'s own docblock:
/// "Never cached — always a live DB read").
class WalletRepository {
  WalletRepository(this._dio);

  final Dio _dio;

  Future<SilverWalletBalance> balance() async {
    try {
      final response = await _dio.get('/town-coins');
      return SilverWalletBalance.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider).dio);
});
