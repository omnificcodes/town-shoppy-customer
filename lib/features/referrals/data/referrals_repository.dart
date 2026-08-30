import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/referral_summary.dart';

/// `GET /referrals/me` — the only referral route the backend exposes
/// (`ReferralController`'s own docblock). Applying a referral code is a
/// separate concern handled entirely inside the auth feature, since it only
/// happens through `POST /auth/otp/verify`'s `referral_code` field at
/// first-time registration — there is no standalone "apply a code" route.
class ReferralsRepository {
  ReferralsRepository(this._dio);

  final Dio _dio;

  Future<ReferralSummary> me() async {
    try {
      final response = await _dio.get('/referrals/me');
      return ReferralSummary.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final referralsRepositoryProvider = Provider<ReferralsRepository>((ref) {
  return ReferralsRepository(ref.watch(apiClientProvider).dio);
});
