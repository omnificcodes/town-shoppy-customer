import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/business_prize.dart';
import 'models/management_totals.dart';

/// Sponsored prizes (`/prizes*`). `merchant_id` is required on the list --
/// it is the authorization key for a merchant caller. Propose is Owner
/// only and package-gated; there is no edit endpoint, only withdraw.
class BusinessPrizesRepository {
  BusinessPrizesRepository(this._dio);

  final Dio _dio;

  Future<ManagementPage<BusinessPrize, PrizeTotals>> list({required int merchantId, int page = 1, int perPage = 20, String? status, String? search}) async {
    try {
      final response = await _dio.get(
        '/prizes',
        queryParameters: {
          'merchant_id': merchantId,
          'page': page,
          'per_page': perPage,
          if (status != null) 'status': status,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => BusinessPrize.fromJson(e as Map<String, dynamic>)).toList();
      final meta = ApiEnvelope.meta(response) ?? const {};
      return ManagementPage(
        items: items,
        currentPage: meta['current_page'] as int? ?? page,
        lastPage: meta['last_page'] as int? ?? page,
        total: meta['total'] as int? ?? items.length,
        totals: PrizeTotals.fromJson(meta['totals'] is Map ? Map<String, dynamic>.from(meta['totals'] as Map) : null),
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<BusinessPrize> show(int id) => _prize(() => _dio.get('/prizes/$id'));

  Future<BusinessPrize> propose({required int merchantId, required int associationId, required PrizeInput input}) =>
      _prize(() => _dio.post('/prizes', data: input.toJson(merchantId: merchantId, associationId: associationId)));

  Future<BusinessPrize> withdraw(int id, {String reason = 'Withdrawn by sponsor.'}) =>
      _prize(() => _dio.post('/prizes/$id/withdraw', data: {'reason': reason}));

  Future<BusinessPrize> _prize(Future<Response> Function() call) async {
    try {
      final response = await call();
      return BusinessPrize.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final businessPrizesRepositoryProvider = Provider<BusinessPrizesRepository>((ref) {
  return BusinessPrizesRepository(ref.watch(apiClientProvider).dio);
});
