import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'local_notification_service.dart';

/// Remote push delivery (FCM) sits behind this interface.
///
/// The default is [NoopPushService]: nothing is registered and notifications
/// arrive through the in-app notification centre (backend `/notifications/my`)
/// and local notifications. Push through Firebase Cloud Messaging is optional:
/// `FirebasePushService` (`firebase_push_service.dart`) replaces the no-op
/// through a [pushServiceProvider] override in `main.dart`, only when Firebase
/// initialises (it needs your own `google-services.json`).
abstract class PushService {
  /// Registers for push and starts listening. Safe to call repeatedly.
  Future<void> initialize({bool requestPermission = false});

  /// Stops pushes for this device reaching the signed-in account. Called just
  /// before logout, while the session is still valid. Never throws.
  Future<void> unregister();

  /// The current device push token, if any.
  String? get currentToken;
}

/// Push delivery is off: every call does nothing.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> initialize({bool requestPermission = false}) async {}

  @override
  Future<void> unregister() async {}

  @override
  String? get currentToken => null;
}

final pushServiceProvider = Provider<PushService>(
  (ref) => const NoopPushService(),
);

/// In-app / local notifications, plus whatever [PushService] is installed.
class NotificationService {
  final Ref _ref;
  bool _priceCountdownSynced = false;

  NotificationService(this._ref);

  Future<void> initialize({bool requestPermission = false}) async {
    try {
      await _ref
          .read(pushServiceProvider)
          .initialize(requestPermission: requestPermission);
    } catch (error) {
      debugPrint('[Notifications] Push init skipped: $error');
    }
    try {
      await LocalNotificationService.instance.ensureInitialized();
    } catch (error) {
      debugPrint('[Notifications] Local notification init skipped: $error');
    }

    if (!_priceCountdownSynced &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _priceCountdownSynced = await _syncActivePriceCountdownFromBackend();
    }
  }

  Future<bool> _syncActivePriceCountdownFromBackend() async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get(
        '/notifications/my',
        queryParameters: {'limit': 120},
      );
      final items = response.data['data'];
      if (items is! List) return true;

      Map<String, dynamic>? latestActive;
      for (final item in items) {
        if (item is! Map) continue;
        final type = item['type']?.toString();
        final data = item['data'];
        final effectiveAtRaw = data is Map
            ? data['effectiveAt']?.toString()
            : null;
        final effectiveAt = effectiveAtRaw == null
            ? null
            : DateTime.tryParse(effectiveAtRaw)?.toLocal();

        if (!LocalNotificationService.instance.isPriceCampaignType(type)) {
          continue;
        }

        if (type == 'price_change_campaign_applied') {
          await LocalNotificationService.instance.cancelPriceCountdown();
          return true;
        }

        if (effectiveAt == null || !effectiveAt.isAfter(DateTime.now())) {
          continue;
        }

        latestActive = Map<String, dynamic>.from(item);
        break;
      }

      if (latestActive == null) {
        await LocalNotificationService.instance.cancelPriceCountdown();
        return true;
      }

      final notificationData = latestActive['data'] is Map
          ? Map<String, dynamic>.from(latestActive['data'])
          : null;

      await LocalNotificationService.instance
          .syncPriceCountdownFromNotificationData(
            notificationData,
            title: latestActive['title']?.toString(),
            body: latestActive['body']?.toString(),
          );
      return true;
    } catch (error) {
      debugPrint('[Notifications] Active price countdown sync skipped: $error');
      return false;
    }
  }

  /// Called before logout so the backend stops pushing to this device.
  Future<void> unregisterPush() async {
    try {
      await _ref.read(pushServiceProvider).unregister();
    } catch (error) {
      debugPrint('[Notifications] Push unregister skipped: $error');
    }
  }

  String? get currentToken => _ref.read(pushServiceProvider).currentToken;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});
