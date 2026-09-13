import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../merchants/data/models/association_ref.dart';
import '../../merchants/data/models/town_ref.dart';

/// `GET /towns` and `GET /associations?town_id=` -- public, active-only,
/// server-cached reference lists the registration form's Town ->
/// Association pickers are built from. Both return flat arrays, no meta.
class ReferenceDataRepository {
  ReferenceDataRepository(this._dio);

  final Dio _dio;

  Future<List<TownRef>> towns() async {
    try {
      final response = await _dio.get('/towns');
      return (ApiEnvelope.data(response) as List<dynamic>).map((e) => TownRef.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<List<AssociationRef>> associations({required int townId}) async {
    try {
      final response = await _dio.get('/associations', queryParameters: {'town_id': townId});
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => AssociationRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final referenceDataRepositoryProvider = Provider<ReferenceDataRepository>((ref) {
  return ReferenceDataRepository(ref.watch(apiClientProvider).dio);
});

final townsProvider = FutureProvider<List<TownRef>>((ref) => ref.watch(referenceDataRepositoryProvider).towns());

final associationsByTownProvider = FutureProvider.family<List<AssociationRef>, int>(
  (ref, townId) => ref.watch(referenceDataRepositoryProvider).associations(townId: townId),
);
