import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/cursor_page.dart';
import '../../offer_redemptions/data/models/offer_redemption.dart';
import 'models/business_offer.dart';

/// A page of the merchant's own offers plus the per-status counts the
/// same response carries.
class OffersPage {
  const OffersPage({required this.items, required this.currentPage, required this.lastPage, required this.total, required this.counts});

  final List<BusinessOffer> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final OfferStatusCounts counts;

  bool get hasMore => currentPage < lastPage;
}

/// Offers (`/offers*`, Owner-only mutations, package-gated) and the offer
/// redemption queue (`/offer-redemptions?as=merchant`, Owner or Staff).
/// `merchant_id` is always sent on the offers list: the backend picks the
/// management view by role, and a dual-role account would otherwise get
/// every merchant's offers.
class BusinessOffersRepository {
  BusinessOffersRepository(this._dio);

  final Dio _dio;

  Future<OffersPage> list({required int merchantId, int page = 1, int perPage = 20, String? status, String? search}) async {
    try {
      final response = await _dio.get(
        '/offers',
        queryParameters: {
          'merchant_id': merchantId,
          'page': page,
          'per_page': perPage,
          if (status != null) 'status': status,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => BusinessOffer.fromJson(e as Map<String, dynamic>)).toList();
      final meta = ApiEnvelope.meta(response) ?? const {};
      return OffersPage(
        items: items,
        currentPage: meta['current_page'] as int? ?? page,
        lastPage: meta['last_page'] as int? ?? page,
        total: meta['total'] as int? ?? items.length,
        counts: OfferStatusCounts.fromJson(meta['status_counts'] is Map ? Map<String, dynamic>.from(meta['status_counts'] as Map) : null),
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<BusinessOffer> show(int id) => _offer(() => _dio.get('/offers/$id'));

  Future<BusinessOffer> create({required int merchantId, required OfferInput input}) =>
      _offer(() => _dio.post('/offers', data: {'merchant_id': merchantId, ...input.toJson()}));

  /// Only a `draft` can be edited (409 otherwise).
  Future<BusinessOffer> update(int id, OfferInput input) => _offer(() => _dio.patch('/offers/$id', data: input.toJson()));

  Future<BusinessOffer> publish(int id) => _offer(() => _dio.post('/offers/$id/publish'));

  Future<BusinessOffer> withdraw(int id, {String? reason}) =>
      _offer(() => _dio.post('/offers/$id/withdraw', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()}));

  Future<BusinessOffer> end(int id, {String? reason}) =>
      _offer(() => _dio.post('/offers/$id/end', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()}));

  Future<BusinessOffer> _offer(Future<Response> Function() call) async {
    try {
      final response = await call();
      return BusinessOffer.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  // ---- Offer redemptions (cursor-paginated; no totals on this endpoint) ----

  Future<CursorPage<OfferRedemption>> offerRedemptions({String? status, String? cursor, int perPage = 20}) async {
    try {
      final response = await _dio.get(
        '/offer-redemptions',
        queryParameters: {'as': 'merchant', 'per_page': perPage, if (status != null) 'status': status, if (cursor != null) 'cursor': cursor},
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => OfferRedemption.fromJson(e as Map<String, dynamic>)).toList();
      return CursorPage(items: items, nextCursor: ApiEnvelope.meta(response)?['next_cursor'] as String?);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<OfferRedemption> approveOfferRedemption(int id) => _offerRedemption(() => _dio.post('/offer-redemptions/$id/approve'));

  Future<OfferRedemption> rejectOfferRedemption(int id, {String? reason}) => _offerRedemption(
        () => _dio.post('/offer-redemptions/$id/reject', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()}),
      );

  Future<OfferRedemption> _offerRedemption(Future<Response> Function() call) async {
    try {
      final response = await call();
      return OfferRedemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final businessOffersRepositoryProvider = Provider<BusinessOffersRepository>((ref) {
  return BusinessOffersRepository(ref.watch(apiClientProvider).dio);
});
