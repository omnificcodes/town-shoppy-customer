/// App-wide constant values that are not environment-specific.
class AppConstants {
  AppConstants._();

  static const String appName = 'Town Shoppy';

  /// Public pages on townshoppy.com that the app links to. The app stores
  /// list the same two URLs, so they must stay live.
  static const String privacyPolicyUrl = 'https://townshoppy.com/privacy-policy/';
  static const String deleteAccountHelpUrl = 'https://townshoppy.com/delete-account/';

  static const String supportEmail = 'support@townshoppy.com';

  static const Duration networkConnectTimeout = Duration(seconds: 15);
  static const Duration networkReceiveTimeout = Duration(seconds: 15);

  /// Sanctum plaintext token (`Account::createToken('api')->plainTextToken`)
  /// — no refresh-token flow exists on the backend; a 401 always means
  /// "sign in again," never "silently refresh" (see AuthController).
  static const String secureStorageAuthTokenKey = 'auth_token';

  /// Last-used [AppMode] (`customer` / `business`) for accounts that can use
  /// both -- see `AppModeController`. Cleared alongside the token on sign-out.
  static const String secureStorageAppModeKey = 'app_mode';

  /// The FCM token this install last successfully registered with the
  /// backend -- lets PushNotificationService skip a redundant
  /// register-device-token call on every app start when the token hasn't
  /// actually changed, and lets it deactivate the right token on logout.
  static const String secureStorageFcmTokenKey = 'fcm_token';
}
