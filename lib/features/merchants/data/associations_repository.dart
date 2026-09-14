import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/association_ref.dart';

/// `GET /associations` -- public, with no auth middleware. For a customer
/// (or a guest) `AssociationController::index()` returns every active
/// association with its town, the same list anyone would see.
class AssociationsRepository {
  AssociationsRepository(this._dio);

  final Dio _dio;

  Future<List<AssociationRef>> listActive() async {
    try {
      final response = await _dio.get('/associations');
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => AssociationRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final associationsRepositoryProvider = Provider<AssociationsRepository>((ref) {
  return AssociationsRepository(ref.watch(apiClientProvider).dio);
});
