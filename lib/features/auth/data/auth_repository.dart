import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/account.dart';

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
