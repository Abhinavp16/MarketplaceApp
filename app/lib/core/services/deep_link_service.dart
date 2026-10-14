import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'notification_navigation_service.dart';

/// Opens shared website links in the app. A product shared from the app is
/// `https://demo.demomart.example/products/<slug>`; with the app installed,
/// Android hands that URL here (see the intent filter in AndroidManifest; the
/// demo domain is a placeholder, so the link is not a verified App Link) and
/// it opens the product page. Other website pages are ignored.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  static const Set<String> _hosts = {
    'demo.demomart.example',
    'www.demo.demomart.example',
  };

  StreamSubscription<Uri>? _subscription;

  /// Starts listening; call once, early, so the link that launched the app
  /// (cold start) is caught too.
  void initialize() {
    if (_subscription != null || kIsWeb) return;
    try {
      // Emits the launch link first, then links that arrive while running.
      _subscription = AppLinks().uriLinkStream.listen(
        open,
        onError: (Object error) => debugPrint('[DeepLink] $error'),
      );
    } catch (error) {
      debugPrint('[DeepLink] Not available: $error');
    }
  }

  /// Opens [uri] when it is a product link; returns whether it was one.
  bool open(Uri uri) {
    final route = routeFor(uri);
    if (route == null) return false;
    debugPrint('[DeepLink] $uri -> $route');
    NotificationNavigationService.instance.openDeepLink(route);
    return true;
  }

  /// App route for a website link, or null: `/products/<slug>` (with or
  /// without www, trailing slash or query) becomes `/product/<slug>`.
  static String? routeFor(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (!_hosts.contains(uri.host.toLowerCase())) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 2 || segments.first != 'products') return null;
    final slug = segments[1].trim();
    if (slug.isEmpty) return null;
    return '/product/${Uri.encodeComponent(slug)}';
  }
}
