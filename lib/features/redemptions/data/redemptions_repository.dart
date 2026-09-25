import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/redemption.dart';

/// `GET /redemptions` / `GET /redemptions/{id}` — `RedemptionController`
/// scopes both to the caller's own `customer_profile_id` server-side for a
/// customer account (see the controller's own docblock); this client never
/// adds an equivalent filter itself.
///
/// Read-only now: the customer no longer starts a code-based redemption.
/// Paying with coins goes through the counter QR (`PurchasesRepository.
/// requestPurchase` with `redeem`), which the business approves.
class RedemptionsRepository {
  RedemptionsRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/redemptions', queryParameters: {'page': page, 'per_page': perPage});
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => Redemption.fromJson(e as Map<String, dynamic>))
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

  Future<Redemption> show(int id) async {
    try {
      final response = await _dio.get('/redemptions/$id');
      return Redemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final redemptionsRepositoryProvider = Provider<RedemptionsRepository>((ref) {
  return RedemptionsRepository(ref.watch(apiClientProvider).dio);
});
