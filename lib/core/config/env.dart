/// Compile-time environment configuration.
///
/// No API URL is hardcoded into app logic — every build picks its target
/// via `--dart-define`, e.g.:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://staging.townshoppy.app/api/v1
/// ```
///
/// [apiBaseUrl] defaults to the local Laravel Sail host (`10.0.2.2` is the
/// Android emulator's alias for the host machine's `localhost`; iOS
/// simulators and desktop/web builds can reach `localhost` directly, so a
/// real device or CI build must always pass `API_BASE_URL` explicitly).
class Env {
  Env._();

  static const String name = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Origin of the merchant web app (no trailing slash), used only for the
  /// subscription checkout handoff -- Business mode opens
  /// `<origin>/merchant/subscriptions/subscribe` in the browser rather than
  /// embedding a payment SDK (product decision: keeps the app clear of the
  /// app stores' in-app-purchase rules). Empty when not configured, in
  /// which case the Subscriptions screen explains where to subscribe
  /// instead of offering a dead link.
  static const String merchantWebUrl = String.fromEnvironment('MERCHANT_WEB_URL', defaultValue: '');

  /// This app's OWN hosted web origin (no trailing slash) -- used only to
  /// build a shareable product link (`$customerWebUrl/products/{id}`) for
  /// the WhatsApp order message, since that link must be a real URL a
  /// recipient without the app can still open in a browser. Empty when not
  /// configured (e.g. local dev), in which case the order message simply
  /// omits the link rather than sending a dead one.
  static const String customerWebUrl = String.fromEnvironment('CUSTOMER_WEB_URL', defaultValue: '');

  static bool get isProduction => name == 'production';
}
