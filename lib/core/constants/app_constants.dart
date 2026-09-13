/// App-wide constant values that are not environment-specific.
class AppConstants {
  AppConstants._();

  static const String appName = 'Town Shoppy';

  static const Duration networkConnectTimeout = Duration(seconds: 15);
  static const Duration networkReceiveTimeout = Duration(seconds: 15);

  /// Sanctum plaintext token (`Account::createToken('api')->plainTextToken`)
  /// — no refresh-token flow exists on the backend; a 401 always means
  /// "sign in again," never "silently refresh" (see AuthController).
  static const String secureStorageAuthTokenKey = 'auth_token';

  /// Last-used [AppMode] (`customer` / `business`) for accounts that can use
  /// both -- see `AppModeController`. Cleared alongside the token on sign-out.
  static const String secureStorageAppModeKey = 'app_mode';
}
