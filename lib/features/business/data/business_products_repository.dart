import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import '../../products/data/models/product.dart';

/// The merchant's own catalog management -- `/products*`, Owner-only
/// mutations, package-gated. Same shape as `BusinessOffersRepository`:
/// `merchant_id` is always sent on the list call so `ProductController`
/// picks the management view (own merchant, including `inactive` rows)
/// rather than the public catalog.
class BusinessProductsRepository {
  BusinessProductsRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Product>> list({required int merchantId, int page = 1, int perPage = 20}) async {
    try {
      // `mine=1` asks for the management view: this merchant's catalog
      // including its inactive rows. Without it `/products` answers with
      // the public catalog, which is what the customer app's Shopping tab
      // wants and which would hide anything not yet active.
      final response = await _dio.get(
        '/products',
        queryParameters: {'mine': 1, 'merchant_id': merchantId, 'page': page, 'per_page': perPage},
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
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

  Future<Product> create({required int merchantId, required ProductInput input}) =>
      _product(() => _dio.post('/products', data: {'merchant_id': merchantId, ...input.toJson()}));

  Future<Product> update(int id, ProductInput input) =>
      _product(() => _dio.patch('/products/$id', data: input.toJson()));

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/products/$id');
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<Product> _product(Future<Response> Function() call) async {
    try {
      final response = await call();
      return Product.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final businessProductsRepositoryProvider = Provider<BusinessProductsRepository>((ref) {
  return BusinessProductsRepository(ref.watch(apiClientProvider).dio);
});
