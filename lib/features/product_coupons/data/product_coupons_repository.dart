import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/cursor_page.dart';
import 'models/product_coupon_request.dart';

/// Product coupons (a plan feature): the customer asks for a product's
/// Lucky Draw coupons, the shop's owner or staff accepts or declines.
///
/// * `POST /products/{id}/coupon-requests` -- the customer's ask;
///   `Idempotency-Key` required, so a retried tap never asks twice.
/// * `GET /product-coupon-requests?as=merchant` -- the shop's queue.
/// * `POST /product-coupon-requests/{id}/approve|reject` -- the decision.
class ProductCouponsRepository {
  ProductCouponsRepository(this._dio);

  final Dio _dio;

  Future<ProductCouponRequest> request(int productId, {required String idempotencyKey}) =>
      _one(() => _dio.post(
            '/products/$productId/coupon-requests',
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ));

  Future<CursorPage<ProductCouponRequest>> merchantRequests({String? status, String? cursor, int perPage = 20}) async {
    try {
      final response = await _dio.get(
        '/product-coupon-requests',
        queryParameters: {
          'as': 'merchant',
          'per_page': perPage,
          if (status != null) 'status': status,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => ProductCouponRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      return CursorPage(items: items, nextCursor: ApiEnvelope.meta(response)?['next_cursor'] as String?);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<ProductCouponRequest> approve(int id) => _one(() => _dio.post('/product-coupon-requests/$id/approve'));

  Future<ProductCouponRequest> reject(int id, {String? reason}) => _one(
        () => _dio.post(
          '/product-coupon-requests/$id/reject',
          data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
        ),
      );

  Future<ProductCouponRequest> _one(Future<Response> Function() call) async {
    try {
      final response = await call();
      return ProductCouponRequest.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final productCouponsRepositoryProvider = Provider<ProductCouponsRepository>((ref) {
  return ProductCouponsRepository(ref.watch(apiClientProvider).dio);
});
