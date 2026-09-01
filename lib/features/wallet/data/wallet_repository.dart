import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/cursor_page.dart';
import 'models/silver_wallet_balance.dart';
import 'models/wallet_ledger_entry.dart';

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

  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async {
    try {
      final response = await _dio.get(
        '/town-coins/transactions',
        queryParameters: {if (cursor != null) 'cursor': cursor},
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => WalletLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = ApiEnvelope.meta(response);
      return CursorPage(items: items, nextCursor: meta?['next_cursor'] as String?);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider).dio);
});
