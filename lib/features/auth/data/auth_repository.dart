import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/account.dart';
import 'models/otp_request_result.dart';

class AuthResult {
  const AuthResult({required this.account, required this.token});

  final Account account;
  final String token;
}

/// Talks to the real `/auth/*` endpoints — password login/register, `me`,
/// and `logout`. Mobile-number ownership is not proven at signup (no OTP);
/// the same trade-off the admin web app already makes for merchant/admin
/// registration via `POST /auth/register`.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthResult> login({required String mobileNumber, required String password}) async {
    try {
      final response = await _dio.post('/auth/login', data: {'mobile_number': mobileNumber, 'password': password});
      return _parseAuthResult(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /auth/impersonation/exchange` — trades a Super Admin's
  /// single-use, 60-second hand-off code for a one-hour session. Same
  /// `{account, token}` shape as [login].
  Future<AuthResult> exchangeImpersonationCode(String code) async {
    try {
      final response = await _dio.post('/auth/impersonation/exchange', data: {'code': code});
      return _parseAuthResult(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<AuthResult> register({
    required String mobileNumber,
    required String name,
    required String password,
    String? referralCode,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'mobile_number': mobileNumber,
          'name': name,
          'password': password,
          'password_confirmation': password,
          if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
        },
      );
      return _parseAuthResult(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  AuthResult _parseAuthResult(Map<String, dynamic> data) {
    return AuthResult(account: Account.fromJson(data['account'] as Map<String, dynamic>), token: data['token'] as String);
  }

  Future<Account> me() async {
    try {
      final response = await _dio.get('/auth/me');
      return Account.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Step 1 of the forgot-password flow -- `POST /auth/password/forgot`.
  /// Returns the same shape whether or not an account exists for this
  /// number (enumeration protection, `AuthController::forgotPassword`'s own
  /// docblock) -- there is deliberately no way to tell from this response
  /// alone whether an OTP was actually sent to a real account.
  Future<OtpRequestResult> forgotPassword({required String mobileNumber, String? channel}) async {
    try {
      final response = await _dio.post(
        '/auth/password/forgot',
        data: {'mobile_number': mobileNumber, if (channel != null) 'channel': channel},
      );
      return OtpRequestResult.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// Step 2 -- `POST /auth/password/reset`. Verifies the OTP and sets the
  /// new password; does not log the caller in (no token in the response),
  /// so a stolen reset link can't silently also hand out a session.
  Future<void> resetPassword({
    required String mobileNumber,
    required int otpRequestId,
    required String code,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/auth/password/reset',
        data: {
          'mobile_number': mobileNumber,
          'otp_request_id': otpRequestId,
          'code': code,
          'password': password,
          'password_confirmation': password,
        },
      );
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /auth/password/set` -- for an account that signed up via OTP and
  /// has no password yet (`Account.hasPassword == false`). Business mode's
  /// Security screen, mirroring the merchant web app.
  Future<void> setPassword({required String password}) async {
    try {
      await _dio.post('/auth/password/set', data: {'password': password, 'password_confirmation': password});
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /auth/password/change` -- the backend re-checks
  /// `current_password`, so a wrong one comes back as a 422 field error.
  Future<void> changePassword({required String currentPassword, required String password}) async {
    try {
      await _dio.post(
        '/auth/password/change',
        data: {'current_password': currentPassword, 'password': password, 'password_confirmation': password},
      );
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
