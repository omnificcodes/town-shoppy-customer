import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/offer.dart';

/// `GET /offers/nearby` (`OfferController::nearby()`) — public, feature-flag
/// gated server-side (`offers`, seeded enabled). Same "bare resource
/// collection, no pagination meta" response shape as
/// `MerchantsRepository.nearby()` (confirmed by reading the controller:
/// `Cache::remember(...)` stores and returns the resolved resource array
/// directly, never the paginator's meta), so this returns a flat list, not
/// an [OffsetPage] -- there is no "load more" for a Home carousel anyway.
class OffersRepository {
  OffersRepository(this._dio);

  final Dio _dio;

  Future<List<Offer>> nearby({required double latitude, required double longitude, int perPage = 10}) async {
    try {
      final response = await _dio.get(
        '/offers/nearby',
        queryParameters: {'latitude': latitude, 'longitude': longitude, 'per_page': perPage},
      );
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Offer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /offers` (`OfferController::index()`) -- for a guest/customer
  /// caller this is server-scoped to currently-active, currently-running,
  /// publicly-visible offers at active merchants (see that controller's
  /// own guest/customer branch), page-paginated same as
  /// `MerchantsRepository.list()`. Unlike [nearby], this needs no device
  /// location, so it is the Offers tab's primary listing. [categoryId] and
  /// [expiringWithinDays] map onto the controller's own `category_id` and
  /// `expiring_within_days` filters, so pagination counts the filtered set.
  Future<OffsetPage<Offer>> list({int page = 1, int perPage = 20, int? categoryId, int? expiringWithinDays}) async {
    try {
      final response = await _dio.get(
        '/offers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'category_id': ?categoryId,
          'expiring_within_days': ?expiringWithinDays,
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Offer.fromJson(e as Map<String, dynamic>))
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

  /// `GET /offers/{id}` (`OfferController::show()`) -- returns
  /// `PublicOfferResource` for an unauthenticated/customer caller, same
  /// shape as [nearby]'s items. Used by the offer redemption flow, which
  /// needs a single offer's detail rather than a nearby list.
  Future<Offer> show(int id) async {
    try {
      final response = await _dio.get('/offers/$id');
      return Offer.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref.watch(apiClientProvider).dio);
});
