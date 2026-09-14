import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/notifications_repository.dart';
import '../presentation/notification_navigation.dart';
import 'notifications_controller.dart';
import 'unread_count_provider.dart';

/// Whether this build can register for push at all -- Android and iOS
/// native apps only (Firebase Messaging has no meaningful web story here,
/// and this app's own web build already has its own "open in the
/// browser" flows for everything push would otherwise cover). A provider
/// rather than a bare platform check purely so a test can override it,
/// the same seam pattern `nativeCheckoutAvailableProvider` already
/// establishes. `!kIsWeb` first so `Platform.isAndroid`/`isIOS` — which
/// throw if actually evaluated on a web build — never run there.
final pushNotificationsSupportedProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;

  return Platform.isAndroid || Platform.isIOS;
});

/// Owns the Firebase Messaging lifecycle end to end: permission (asked
/// once — the OS itself, not this app, decides whether a repeat call ever
/// re-prompts), token fetch/refresh/registration, foreground/background/
/// terminated message handling, and tap-to-navigate. Reuses
/// `notificationTarget()` (the exact same type-to-route map the in-app
/// notification list already taps through) rather than a second,
/// drifting copy of that logic.
///
/// Listener wiring (`build()`) happens unconditionally and early — a
/// push can arrive before login finishes restoring. Token
/// registration (`registerForCurrentAccount()`) is a separate, explicit
/// step called only once an [Account] actually exists, since a token is
/// meaningless without one to attach it to.
class PushNotificationService extends Notifier<void> {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void build() {
    if (ref.watch(pushNotificationsSupportedProvider)) {
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
    }

    ref.onDispose(() {
      _foregroundSub?.cancel();
      _openedAppSub?.cancel();
      _tokenRefreshSub?.cancel();
    });
  }

  /// Requests notification permission (a no-op re-prompt if the OS
  /// already recorded a decision) and registers this install's current
  /// token, but only once an account is actually signed in — call this
  /// from `AuthController` right after `login()`/`register()` succeed and
  /// after a successful session restore, never before. Never awaited by
  /// its caller: a slow/declined permission dialog must not block sign-in.
  Future<void> registerForCurrentAccount() async {
    if (!ref.read(pushNotificationsSupportedProvider)) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (_) {
      // Firebase not configured yet (no google-services.json /
      // GoogleService-Info.plist in this build) or a transient failure --
      // push is best-effort and must never block or crash the app that
      // asked for it.
    }
  }

  /// Deactivates this install's token server-side and forgets it locally,
  /// so the NEXT account to sign in on this device starts clean and a
  /// signed-out device stops receiving pushes meant for whoever just left.
  Future<void> deregisterCurrentDevice() async {
    if (!ref.read(pushNotificationsSupportedProvider)) return;

    final storage = ref.read(secureStorageServiceProvider);
    final token = await storage.read(AppConstants.secureStorageFcmTokenKey);
    if (token == null) return;

    try {
      await ref.read(notificationsRepositoryProvider).deactivateDeviceToken(token);
    } on AppException {
      // Best-effort — the local record is cleared either way below, and a
      // stale-but-still-active row server-side is harmless (it just means
      // this device keeps getting pushes for the account that logged out
      // until the NEXT login re-registers over it, which normal use makes
      // vanishingly unlikely in practice).
    }

    await storage.delete(AppConstants.secureStorageFcmTokenKey);
  }

  /// Call once, after the widget tree (and this app's router) exist — the
  /// app may have been launched BY tapping a push notification while
  /// fully terminated, and that's the only way to learn which one.
  Future<void> handleInitialMessage() async {
    if (!ref.read(pushNotificationsSupportedProvider)) return;

    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) await _openFromData(message.data);
  }

  Future<void> _onTokenRefresh(String token) async {
    // A refreshed token is only worth registering if someone is actually
    // signed in to attach it to -- otherwise it's remembered nowhere and
    // simply re-fetched (and registered then) on the next successful login.
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      await _registerToken(token);
    }
  }

  Future<void> _registerToken(String token) async {
    final storage = ref.read(secureStorageServiceProvider);
    if (await storage.read(AppConstants.secureStorageFcmTokenKey) == token) {
      return; // Unchanged since our last successful registration -- skip the network call.
    }

    try {
      await ref.read(notificationsRepositoryProvider).registerDeviceToken(
            fcmToken: token,
            platform: Platform.isIOS ? 'ios' : 'android',
          );
      await storage.write(AppConstants.secureStorageFcmTokenKey, token);
    } on AppException {
      // Best-effort — a failed registration just means this device stays
      // un-registered until the next app start/token refresh retries it.
    }
  }

  /// A message arriving while the app is already open. There is no
  /// platform-shown banner to rely on here (that's what a system tray
  /// does for background/terminated messages) -- what's real and correct
  /// without adding a whole local-notifications plugin for one banner is
  /// refreshing the inbox and its badge immediately, so the new
  /// notification is already sitting there the moment the user opens it.
  void _onForegroundMessage(RemoteMessage message) {
    ref
      ..invalidate(unreadNotificationCountProvider)
      ..invalidate(notificationsControllerProvider);
  }

  /// The app was backgrounded, not terminated, and the user tapped the
  /// system notification to bring it back to the foreground.
  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    await _openFromData(message.data);
  }

  Future<void> _openFromData(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    if (type == null) return;

    final target = notificationTarget(type);
    if (target == null) return;

    final auth = ref.read(authControllerProvider);
    if (target.mode == AppMode.business && !(auth is AuthAuthenticated && auth.account.hasMerchantAccess)) {
      // Defensive only -- every business-mode notification type is sent
      // exclusively to a merchant owner/staff account server-side.
      return;
    }

    if (ref.read(appModeControllerProvider).mode != target.mode) {
      await ref.read(appModeControllerProvider.notifier).select(target.mode);
    }

    ref.read(appRouterProvider).go(target.path);
  }
}

final pushNotificationServiceProvider = NotifierProvider<PushNotificationService, void>(PushNotificationService.new);

/// Registered in `main()` before `runApp()`, per firebase_messaging's own
/// requirement -- a message that arrives while the app is backgrounded or
/// fully terminated is handled in a fresh, separate isolate with no
/// access to this app's state (no Riverpod container, no navigator,
/// nothing built by `runApp()`), so this is deliberately minimal.
/// Nothing here needs to display the notification itself — every push
/// this app sends already carries a `notification` payload (see
/// PushNotificationChannel on the backend), which Android/iOS show in the
/// system tray automatically with no app code involved; registering this
/// handler exists only to satisfy the plugin's own contract so
/// `getInitialMessage()`/`onMessageOpenedApp` behave correctly once the
/// user actually taps it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
