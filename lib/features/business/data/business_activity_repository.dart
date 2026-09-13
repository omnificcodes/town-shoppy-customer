import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import '../../purchases/data/models/purchase.dart';
import '../../redemptions/data/models/redemption.dart';
import 'models/management_totals.dart';
import 'models/purchase_stats.dart';

/// The merchant-side reads and counter actions behind the Business
/// dashboard, Purchases and Redemptions screens. Every list call passes
/// `context=management` *and* `merchant_id`: this account very likely also
/// has a customer profile, and without the flag the backend returns the
/// caller's *personal* history instead of the shop's (the exact bug the
/// merchant web app documents in `usePurchases()`).
class BusinessActivityRepository {
  BusinessActivityRepository(this._dio);

  final Dio _dio;

  Future<PurchaseStats> stats({String range = '30d'}) async {
    try {
      final response = await _dio.get('/purchases/stats', queryParameters: {'range': range});
      return PurchaseStats.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<OffsetPage<Purchase>> purchases({int page = 1, int perPage = 20, String? status}) async {
    final full = await purchasesPage(page: page, perPage: perPage, status: status);
    return OffsetPage(items: full.items, currentPage: full.currentPage, lastPage: full.lastPage, total: full.total);
  }

  /// `GET /purchases` -- `status`, `branch_id`, `from`/`to` (YYYY-MM-DD),
  /// `search` (bill reference, or exact amount when numeric). Order is
  /// fixed newest-first; nothing is validated server-side, so a bad value
  /// yields an empty list rather than a 422.
  Future<ManagementPage<Purchase, PurchaseTotals>> purchasesPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? merchantId,
    int? branchId,
    String? from,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/purchases',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'context': 'management',
          if (merchantId != null) 'merchant_id': merchantId,
          if (status != null) 'status': status,
          if (branchId != null) 'branch_id': branchId,
          if (from != null) 'from': from,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      return _page(response, page, Purchase.fromJson, PurchaseTotals.fromJson);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<OffsetPage<Redemption>> redemptions({int page = 1, int perPage = 20, String? status}) async {
    final full = await redemptionsPage(page: page, perPage: perPage, status: status);
    return OffsetPage(items: full.items, currentPage: full.currentPage, lastPage: full.lastPage, total: full.total);
  }

  /// `GET /redemptions` -- unlike purchases these filters ARE validated
  /// (422 on a bad status). `search` matches customer name, mobile number
  /// or exact redemption id.
  Future<ManagementPage<Redemption, RedemptionTotals>> redemptionsPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? merchantId,
    int? branchId,
    String? from,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/redemptions',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'context': 'management',
          if (merchantId != null) 'merchant_id': merchantId,
          if (status != null) 'status': status,
          if (branchId != null) 'branch_id': branchId,
          if (from != null) 'from': from,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      return _page(response, page, Redemption.fromJson, RedemptionTotals.fromJson);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /purchases/{id}` -- the same resource owner/staff see as the
  /// customer does; merchant/branch relations and `coupons_issued` are
  /// loaded on this endpoint.
  Future<Purchase> purchase(int id) async {
    try {
      final response = await _dio.get('/purchases/$id');
      return Purchase.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `GET /redemptions/{id}` -- no customer relation on this endpoint.
  Future<Redemption> redemption(int id) async {
    try {
      final response = await _dio.get('/redemptions/$id');
      return Redemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  // ---- Purchase actions (owner or staff; `pending` only; 409 otherwise) ----

  Future<Purchase> approvePurchase(int id) async {
    try {
      final response = await _dio.post('/purchases/$id/approve');
      return Purchase.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<Purchase> rejectPurchase(int id, {String? reason}) async {
    try {
      final response = await _dio.post('/purchases/$id/reject', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()});
      return Purchase.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  // ---- Redemption actions ----

  /// `verification_method` is `otp` (typed PIN), `qr` (the customer's
  /// redemption QR, scanned or typed) or `counter_confirm` (no code; only
  /// accepted when the redemption was raised at this branch's counter).
  Future<Redemption> verifyRedemption(int id, {required String method, String? code}) async {
    try {
      final response = await _dio.post(
        '/redemptions/$id/verify',
        data: {'verification_method': method, if (method != 'counter_confirm') 'code': code?.trim()},
      );
      return Redemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<Redemption> cancelRedemption(int id, {String? reason}) async {
    try {
      final response = await _dio.post('/redemptions/$id/cancel', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()});
      return Redemption.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  ManagementPage<T, Totals> _page<T, Totals>(
    Response response,
    int page,
    T Function(Map<String, dynamic>) parse,
    Totals Function(Map<String, dynamic>?) parseTotals,
  ) {
    final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList();
    final meta = ApiEnvelope.meta(response) ?? const {};
    return ManagementPage(
      items: items,
      currentPage: meta['current_page'] as int? ?? page,
      lastPage: meta['last_page'] as int? ?? page,
      total: meta['total'] as int? ?? items.length,
      totals: parseTotals(meta['totals'] is Map ? Map<String, dynamic>.from(meta['totals'] as Map) : null),
    );
  }
}

final businessActivityRepositoryProvider = Provider<BusinessActivityRepository>((ref) {
  return BusinessActivityRepository(ref.watch(apiClientProvider).dio);
});
