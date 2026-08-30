import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/merchant_category.dart';

/// `GET /merchant-categories` — public, no `auth:sanctum` middleware at all
/// (`MerchantCategoryController::index()` never reads `$request->user()`).
/// Returns a flat, unpaginated array of active categories sorted by name
/// (server-side cached for 24h) — there is no pagination meta to parse here,
/// unlike the offset-paginated list endpoints elsewhere in the app.
class MerchantCategoriesRepository {
  MerchantCategoriesRepository(this._dio);

  final Dio _dio;

  Future<List<MerchantCategory>> list() async {
    try {
      final response = await _dio.get('/merchant-categories');
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => MerchantCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final merchantCategoriesRepositoryProvider = Provider<MerchantCategoriesRepository>((ref) {
  return MerchantCategoriesRepository(ref.watch(apiClientProvider).dio);
});
