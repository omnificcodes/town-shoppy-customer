import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';

/// Method 3 (3-way purchase architecture) — the customer's own identity
/// QR, which a merchant scans to resolve them server-side. `GET
/// /customer/qr` lazily provisions a token on first call; there is no
/// separate "generate" endpoint, only regenerate (see CustomerQrService's
/// own docblock for why revoke-without-replacement doesn't apply here).
class CustomerQrRepository {
  CustomerQrRepository(this._dio);

  final Dio _dio;

  Future<String> show() async {
    try {
      final response = await _dio.get('/customer/qr');
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['token'] as String;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<String> regenerate() async {
    try {
      final response = await _dio.post('/customer/qr/regenerate');
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['token'] as String;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final customerQrRepositoryProvider = Provider<CustomerQrRepository>((ref) {
  return CustomerQrRepository(ref.watch(apiClientProvider).dio);
});
