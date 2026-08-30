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

  static bool get isProduction => name == 'production';
}
