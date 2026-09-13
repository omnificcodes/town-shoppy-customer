import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/merchant_branch.dart';

/// The merchant's own branches (`/merchant-branches`, all package-gated)
/// and each branch's permanent Purchase QR token. The list is scoped to
/// the caller's merchant server-side; `merchant_id` only narrows.
class MerchantBranchesRepository {
  MerchantBranchesRepository(this._dio);

  final Dio _dio;

  /// One page of up to 50 -- the backend cap. A V1 merchant never has more
  /// branches than that, so callers treat this as "all".
  Future<List<MerchantBranch>> list({required int merchantId}) async {
    try {
      final response = await _dio.get('/merchant-branches', queryParameters: {'merchant_id': merchantId, 'per_page': 50});
      return (ApiEnvelope.data(response) as List<dynamic>).map((e) => MerchantBranch.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<MerchantBranch> create({required int merchantId, required BranchInput input}) async {
    try {
      final response = await _dio.post('/merchant-branches', data: {'merchant_id': merchantId, ...input.toJson()});
      return MerchantBranch.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// PATCH semantics -- [fields] is exactly what changes (`BranchInput
  /// .toJson()` for the form, `{'status': ...}` / `{'is_primary': true}`
  /// for the quick actions).
  Future<MerchantBranch> update(int branchId, Map<String, dynamic> fields) async {
    try {
      final response = await _dio.patch('/merchant-branches/$branchId', data: fields);
      return MerchantBranch.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `null` when the branch has no working QR (never generated, or revoked).
  Future<String?> purchaseQr(int branchId) async {
    try {
      final response = await _dio.get('/merchant-branches/$branchId/purchase-qr');
      return (ApiEnvelope.data(response) as Map<String, dynamic>?)?['token'] as String?;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Generates or regenerates -- the previous token stops working at once.
  Future<String> generatePurchaseQr(int branchId) async {
    try {
      final response = await _dio.post('/merchant-branches/$branchId/purchase-qr');
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['token'] as String;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<void> revokePurchaseQr(int branchId) async {
    try {
      await _dio.delete('/merchant-branches/$branchId/purchase-qr');
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final merchantBranchesRepositoryProvider = Provider<MerchantBranchesRepository>((ref) {
  return MerchantBranchesRepository(ref.watch(apiClientProvider).dio);
});
