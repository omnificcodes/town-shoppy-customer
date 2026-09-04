import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
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
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref.watch(apiClientProvider).dio);
});
