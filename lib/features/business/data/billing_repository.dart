import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/billing.dart';
import 'models/management_totals.dart';

/// Read side of billing: the payments this merchant made to Town Shoppy
/// and the invoices issued for them. Owner only on the server
/// (`PaymentPolicy` / `InvoicePolicy` -- staff get a 403). Refunds and
/// cash assignment are Super Admin actions and deliberately absent.
///
/// `merchant_id` is sent on every list call for the same reason the web's
/// `usePayments()` documents: a dual-role account (a Super Admin who also
/// owns a shop) is otherwise served every merchant's rows.
class BillingRepository {
  BillingRepository(this._dio);

  final Dio _dio;

  /// `GET /payments` -- `status`, `date_from`/`date_to` (YYYY-MM-DD, both
  /// validated; `to` must be on/after `from`), `search` (substring of the
  /// gateway reference, or the exact payment id / amount when numeric).
  Future<ManagementPage<MerchantPayment, PaymentTotals>> payments({
    int page = 1,
    int perPage = 20,
    int? merchantId,
    String? status,
    String? from,
    String? to,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/payments',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (merchantId != null) 'merchant_id': merchantId,
          if (status != null) 'status': status,
          if (from != null) 'date_from': from,
          if (to != null) 'date_to': to,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => MerchantPayment.fromJson(e as Map<String, dynamic>)).toList();
      final meta = ApiEnvelope.meta(response) ?? const {};
      return ManagementPage(
        items: items,
        currentPage: meta['current_page'] as int? ?? page,
        lastPage: meta['last_page'] as int? ?? page,
        total: meta['total'] as int? ?? items.length,
        totals: PaymentTotals.fromJson(meta['totals'] is Map ? Map<String, dynamic>.from(meta['totals'] as Map) : null),
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /payments/{id}` -- merchant and invoice relations loaded.
  Future<MerchantPayment> payment(int id) async {
    try {
      final response = await _dio.get('/payments/$id');
      return MerchantPayment.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /invoices` -- `date_from`/`date_to` against `issued_at`. No
  /// status (an invoice has none) and no search on the server.
  Future<OffsetPage<MerchantInvoice>> invoices({int page = 1, int perPage = 20, int? merchantId, String? from, String? to}) async {
    try {
      final response = await _dio.get(
        '/invoices',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (merchantId != null) 'merchant_id': merchantId,
          if (from != null) 'date_from': from,
          if (to != null) 'date_to': to,
        },
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => MerchantInvoice.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<MerchantInvoice> invoice(int id) async {
    try {
      final response = await _dio.get('/invoices/$id');
      return MerchantInvoice.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(apiClientProvider).dio);
});
