import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/merchant.dart';
import 'models/merchant_branch_ref.dart';
import 'models/nearby_merchant.dart';

/// `GET /merchants` / `GET /merchants/{id}` — both carry no `auth:sanctum`
/// middleware (`MerchantController` resolves `$request->user('sanctum')`
/// explicitly for optional auth). A customer account is never "privileged"
/// there (`isPrivileged` requires Super Admin or Association Admin
/// specifically), so this client always receives the same
/// `MerchantPublicResource` shape a guest would.
///
/// `category_id`, `accepts_town_coin` and `search` are the real filters
/// this client uses on `index()` (`association_id` is also
/// backend-supported but has no client use case yet). `search` is a plain
/// `name LIKE` match — unprivileged callers (every request this app makes)
/// hit the same `->when($request->filled('search'), ...)` clause a Super
/// Admin does, so it's fully public. There is still no `town_id` filter on
/// this endpoint (confirmed by reading `MerchantController::index()`
/// directly), so this repository does not expose one.
class MerchantsRepository {
  MerchantsRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Merchant>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    bool? acceptsTownCoin,
    bool? featured,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/merchants',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (categoryId != null) 'category_id': categoryId,
          if (acceptsTownCoin == true) 'accepts_town_coin': 1,
          if (featured == true) 'featured': 1,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
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

  Future<Merchant> show(int id) async {
    try {
      final response = await _dio.get('/merchants/$id');
      return Merchant.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /merchants/{id}/branches` — the full, active-only branch list for
  /// one merchant (Phase 4), unlike `show()`'s embedded `branch`, which is
  /// only ever the single primary branch. Same optional-auth, fully public
  /// contract as `list()`/`show()` — every caller gets the same data.
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async {
    try {
      final response = await _dio.get('/merchants/$merchantId/branches');
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => MerchantBranchRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /merchants/nearby` (`MerchantController::nearby()`) — spatial
  /// search around a device coordinate, `active`-status merchants only.
  /// Unlike `list()`, the backend's response here carries no `meta` object
  /// at all (confirmed by reading the controller: it caches and returns the
  /// bare resource collection, never the paginator's pagination info) — so
  /// there is no `last_page`/`total` to report. [OffsetPage.lastPage] is
  /// therefore synthesized as "one page past the current one" whenever a
  /// full page of [perPage] came back, and equal to [page] (no more pages)
  /// whenever a short page comes back — the standard "infer the end from a
  /// short page" pattern, not a real page count.
  ///
  /// [radiusKm] maps to the endpoint's own `radius_km` (0.1 up to the
  /// server's configured maximum); omitted, the server uses its default.
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    double? radiusKm,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/merchants/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'page': page,
          'per_page': perPage,
          if (categoryId != null) 'category_id': categoryId,
          if (radiusKm != null) 'radius_km': radiusKm,
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => NearbyMerchant.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = items.length == perPage;
      return OffsetPage(items: items, currentPage: page, lastPage: hasMore ? page + 1 : page, total: items.length);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final merchantsRepositoryProvider = Provider<MerchantsRepository>((ref) {
  return MerchantsRepository(ref.watch(apiClientProvider).dio);
});
