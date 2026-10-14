import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'local_notification_service.dart';
import 'notification_navigation_service.dart';
import 'notification_service.dart';

/// Set `--dart-define=ENABLE_PUSH=false` to force push off even when a
/// `google-services.json` is present. Defaults to on, which is still safe
/// without any Firebase configuration: initialisation simply fails and the
/// app keeps using [NoopPushService].
const bool kEnablePush = bool.fromEnvironment(
  'ENABLE_PUSH',
  defaultValue: true,
);

/// Handles background / terminated-state messages. Must be a top-level
/// function so the engine can start it in its own isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    return;
  }
  debugPrint('[FCM] Background message: ${message.messageId}');
  await LocalNotificationService.instance.handleRemoteMessage(message);
}

/// Firebase Cloud Messaging implementation of [PushService].
///
/// Create it only after [FirebasePushService.bootstrap] returned true (see
/// `main.dart`); until then the app runs on [NoopPushService].
class FirebasePushService implements PushService {
  FirebasePushService(this._ref);

  final Ref _ref;

  String? _currentToken;
  Future<void>? _lifecycleInitialization;
  bool _messageHandlersInstalled = false;
  bool _tokenRefreshListenerInstalled = false;
  bool _isTokenRegistered = false;
  bool _isRegistrationInFlight = false;
  int _registrationAttempt = 0;
  Timer? _registrationRetryTimer;

  static const int _maxRegistrationAttempts = 6;

  static bool _bootstrapLogged = false;

  /// Initialises Firebase and installs the background handler. Returns false
  /// (and never throws) when push is disabled, or Firebase cannot start, e.g.
  /// because no `google-services.json` was bundled. Logged once in debug.
  static Future<bool> bootstrap({
    bool enabled = kEnablePush,
    Future<void> Function()? initializer,
  }) async {
    if (!enabled) return false;
    try {
      await (initializer ?? _initializeFirebase)();
      return true;
    } catch (error) {
      if (!_bootstrapLogged) {
        _bootstrapLogged = true;
        debugPrint('[FCM] Push disabled (Firebase not configured): $error');
      }
      return false;
    }
  }

  static Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  @override
  String? get currentToken => _currentToken;

  @override
  Future<void> initialize({bool requestPermission = false}) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase not configured, skipping push');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    unawaited(_initializeLifecycleInBackground(messaging));

    // Permission follows the app's existing flow: the onboarding screen calls
    // initialize(requestPermission: true); every other call only reads it.
    final settings = requestPermission
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
        : await messaging.getNotificationSettings();
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _getAndRegisterToken(messaging);
      _setupTokenRefreshListener(messaging);
    }
  }

  /// Tells the backend to stop sending pushes for this device to the account
  /// that is signing out. Best effort; must run while still authenticated.
  @override
  Future<void> unregister() async {
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    _isTokenRegistered = false;
    _registrationAttempt = 0;

    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    try {
      await _ref
          .read(apiClientProvider)
          .post('/notifications/unregister-token', data: {'fcmToken': token});
      debugPrint('[FCM] Token unregistered from backend');
    } catch (error) {
      debugPrint('[FCM] Token unregister skipped: $error');
    }
  }

  Future<void> _initializeLifecycleInBackground(
    FirebaseMessaging messaging,
  ) async {
    try {
      await _ensureLifecycleInitialized(messaging);
    } catch (error) {
      debugPrint('[FCM] Lifecycle initialization failed: $error');
    }
  }

  Future<void> _ensureLifecycleInitialized(FirebaseMessaging messaging) {
    final existing = _lifecycleInitialization;
    if (existing != null) return existing;

    final initialization = _initializeLifecycle(messaging);
    _lifecycleInitialization = initialization;
    return initialization.catchError((Object error) {
      if (identical(_lifecycleInitialization, initialization)) {
        _lifecycleInitialization = null;
      }
      throw error;
    });
  }

  Future<void> _initializeLifecycle(FirebaseMessaging messaging) async {
    await LocalNotificationService.instance.ensureInitialized();
    if (!_messageHandlersInstalled) {
      _messageHandlersInstalled = true;
      _setupMessageHandlers();
    }

    // App was launched by tapping a push while terminated.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Initial message: ${initialMessage.data}');
      NotificationNavigationService.instance.handlePayload(
        initialMessage.data,
        messageId: initialMessage.messageId,
      );
    }
  }

  Future<void> _getAndRegisterToken(FirebaseMessaging messaging) async {
    if (_isRegistrationInFlight) return;
    _isRegistrationInFlight = true;

    try {
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken() returned no token; scheduling retry');
        _scheduleRegistrationRetry();
        return;
      }

      _currentToken = token;
      // Debug builds only: never print tokens in release.
      if (kDebugMode) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
      }

      if (await _registerTokenWithBackend(token)) {
        _isTokenRegistered = true;
        _registrationAttempt = 0;
        _registrationRetryTimer?.cancel();
        _registrationRetryTimer = null;
      } else {
        _scheduleRegistrationRetry();
      }
    } catch (error) {
      debugPrint('[FCM] Error getting token: $error');
      _scheduleRegistrationRetry();
    } finally {
      _isRegistrationInFlight = false;
    }
  }

  void _scheduleRegistrationRetry() {
    if (_isTokenRegistered) return;
    if (_registrationRetryTimer != null) return;
    if (_registrationAttempt >= _maxRegistrationAttempts) {
      debugPrint(
        '[FCM] Giving up token registration after $_registrationAttempt '
        'attempts. It will retry on next app start, login, or token refresh.',
      );
      return;
    }

    _registrationAttempt++;
    final delay = Duration(seconds: 5 * _registrationAttempt);
    debugPrint(
      '[FCM] Retrying token registration in ${delay.inSeconds}s '
      '(attempt $_registrationAttempt/$_maxRegistrationAttempts)',
    );

    _registrationRetryTimer = Timer(delay, () async {
      _registrationRetryTimer = null;
      if (_isTokenRegistered || Firebase.apps.isEmpty) return;
      await _getAndRegisterToken(FirebaseMessaging.instance);
    });
  }

  void _setupTokenRefreshListener(FirebaseMessaging messaging) {
    if (_tokenRefreshListenerInstalled) return;
    _tokenRefreshListenerInstalled = true;

    messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      _currentToken = newToken;
      _isTokenRegistered = await _registerTokenWithBackend(newToken);
      if (!_isTokenRegistered) _scheduleRegistrationRetry();
    });
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');

      final type = message.data['type']?.toString();
      if (LocalNotificationService.instance.isPriceCampaignType(type)) {
        await LocalNotificationService.instance.handleRemoteMessage(message);
      } else {
        // The system does not draw a notification for a foreground message,
        // so show it through the local notification service.
        final title =
            message.notification?.title ??
            message.data['title']?.toString() ??
            'Notification';
        final body =
            message.notification?.body ?? message.data['body']?.toString() ?? '';
        if (body.isNotEmpty || title.isNotEmpty) {
          await LocalNotificationService.instance.showSimpleNotification(
            title: title,
            body: body,
            data: message.data,
            messageId: message.messageId,
          );
        }
      }

      if (type == 'ROLE_UPDATED') {
        unawaited(_ref.read(authProvider.notifier).fetchCurrentUser());
      }
    });

    // Tapped a push while the app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('[FCM] Message opened app: ${message.data}');

      await LocalNotificationService.instance.handleRemoteMessage(message);
      NotificationNavigationService.instance.handlePayload(
        message.data,
        messageId: message.messageId,
      );

      if (message.data['type'] == 'ROLE_UPDATED') {
        unawaited(_ref.read(authProvider.notifier).fetchCurrentUser());
      }
    });
  }

  Future<bool> _registerTokenWithBackend(String token) async {
    try {
      await _ref
          .read(apiClientProvider)
          .post(
            '/notifications/register-token',
            data: {'fcmToken': token, 'platform': 'android'},
          );
      debugPrint('[FCM] Token registered with backend');
      return true;
    } on DioException catch (error) {
      // A 401 means registration ran before login; it retries after auth.
      debugPrint(
        '[FCM] Failed to register token '
        '(status: ${error.response?.statusCode ?? 'none'}): ${error.message}',
      );
      return false;
    } catch (error) {
      debugPrint('[FCM] Unexpected error registering token: $error');
      return false;
    }
  }
}

/// Provider overrides that install [FirebasePushService] once [bootstrap]
/// succeeded; empty (keeps [NoopPushService]) otherwise.
List<Override> pushServiceOverrides({required bool firebaseReady}) => [
  if (firebaseReady)
    pushServiceProvider.overrideWith((ref) => FirebasePushService(ref)),
];
