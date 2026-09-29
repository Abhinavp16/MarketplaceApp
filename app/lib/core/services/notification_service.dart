import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'local_notification_service.dart';

/// In-app / local notifications only.
///
/// The demo build has no push provider (no Firebase / FCM). Notifications are
/// delivered through the in-app notification centre, which is fed by the
/// backend `/notifications/my` endpoint. Calling [initialize] only prepares
/// local notification channels and syncs any active price countdown.
class NotificationService {
  final Ref _ref;
  bool _priceCountdownSynced = false;

  NotificationService(this._ref);

  Future<void> initialize({bool requestPermission = false}) async {
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

  /// No push token is used in the demo build.
  String? get currentToken => null;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});
