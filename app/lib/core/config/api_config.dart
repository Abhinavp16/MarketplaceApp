/// API configuration.
///
/// The demo build has NO built-in backend URL. The API base URL must be passed
/// at build/run time and is never hard-coded:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1   (Android emulator)
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5050/api/v1  (adb reverse / desktop)
///
/// If `API_BASE_URL` is missing the app shows a "Configuration required"
/// screen instead of starting (see `ConfigRequiredApp`).
library;

class ApiConfig {
  static const String _explicitBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// True when the app was built with `--dart-define=API_BASE_URL=...`.
  static bool get isConfigured => _explicitBaseUrl.trim().isNotEmpty;

  /// The configured API base URL without a trailing slash (empty if unset).
  static String get baseUrl {
    final value = _explicitBaseUrl.trim();
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// Server origin (API base URL without the `/api/v1` suffix).
  static String get publicBaseUrl => baseUrl.replaceFirst('/api/v1', '');

  static String normalizeMediaUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('/')) {
      return '$publicBaseUrl$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    final apiUri = Uri.tryParse(publicBaseUrl);
    if (uri == null || apiUri == null) {
      return trimmed;
    }

    final isLoopbackHost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    final apiUsesLoopback =
        apiUri.host == 'localhost' || apiUri.host == '127.0.0.1';

    if (isLoopbackHost && !apiUsesLoopback) {
      return uri
          .replace(
            scheme: apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
          )
          .toString();
    }

    return trimmed;
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
