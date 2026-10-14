import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

class NotificationDestination {
  const NotificationDestination({
    required this.route,
    required this.requiresAuthentication,
    this.overHome = false,
  });

  final String route;
  final bool requiresAuthentication;

  /// Opened on top of Home (so Back returns there) instead of replacing the
  /// whole stack; used for shared product links.
  final bool overHome;
}

class NotificationNavigationService {
  NotificationNavigationService._();

  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  static const Set<String> _orderNotificationTypes = {
    'order',
    'order_update',
    'payment',
    'payment_verified',
    'payment_rejected',
    'shipping',
  };

  static const Set<String> _negotiationNotificationTypes = {
    'negotiation',
    'negotiation_update',
    'negotiation_countered',
    'negotiation_accepted',
    'negotiation_rejected',
  };

  static const Set<String> _priceNotificationTypes = {
    'price_change_campaign_started',
    'price_change_campaign_12h',
    'price_change_campaign_6h',
    'price_change_campaign_20m',
    'price_change_campaign_applied',
    'price_change_campaign_3h',
    'price_change_campaign_1h',
    'price_change_campaign_5m',
  };

  final Set<String> _handledMessageIds = <String>{};
  NotificationDestination? _pendingDestination;
  bool _appReady = false;
  bool _isAuthenticated = false;
  bool _waitingForAuthentication = false;

  NotificationDestination? destinationFor(Map<dynamic, dynamic>? rawData) {
    if (rawData == null) return null;

    final data = rawData.map((key, value) => MapEntry(key.toString(), value));
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    final negotiationId =
        (data['negotiationId'] ?? data['negotiation_id'])?.toString().trim() ??
        '';
    final orderId =
        (data['orderId'] ?? data['order_id'])?.toString().trim() ?? '';

    final productId =
        (data['productId'] ?? data['product_id'])?.toString().trim() ?? '';
    if ((type == 'product_launched' || type == 'new_product') &&
        productId.isNotEmpty) {
      return NotificationDestination(
        route: '/product/${Uri.encodeComponent(productId)}',
        requiresAuthentication: false,
      );
    }

    if (_negotiationNotificationTypes.contains(type) &&
        negotiationId.isNotEmpty) {
      return NotificationDestination(
        route: '/negotiation-detail/${Uri.encodeComponent(negotiationId)}',
        requiresAuthentication: true,
      );
    }

    if (orderId.isNotEmpty) {
      return NotificationDestination(
        route: '/tracking/${Uri.encodeComponent(orderId)}',
        requiresAuthentication: true,
      );
    }

    if (_orderNotificationTypes.contains(type)) {
      return const NotificationDestination(
        route: '/previous-orders',
        requiresAuthentication: true,
      );
    }

    if (_priceNotificationTypes.contains(type)) {
      return const NotificationDestination(
        route: '/home',
        requiresAuthentication: false,
      );
    }

    return null;
  }

  bool handlePayload(Map<dynamic, dynamic>? data, {String? messageId}) {
    final destination = destinationFor(data);
    if (destination == null || !_rememberMessage(messageId)) return false;

    _pendingDestination = destination;
    return _drainPendingDestination();
  }

  bool openFromContext(
    BuildContext context,
    Map<dynamic, dynamic>? data, {
    required bool isAuthenticated,
  }) {
    final destination = destinationFor(data);
    if (destination == null) return false;

    _isAuthenticated = isAuthenticated;
    if (destination.requiresAuthentication && !isAuthenticated) {
      _pendingDestination = destination;
      _waitingForAuthentication = true;
      context.push('/login');
      return true;
    }

    context.push(destination.route);
    return true;
  }

  /// Opens a shared link's [route] (e.g. `/product/<slug>`). While the app
  /// is running it is pushed on top of the current screen; at launch it
  /// waits for the splash (update check, sign-in state) and then opens over
  /// Home.
  void openDeepLink(String route) {
    if (_appReady) {
      appRouter.push(route);
      return;
    }
    _pendingDestination = NotificationDestination(
      route: route,
      requiresAuthentication: false,
      overHome: true,
    );
  }

  bool completeStartup({required bool isAuthenticated}) {
    _appReady = true;
    _isAuthenticated = isAuthenticated;
    return _drainPendingDestination();
  }

  void updateAuthentication(bool isAuthenticated) {
    _isAuthenticated = isAuthenticated;
    if (isAuthenticated) {
      _waitingForAuthentication = false;
      // Authentication methods update provider state before their UI redirects
      // to Home. Drain on the next frame so the notification destination is the
      // final navigation action rather than being overwritten by that redirect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _drainPendingDestination();
      });
    }
  }

  bool _drainPendingDestination() {
    final destination = _pendingDestination;
    if (!_appReady || destination == null) return false;

    if (destination.requiresAuthentication && !_isAuthenticated) {
      if (!_waitingForAuthentication) {
        _waitingForAuthentication = true;
        appRouter.go('/login');
      }
      return true;
    }

    _pendingDestination = null;
    _waitingForAuthentication = false;
    if (destination.overHome) {
      appRouter.go('/home');
      // Once Home is in place, so Back from the page returns to it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.push(destination.route);
      });
      return true;
    }
    appRouter.go(destination.route);
    return true;
  }

  bool _rememberMessage(String? messageId) {
    final normalized = messageId?.trim() ?? '';
    if (normalized.isEmpty) return true;
    if (!_handledMessageIds.add(normalized)) return false;

    if (_handledMessageIds.length > 100) {
      _handledMessageIds.remove(_handledMessageIds.first);
    }
    return true;
  }
}
