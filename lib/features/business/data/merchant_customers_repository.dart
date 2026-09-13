import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/management_totals.dart';
import 'models/merchant_customer.dart';

/// The merchant's customer directory (`/customers*`, Owner or Staff,
/// package-gated). The merchant is resolved server-side from the caller;
/// `branch_id` / `from` / `to` narrow the *purchase window* the figures are
/// computed over, not just which rows appear.
class MerchantCustomersRepository {
  MerchantCustomersRepository(this._dio);

  final Dio _dio;

  Future<ManagementPage<MerchantCustomer, CustomerTotals>> list({int page = 1, int perPage = 20, String? search, int? branchId, String? from}) async {
    try {
      final response = await _dio.get(
        '/customers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (branchId != null) 'branch_id': branchId,
          if (from != null) 'from': from,
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => MerchantCustomer.fromJson(e as Map<String, dynamic>)).toList();
      final meta = ApiEnvelope.meta(response) ?? const {};
      return ManagementPage(
        items: items,
        currentPage: meta['current_page'] as int? ?? page,
        lastPage: meta['last_page'] as int? ?? page,
        total: meta['total'] as int? ?? items.length,
        totals: CustomerTotals.fromJson(meta['totals'] is Map ? Map<String, dynamic>.from(meta['totals'] as Map) : null),
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// 404 when this person has no purchase or redemption history here.
  Future<MerchantCustomerDetail> show(int customerId) async {
    try {
      final response = await _dio.get('/customers/$customerId');
      return MerchantCustomerDetail.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final merchantCustomersRepositoryProvider = Provider<MerchantCustomersRepository>((ref) {
  return MerchantCustomersRepository(ref.watch(apiClientProvider).dio);
});
