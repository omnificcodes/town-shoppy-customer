import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../notifications/application/push_notification_service.dart';
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
      unawaited(ref.read(pushNotificationServiceProvider.notifier).registerForCurrentAccount());
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

  /// The isSubmitting guard is the actual duplicate-submission prevention
  /// (not just a disabled button in the UI) — a second call while the first
  /// is still in flight is a no-op.
  bool get _isSubmitting => state is AuthUnauthenticated && (state as AuthUnauthenticated).isSubmitting;

  Future<void> login(String mobileNumber, String password) async {
    if (_isSubmitting) return;

    state = const AuthUnauthenticated(isSubmitting: true);
    try {
      final result = await _repository.login(mobileNumber: mobileNumber, password: password);
      await _storage.write(AppConstants.secureStorageAuthTokenKey, result.token);
      ref.read(sessionEpochProvider.notifier).bump();
      state = AuthAuthenticated(result.account);
      // Never awaited: a slow or declined permission prompt must not hold
      // up sign-in.
      unawaited(ref.read(pushNotificationServiceProvider.notifier).registerForCurrentAccount());
    } on AppException catch (e) {
      state = AuthUnauthenticated(error: e);
    }
  }

  Future<void> register(String mobileNumber, String name, String password, {String? referralCode}) async {
    if (_isSubmitting) return;

    state = const AuthUnauthenticated(isSubmitting: true);
    try {
      final result = await _repository.register(mobileNumber: mobileNumber, name: name, password: password, referralCode: referralCode);
      await _storage.write(AppConstants.secureStorageAuthTokenKey, result.token);
      ref.read(sessionEpochProvider.notifier).bump();
      state = AuthAuthenticated(result.account);
      unawaited(ref.read(pushNotificationServiceProvider.notifier).registerForCurrentAccount());
    } on AppException catch (e) {
      state = AuthUnauthenticated(error: e);
    }
  }

  /// Re-fetches `/auth/me` and swaps it into state in place -- used after a
  /// successful profile edit so the greeting/profile screen reflect the new
  /// name immediately, without the heavier session-epoch bump (which would
  /// also force-refetch every unrelated customer-scoped provider).
  Future<void> refreshAccount() async {
    if (state is! AuthAuthenticated) return;

    try {
      final account = await _repository.me();
      state = AuthAuthenticated(account);
    } on AppException {
      // Best-effort -- the edit itself already succeeded and its own
      // caller already has the fresh data; a failed refresh here just
      // means the greeting/profile screen keep showing the pre-edit
      // values until the next natural session refresh.
    }
  }

  /// Clears any error/submitting flag left over from a previous attempt —
  /// called when a Login/Register screen first mounts, so navigating
  /// between them never shows the other screen's stale error message.
  void clearError() {
    if (state is AuthUnauthenticated) {
      state = const AuthUnauthenticated();
    }
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
    // Best-effort, before the token that authorizes it is deleted below --
    // a signed-out device must stop receiving pushes meant for whoever
    // just left, not linger until the next account happens to log in and
    // overwrite the same token's registration.
    await ref.read(pushNotificationServiceProvider.notifier).deregisterCurrentDevice();
    await _storage.delete(AppConstants.secureStorageAuthTokenKey);
    // The Customer/Business choice belongs to the account that made it --
    // the next sign-in (possibly a different number) starts from scratch.
    await ref.read(appModeControllerProvider.notifier).clear();
    ref.read(sessionEpochProvider.notifier).bump();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
