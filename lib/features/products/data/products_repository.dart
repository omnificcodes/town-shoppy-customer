import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/product.dart';

/// `GET /products` / `GET /products/{id}` (`ProductController`) -- public,
/// no `auth:sanctum` required (a guest, and the merchant receiving a
/// WhatsApp order who may not even have the app, can both open a product's
/// page). For a signed-in caller with no merchant access this returns the
/// same public, active-only view; see `BusinessProductsRepository` for the
/// authenticated merchant-management surface (create/update/delete and
/// this same list widened to include the merchant's own inactive rows).
class ProductsRepository {
  ProductsRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Product>> list({int? merchantId, int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get(
        '/products',
        queryParameters: {'page': page, 'per_page': perPage, if (merchantId != null) 'merchant_id': merchantId},
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<Product> show(int id) async {
    try {
      final response = await _dio.get('/products/$id');
      return Product.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(apiClientProvider).dio);
});
