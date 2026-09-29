import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';
import 'notification_navigation_service.dart';

const String _shopNowActionId = 'price_campaign_shop_now';
const String _priceCampaignPayload = 'price_campaign_open_home';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Keep a background entry point registered for Android action taps.
}

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _defaultChannelId = 'tradehub_default';
  static const String _countdownChannelId = 'tradehub_price_countdown';
  static const int _priceCountdownNotificationId = 910159;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// App text in the saved language. Local notifications are shown without a
  /// BuildContext (possibly from a background isolate), so the language is
  /// read from storage; English is used if that fails.
  Future<AppLocalizations> _l10n() async {
    try {
      return lookupAppLocalizations(await LocaleNotifier.loadSaved());
    } catch (_) {
      return lookupAppLocalizations(LocaleNotifier.english);
    }
  }

  static const Set<String> _priceCampaignTypes = {
    'price_change_campaign_started',
    'price_change_campaign_12h',
    'price_change_campaign_6h',
    'price_change_campaign_20m',
    'price_change_campaign_applied',
    // Legacy keys kept for older stored notifications.
    'price_change_campaign_3h',
    'price_change_campaign_1h',
    'price_change_campaign_5m',
  };

  Future<void> ensureInitialized() async {
    if (_isInitialized || kIsWeb) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final l10n = await _l10n();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _defaultChannelId,
        l10n.localNotificationGeneralChannel,
        description: l10n.localNotificationGeneralChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _countdownChannelId,
        l10n.localNotificationCountdownChannel,
        description: l10n.localNotificationCountdownChannelDescription,
        importance: Importance.high,
      ),
    );

    _isInitialized = true;
  }

  bool isPriceCampaignType(String? type) {
    return type != null && _priceCampaignTypes.contains(type);
  }

  Future<void> syncPriceCountdownFromNotificationData(
    Map<String, dynamic>? data, {
    String? title,
    String? body,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        data == null) {
      return;
    }

    await ensureInitialized();

    final type = data['type']?.toString();
    if (!isPriceCampaignType(type)) {
      return;
    }

    if (type == 'price_change_campaign_applied') {
      await cancelPriceCountdown();
      return;
    }

    final l10n = await _l10n();
    await syncPriceCountdown(
      type: type!,
      title:
          title ??
          data['title']?.toString() ??
          l10n.localNotificationPriceUpdateScheduled,
      body:
          body ??
          data['body']?.toString() ??
          l10n.localNotificationPriceUpdateActive,
      effectiveAtIso: data['effectiveAt']?.toString(),
    );
  }

  Future<void> syncPriceCountdown({
    required String type,
    required String title,
    required String body,
    required String? effectiveAtIso,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final effectiveAt = effectiveAtIso == null
        ? null
        : DateTime.tryParse(effectiveAtIso)?.toLocal();
    if (effectiveAt == null) {
      return;
    }

    final remaining = effectiveAt.difference(DateTime.now());
    if (!remaining.isNegative && remaining > Duration.zero) {
      final l10n = await _l10n();
      await _plugin.show(
        _priceCountdownNotificationId,
        l10n.localNotificationBrand,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _countdownChannelId,
            l10n.localNotificationCountdownChannel,
            channelDescription:
                l10n.localNotificationCountdownChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: true,
            when: effectiveAt.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: remaining.inMilliseconds,
            largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
            color: const Color(0xFF0F766E),
            category: AndroidNotificationCategory.promo,
            subText: title,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: l10n.localNotificationBrand,
              summaryText: title,
            ),
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                _shopNowActionId,
                l10n.localNotificationShopNow,
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ],
          ),
        ),
        payload: _priceCampaignPayload,
      );
    } else {
      await cancelPriceCountdown();
    }
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? messageId,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final payloadData = <String, dynamic>{
      ...?data,
      if (messageId != null && messageId.trim().isNotEmpty)
        '_messageId': messageId,
    };
    final payload = payloadData.isEmpty ? null : jsonEncode(payloadData);
    final l10n = await _l10n();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannelId,
          l10n.localNotificationGeneralChannel,
          channelDescription: l10n.localNotificationGeneralChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
          color: const Color(0xFF0F766E),
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: l10n.localNotificationBrand,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancelPriceCountdown() async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _plugin.cancel(_priceCountdownNotificationId);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == _priceCampaignPayload ||
        response.actionId == _shopNowActionId) {
      NotificationNavigationService.instance.handlePayload(const {
        'type': 'price_change_campaign_started',
      });
      return;
    }

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      NotificationNavigationService.instance.handlePayload(
        decoded,
        messageId: decoded['_messageId']?.toString(),
      );
    } catch (error) {
      debugPrint('[Notifications] Ignoring invalid local payload: $error');
    }
  }
}
