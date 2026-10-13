import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/stamp_card.dart';

/// Digital stamp cards (a plan feature, BR-20c).
///
/// Customer side: `GET /customer-stamp-cards` (own cards, full first, then
/// collecting, then rewarded history).
///
/// Shop side: the programmes under `/stamp-cards`; at the counter
/// `GET /customer-stamp-cards/lookup` for a customer's progress and
/// `POST /customer-stamp-cards/{id}/reward` to hand over a full card's reward.
class StampCardsRepository {
  StampCardsRepository(this._dio);

  final Dio _dio;

  // ---- Customer ----

  Future<List<CustomerStampCard>> myCards() => _list(() => _dio.get('/customer-stamp-cards'));

  Future<CustomerStampCard> show(int id) => _card(() => _dio.get('/customer-stamp-cards/$id'));

  // ---- Shop ----

  Future<StampCardProgrammes> programmes(int merchantId) async {
    try {
      final response = await _dio.get('/stamp-cards', queryParameters: {'merchant_id': merchantId});
      final meta = ApiEnvelope.meta(response) ?? const {};
      return StampCardProgrammes(
        items: (ApiEnvelope.data(response) as List<dynamic>)
            .map((e) => StampCardProgramme.fromJson(e as Map<String, dynamic>))
            .toList(),
        enabled: meta['stamp_cards_enabled'] as bool? ?? false,
        limit: meta['stamp_card_limit'] as int?,
        activeCount: meta['active_count'] as int? ?? 0,
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<StampCardProgramme> createProgramme(int merchantId, StampCardInput input) =>
      _programme(() => _dio.post('/stamp-cards', data: {...input.toJson(), 'merchant_id': merchantId}));

  Future<StampCardProgramme> updateProgramme(int id, StampCardInput input) =>
      _programme(() => _dio.patch('/stamp-cards/$id', data: input.toJson()));

  /// A customer's live card on each of the shop's active programmes, by
  /// profile id (after a counter lookup) or by mobile number.
  Future<({List<CustomerStampCard> cards, String? customerName})> lookup({
    required int merchantId,
    int? customerProfileId,
    String? mobileNumber,
  }) async {
    try {
      final response = await _dio.get(
        '/customer-stamp-cards/lookup',
        queryParameters: {
          'merchant_id': merchantId,
          if (customerProfileId != null) 'customer_profile_id': customerProfileId,
          if (mobileNumber != null) 'mobile_number': mobileNumber.trim(),
        },
      );
      final cards = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => CustomerStampCard.fromJson(e as Map<String, dynamic>))
          .toList();
      final customer = ApiEnvelope.meta(response)?['customer'] as Map<String, dynamic>?;
      return (cards: cards, customerName: customer?['name'] as String?);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<CustomerStampCard> reward(int id) => _card(() => _dio.post('/customer-stamp-cards/$id/reward'));

  Future<List<CustomerStampCard>> _list(Future<Response> Function() call) async {
    try {
      final response = await call();
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => CustomerStampCard.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<CustomerStampCard> _card(Future<Response> Function() call) async {
    try {
      final response = await call();
      return CustomerStampCard.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<StampCardProgramme> _programme(Future<Response> Function() call) async {
    try {
      final response = await call();
      return StampCardProgramme.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final stampCardsRepositoryProvider = Provider<StampCardsRepository>((ref) {
  return StampCardsRepository(ref.watch(apiClientProvider).dio);
});
