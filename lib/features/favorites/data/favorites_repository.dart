import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import '../../merchants/data/models/merchant.dart';

/// The signed-in customer's saved shops (`MerchantFavoriteController`).
/// Favorite state is never part of a merchant payload — `GET /merchants/{id}`
/// is served from a cache shared by every caller — so the app loads
/// [ids] once and resolves each heart against that set.
class FavoritesRepository {
  FavoritesRepository(this._dio);

  final Dio _dio;

  /// `GET /favorites/merchants/ids` — every saved merchant id, unpaginated.
  Future<Set<int>> ids() async {
    try {
      final response = await _dio.get('/favorites/merchants/ids');
      final data = ApiEnvelope.data(response) as Map<String, dynamic>;
      return (data['merchant_ids'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toSet();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /favorites/merchants` — the saved shops themselves, newest first,
  /// in the same public merchant shape `GET /merchants` returns.
  Future<OffsetPage<Merchant>> list({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/favorites/merchants', queryParameters: {'page': page, 'per_page': perPage});
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
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

  /// `PUT /merchants/{id}/favorite` — idempotent; saving twice is a no-op.
  Future<void> add(int merchantId) async {
    try {
      await _dio.put('/merchants/$merchantId/favorite');
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `DELETE /merchants/{id}/favorite` — idempotent as well.
  Future<void> remove(int merchantId) async {
    try {
      await _dio.delete('/merchants/$merchantId/favorite');
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(apiClientProvider).dio);
});
