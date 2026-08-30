import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/account.dart';
import 'models/otp_request_result.dart';

class VerifyOtpResult {
  const VerifyOtpResult({required this.account, required this.token, required this.isNewAccount});

  final Account account;
  final String token;
  final bool isNewAccount;
}

/// Talks to the real `/auth/*` endpoints only — `AuthController.php`
/// (requestOtp/verifyOtp/me/logout). There is no password-based flow used
/// here even though the backend also exposes `POST /auth/login`: the phase
/// brief is explicit that the customer app is OTP-only.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<OtpRequestResult> requestOtp({required String mobileNumber, String? channel}) async {
    try {
      final response = await _dio.post(
        '/auth/otp/request',
        data: {'mobile_number': mobileNumber, if (channel != null) 'channel': channel},
      );
      return OtpRequestResult.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<VerifyOtpResult> verifyOtp({
    required int otpRequestId,
    required String code,
    String? name,
    String? referralCode,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/otp/verify',
        data: {
          'otp_request_id': otpRequestId,
          'code': code,
          if (name != null && name.isNotEmpty) 'name': name,
          if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
        },
      );
      final data = ApiEnvelope.data(response) as Map<String, dynamic>;
      return VerifyOtpResult(
        account: Account.fromJson(data['account'] as Map<String, dynamic>),
        token: data['token'] as String,
        isNewAccount: data['is_new_account'] as bool? ?? false,
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<Account> me() async {
    try {
      final response = await _dio.get('/auth/me');
      return Account.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Best-effort — the caller always clears local session state regardless
  /// of whether this succeeds (a network failure during logout must never
  /// leave the app stuck showing a "signed in" screen).
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException {
      // Intentionally swallowed — see docblock above.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider).dio);
});
