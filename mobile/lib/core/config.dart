/// App-wide configuration for the Flutter personnel app.
class AppConfig {
  AppConfig._();

  /// FastAPI backend base URL.
  ///
  /// Override at run/build time with:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  ///
  /// - Default works for desktop/web/Windows testing (host loopback).
  /// - For the Android emulator use `http://10.0.2.2:8000` (host loopback).
  /// - For a physical phone use the dev machine's LAN IP.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}