import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/coupon.dart';

/// `GET /coupons` / `GET /coupons/{id}` -- for a customer account,
/// `CouponController` scopes both to `customer_profile_id === own`
/// server-side; this client never adds an equivalent filter itself, same
/// "backend already only returns what the caller owns" rule as
/// `PurchasesRepository`.
class CouponsRepository {
  CouponsRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Coupon>> list({int page = 1, int perPage = 20, String? status}) async {
    try {
      final response = await _dio.get(
        '/coupons',
        queryParameters: {'page': page, 'per_page': perPage, if (status != null) 'status': status},
      );
      final items =
          (ApiEnvelope.data(response) as List<dynamic>).map((e) => Coupon.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<Coupon> show(int id) async {
    try {
      final response = await _dio.get('/coupons/$id');
      return Coupon.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final couponsRepositoryProvider = Provider<CouponsRepository>((ref) {
  return CouponsRepository(ref.watch(apiClientProvider).dio);
});
