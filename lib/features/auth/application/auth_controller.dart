import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../notifications/application/push_notification_service.dart';
import '../data/auth_repository.dart';
import '../data/models/account.dart';
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

  /// The in-flight cold-start restore, so [signInWithHandoffCode] can wait
  /// for it instead of racing it for the last write to [state].
  Future<void>? _restore;

  /// When the account in [state] was last read from the backend, and the
  /// re-read currently in flight, if any -- see [syncAccount].
  DateTime? _lastSyncedAt;
  Future<void>? _sync;

  /// How stale the account may be before an app-resume re-reads it. A
  /// mode switch never waits on this (see [build]).
  static const syncInterval = Duration(seconds: 30);

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    _storage = ref.watch(secureStorageServiceProvider);

    // Wire the API client's 401 hook here — the one place that legitimately
    // knows about both networking and auth state without a circular
    // provider dependency (see ApiClient's own docblock).
    ref.watch(apiClientProvider).onUnauthorized = _handleSessionExpired;

    // Switching Business <-> Customer is exactly when "does this account
    // run a business?" decides what is on screen, so it is re-asked of the
    // backend every time, from here rather than at each of the half-dozen
    // switch buttons -- a new one cannot forget. `clear()` on sign-out sets
    // the mode to null, which is not a switch and syncs nothing.
    ref.listen(appModeControllerProvider.select((s) => s.mode), (previous, next) {
      if (next != null && previous != next) unawaited(syncAccount(force: true));
    });

    _restore = _restoreSession();
    return const AuthInitial();
  }

  /// Re-reads `/auth/me` so the account in memory matches the backend.
  ///
  /// The account used to be read once per session -- at sign-in, or cold
  /// start -- plus a refresh after this app's OWN merchant registration.
  /// A business that came into being any other way (the merchant web
  /// portal's own sign-up, another tab or device, or that one refresh
  /// losing a flaky connection) stayed invisible until the next sign-in:
  /// the Customer menu kept offering "Register your business" to an owner.
  /// This is called on every mode switch and whenever the app returns to
  /// the foreground (see `AccountSyncOnResume`).
  ///
  /// Concurrent calls share one request. Unless [force]d, a call within
  /// [syncInterval] of the last successful read is skipped, so switching
  /// back to a tab repeatedly does not hammer the API. Failures are
  /// silent: the account already in memory stays, and the next trigger
  /// tries again.
  Future<void> syncAccount({bool force = false}) {
    final current = state;
    if (current is! AuthAuthenticated || current.isLoggingOut) return Future.value();

    final inFlight = _sync;
    if (inFlight != null) return inFlight;

    final last = _lastSyncedAt;
    if (!force && last != null && DateTime.now().difference(last) < syncInterval) return Future.value();

    final sync = refreshAccount().then((_) {});
    _sync = sync;
    return sync.whenComplete(() => _sync = null);
  }

  /// Pretends the last read happened [age] ago, so a test can exercise the
  /// throttle without waiting it out.
  @visibleForTesting
  void debugBackdateLastSync(Duration age) => _lastSyncedAt = DateTime.now().subtract(age);

  /// Puts a freshly read [account] into [state] and notes when it was read.
  void _signedIn(Account account) {
    _lastSyncedAt = DateTime.now();
    state = AuthAuthenticated(account);
  }

  Future<void> _restoreSession() async {
    final token = await _storage.read(AppConstants.secureStorageAuthTokenKey);
    if (token == null || token.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final account = await _repository.me();
      _signedIn(account);
      unawaited(ref.read(pushNotificationServiceProvider.notifier).registerForCurrentAccount());
    } on UnauthenticatedException {
      await _storage.delete(AppConstants.secureStorageAuthTokenKey);
      state = const AuthUnauthenticated();
    } on AppException {
      // Network/server failure while validating a stored token is not the
      // same as an invalid token — keep it and let the user retry rather
      // than forcing a fresh login over a flaky connection (section 37).
      state = const AuthUnauthenticated(
        error: NetworkException("We couldn't reach Town Shoppy. Check your connection and try again."),
      );
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
      _signedIn(result.account);
      // Never awaited: a slow or declined permission prompt must not hold
      // up sign-in.
      unawaited(ref.read(pushNotificationServiceProvider.notifier).registerForCurrentAccount());
    } on AppException catch (e) {
      state = AuthUnauthenticated(error: e);
    }
  }

  /// Signs in with a Super Admin's single-use "login as customer" hand-off
  /// code (`ImpersonationController::exchange`). Replaces whatever session
  /// this browser already had. Unlike [login], a failure is thrown to the
  /// caller rather than parked in state, since the hand-off screen — not
  /// the Login form — is what needs to show it.
  ///
  /// Deliberately never registers this device for push: the person at the
  /// keyboard is support staff, and the customer's notifications must not
  /// start arriving on their machine.
  Future<void> signInWithHandoffCode(String code) async {
    // A fresh web load is still restoring the previous session; let it
    // finish first so it cannot overwrite the account set below.
    await _restore;

    final result = await _repository.exchangeImpersonationCode(code);

    await ref.read(pushNotificationServiceProvider.notifier).deregisterCurrentDevice();
    await _storage.write(AppConstants.secureStorageAuthTokenKey, result.token);
    ref.read(sessionEpochProvider.notifier).bump();
    _signedIn(result.account);
  }

  Future<void> register(String mobileNumber, String name, String password, {String? referralCode}) async {
    if (_isSubmitting) return;

    state = const AuthUnauthenticated(isSubmitting: true);
    try {
      final result = await _repository.register(
        mobileNumber: mobileNumber,
        name: name,
        password: password,
        referralCode: referralCode,
      );
      await _storage.write(AppConstants.secureStorageAuthTokenKey, result.token);
      ref.read(sessionEpochProvider.notifier).bump();
      _signedIn(result.account);
      unawaited(ref.read(pushNotificationServiceProvider.notifier).registerForCurrentAccount());
    } on AppException catch (e) {
      state = AuthUnauthenticated(error: e);
    }
  }

  /// Re-fetches `/auth/me` and swaps it into state in place -- used after a
  /// successful profile edit so the greeting/profile screen reflect the new
  /// name immediately, without the heavier session-epoch bump (which would
  /// also force-refetch every unrelated customer-scoped provider).
  ///
  /// Returns whether the refetch actually landed. Most callers can ignore
  /// it (a failed refresh here is a stale greeting at worst, corrected on
  /// the next natural one). The one caller that cannot ignore it is
  /// merchant registration: its whole "land in Business mode straight
  /// away" depends on this specific call picking up the merchant profile
  /// the account did not have a moment ago, and a network hiccup right
  /// after filling out a long form is not rare on a phone. See
  /// MerchantRegisterScreen's `_SuccessView`, which retries on this return
  /// value rather than navigating on a stale account.
  Future<bool> refreshAccount() async {
    final before = state;
    if (before is! AuthAuthenticated) return false;

    try {
      final account = await _repository.me();

      // The session may have moved on while the request was out: signed
      // out, started signing out, or been replaced by another account (an
      // admin hand-off). A late answer about the old session must not be
      // written over whatever is current now.
      final now = state;
      if (now is! AuthAuthenticated || now.isLoggingOut || now.account.id != account.id) return false;

      _signedIn(account);
      return true;
    } on AppException {
      return false;
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

  /// Deletes the signed-in account for good, then drops the session exactly
  /// as a sign-out would. Throws the server's [AppException] (wrong
  /// password, a business account that must go through support) and leaves
  /// the customer signed in, so the screen can show why.
  ///
  /// The state flips to signed-out BEFORE the local cleanup: that cleanup
  /// makes one last best-effort call with a token the server has already
  /// revoked, and its 401 must not be read as "your session expired".
  Future<void> deleteAccount({String? password}) async {
    await _repository.deleteAccount(password: password);

    state = const AuthUnauthenticated();
    await _clearSessionAndCustomerState();
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
