import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

/// Bumped on every login and logout/session-expiry. Every customer-scoped
/// provider (wallet, notifications, home summary, profile, ...) must start
/// its `build()`/constructor with `ref.watch(sessionEpochProvider)` as its
/// first line — the value itself is unused, but watching it makes Riverpod
/// treat the provider as a dependent and recompute it from scratch on every
/// epoch change. This is the Riverpod equivalent of the admin web app's
/// `queryClient.clear()` fix (section 39: "do not repeat the admin
/// cache-leak bug").
class SessionEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final sessionEpochProvider = NotifierProvider<SessionEpoch, int>(SessionEpoch.new);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;
  late final SecureStorageService _storage;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    _storage = ref.watch(secureStorageServiceProvider);

    // Wire the API client's 401 hook here — the one place that legitimately
    // knows about both networking and auth state without a circular
    // provider dependency (see ApiClient's own docblock).
    ref.watch(apiClientProvider).onUnauthorized = _handleSessionExpired;

    _restoreSession();
    return const AuthInitial();
  }

  Future<void> _restoreSession() async {
    final token = await _storage.read(AppConstants.secureStorageAuthTokenKey);
    if (token == null || token.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final account = await _repository.me();
      state = AuthAuthenticated(account);
    } on UnauthenticatedException {
      await _storage.delete(AppConstants.secureStorageAuthTokenKey);
      state = const AuthUnauthenticated();
    } on AppException {
      // Network/server failure while validating a stored token is not the
      // same as an invalid token — keep it and let the user retry rather
      // than forcing a fresh login over a flaky connection (section 37).
      state = const AuthUnauthenticated(error: NetworkException("We couldn't reach Town Shoppy. Check your connection and try again."));
    }
  }

  Future<void> requestOtp(String mobileNumber) async {
    state = const AuthUnauthenticated(isRequestingOtp: true);
    try {
      final result = await _repository.requestOtp(mobileNumber: mobileNumber);
      state = AuthOtpSent(
        otpRequestId: result.otpRequestId,
        mobileNumber: mobileNumber,
        expiresAt: DateTime.now().add(Duration(seconds: result.expiresInSeconds)),
        channelUsed: result.channelUsed,
        debugCode: result.debugCode,
      );
    } on AppException catch (e) {
      state = AuthUnauthenticated(error: e);
    }
  }

  Future<void> resendOtp() async {
    final current = state;
    if (current is! AuthOtpSent) return;

    state = current.copyWith(isResending: true, clearError: true);
    try {
      final result = await _repository.requestOtp(mobileNumber: current.mobileNumber);
      state = current.copyWith(
        otpRequestId: result.otpRequestId,
        expiresAt: DateTime.now().add(Duration(seconds: result.expiresInSeconds)),
        channelUsed: result.channelUsed,
        debugCode: result.debugCode,
        clearDebugCode: result.debugCode == null,
        isResending: false,
      );
    } on AppException catch (e) {
      state = current.copyWith(isResending: false, error: e);
    }
  }

  Future<void> verifyOtp(String code) async {
    final current = state;
    if (current is! AuthOtpSent) return;

    state = current.copyWith(isVerifying: true, clearError: true);
    try {
      final result = await _repository.verifyOtp(otpRequestId: current.otpRequestId, code: code);
      await _storage.write(AppConstants.secureStorageAuthTokenKey, result.token);
      ref.read(sessionEpochProvider.notifier).bump();
      state = AuthAuthenticated(result.account);
    } on ValidationAppException catch (e) {
      if (e.fieldErrors.containsKey('name')) {
        // A genuinely new account — the backend needs a name (and will
        // optionally accept a referral code) before it can finish creating
        // the CustomerProfile. Not an error to show; a real next step.
        state = AuthProfileRequired(otpRequestId: current.otpRequestId, code: code, mobileNumber: current.mobileNumber);
      } else {
        state = current.copyWith(isVerifying: false, error: e);
      }
    } on AppException catch (e) {
      state = current.copyWith(isVerifying: false, error: e);
    }
  }

  /// Resubmits the same (still-idempotent) OTP verification, this time with
  /// the name required to complete a genuinely new account's registration,
  /// and an optional referral code — the only moment the backend ever
  /// accepts one (see [AuthProfileRequired]'s docblock).
  Future<void> completeRegistration({required String name, String? referralCode}) async {
    final current = state;
    // The isSubmitting guard is the actual duplicate-submission prevention
    // (not just a disabled button in the UI) — a second call while the
    // first is still in flight is a no-op.
    if (current is! AuthProfileRequired || current.isSubmitting) return;

    state = current.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await _repository.verifyOtp(
        otpRequestId: current.otpRequestId,
        code: current.code,
        name: name,
        referralCode: referralCode,
      );
      await _storage.write(AppConstants.secureStorageAuthTokenKey, result.token);
      ref.read(sessionEpochProvider.notifier).bump();
      state = AuthAuthenticated(result.account);
    } on AppException catch (e) {
      state = current.copyWith(isSubmitting: false, error: e);
    }
  }

  /// Lets the mobile-number screen re-render without losing the "otp sent"
  /// context entirely broken — used by the "use a different number" action.
  void backToMobileEntry() {
    state = const AuthUnauthenticated();
  }

  Future<void> logout() async {
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(current.account, isLoggingOut: true);
    }

    await _repository.logout();
    await _clearSessionAndCustomerState();
    state = const AuthUnauthenticated();
  }

  void _handleSessionExpired() {
    if (state is AuthUnauthenticated || state is AuthSessionExpired || state is AuthInitial) return;

    unawaited(_clearSessionAndCustomerState().then((_) => state = const AuthSessionExpired()));
  }

  Future<void> _clearSessionAndCustomerState() async {
    await _storage.delete(AppConstants.secureStorageAuthTokenKey);
    ref.read(sessionEpochProvider.notifier).bump();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
