import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/scratch_card.dart';

/// Scratch cards (a plan feature, BR-20b).
///
/// Customer side: `GET /customer-scratch-cards` (own cards, unscratched
/// first), `POST /customer-scratch-cards/{id}/scratch` (reveals the reward;
/// a coin card's coins land in the wallet at that moment).
///
/// Shop side: the designs under `/scratch-cards`, and at the counter
/// `GET /customer-scratch-cards/lookup?code=` then
/// `POST /customer-scratch-cards/{id}/redeem` for an offer card's code.
class ScratchCardsRepository {
  ScratchCardsRepository(this._dio);

  final Dio _dio;

  // ---- Customer ----

  Future<List<CustomerScratchCard>> myCards() async {
    try {
      final response = await _dio.get('/customer-scratch-cards', queryParameters: {'per_page': 50});
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => CustomerScratchCard.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<CustomerScratchCard> show(int id) => _card(() => _dio.get('/customer-scratch-cards/$id'));

  Future<CustomerScratchCard> scratch(int id) => _card(() => _dio.post('/customer-scratch-cards/$id/scratch'));

  // ---- Shop ----

  Future<ScratchCardDesigns> designs(int merchantId) async {
    try {
      final response = await _dio.get('/scratch-cards', queryParameters: {'merchant_id': merchantId});
      final meta = ApiEnvelope.meta(response) ?? const {};
      return ScratchCardDesigns(
        items: (ApiEnvelope.data(response) as List<dynamic>)
            .map((e) => ScratchCardDesign.fromJson(e as Map<String, dynamic>))
            .toList(),
        enabled: meta['scratch_cards_enabled'] as bool? ?? false,
        remaining: meta['scratch_cards_remaining'] as int?,
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<ScratchCardDesign> createDesign(int merchantId, ScratchCardDesignInput input) =>
      _design(() => _dio.post('/scratch-cards', data: {...input.toJson(), 'merchant_id': merchantId}));

  Future<ScratchCardDesign> updateDesign(int id, ScratchCardDesignInput input) =>
      _design(() => _dio.patch('/scratch-cards/$id', data: input.toJson()));

  Future<ScratchCardDesign> setDesignStatus(int id, {required bool active}) =>
      _design(() => _dio.patch('/scratch-cards/$id', data: {'status': active ? 'active' : 'inactive'}));

  Future<CustomerScratchCard> lookup(String code) =>
      _card(() => _dio.get('/customer-scratch-cards/lookup', queryParameters: {'code': code.trim()}));

  Future<CustomerScratchCard> redeem(int id) => _card(() => _dio.post('/customer-scratch-cards/$id/redeem'));

  Future<CustomerScratchCard> _card(Future<Response> Function() call) async {
    try {
      final response = await call();
      return CustomerScratchCard.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<ScratchCardDesign> _design(Future<Response> Function() call) async {
    try {
      final response = await call();
      return ScratchCardDesign.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final scratchCardsRepositoryProvider = Provider<ScratchCardsRepository>((ref) {
  return ScratchCardsRepository(ref.watch(apiClientProvider).dio);
});
