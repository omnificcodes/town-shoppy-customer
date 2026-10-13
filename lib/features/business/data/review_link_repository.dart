import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/review_link.dart';

/// Magic review links (BR-20d): `GET/PUT /review-link` for the shop's link
/// and results, `GET /review-link/responses` for the ratings and notes.
class ReviewLinkRepository {
  ReviewLinkRepository(this._dio);

  final Dio _dio;

  Future<ReviewLinkOverview> overview(int merchantId) =>
      _overview(() => _dio.get('/review-link', queryParameters: {'merchant_id': merchantId}));

  /// Creates the link on first save; later saves change the Google URL or
  /// switch it on/off. The QR code never changes.
  Future<ReviewLinkOverview> save(int merchantId, {required String googleReviewUrl, String? status}) => _overview(
    () => _dio.put(
      '/review-link',
      data: {'merchant_id': merchantId, 'google_review_url': googleReviewUrl.trim(), if (status != null) 'status': status},
    ),
  );

  /// Newest first. [privateOnly] keeps just the notes from 1-3 star ratings.
  Future<List<ReviewResponse>> responses(int merchantId, {bool privateOnly = false}) async {
    try {
      final response = await _dio.get(
        '/review-link/responses',
        queryParameters: {'merchant_id': merchantId, if (privateOnly) 'filter': 'private'},
      );
      return (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => ReviewResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<ReviewLinkOverview> _overview(Future<Response> Function() call) async {
    try {
      final response = await call();
      return ReviewLinkOverview.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final reviewLinkRepositoryProvider = Provider<ReviewLinkRepository>((ref) {
  return ReviewLinkRepository(ref.watch(apiClientProvider).dio);
});
