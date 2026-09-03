import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/offset_page.dart';
import 'models/draw.dart';
import 'models/draw_winner.dart';
import 'models/voucher.dart';

/// `GET /draws*` -- deliberately callable while unauthenticated too (the
/// backend route sits outside auth:sanctum on purpose, ADR-003's
/// "unauthenticated public summary"). Draws are shipped and live; an
/// authenticated caller with no eligible draws yet simply sees a
/// 200-with-empty-list. `GET /vouchers*` IS own-account-only ("my winnings").
class LuckyDrawRepository {
  LuckyDrawRepository(this._dio);

  final Dio _dio;

  Future<OffsetPage<Draw>> draws({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/draws', queryParameters: {'page': page, 'per_page': perPage});
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => Draw.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<Draw> draw(int id) async {
    try {
      final response = await _dio.get('/draws/$id');
      return Draw.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<List<DrawWinner>> winners(int drawId) async {
    try {
      final response = await _dio.get('/draws/$drawId/winners');
      return (ApiEnvelope.data(response) as List<dynamic>).map((e) => DrawWinner.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<OffsetPage<Voucher>> myVouchers({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/vouchers', queryParameters: {'page': page, 'per_page': perPage});
      final items = (ApiEnvelope.data(response) as List<dynamic>).map((e) => Voucher.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<Voucher> voucher(int id) async {
    try {
      final response = await _dio.get('/vouchers/$id');
      return Voucher.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Returns the raw claim code/secret -- exactly once, only from this
  /// call. Never cached beyond the current screen's lifetime.
  Future<String> voucherQrSecret(int id) async {
    try {
      final response = await _dio.get('/vouchers/$id/qr');
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['qr_secret'] as String;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final luckyDrawRepositoryProvider = Provider<LuckyDrawRepository>((ref) {
  return LuckyDrawRepository(ref.watch(apiClientProvider).dio);
});
