import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/api_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/navigation/app_navigator_key.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/app_update_provider.dart';
import 'core/providers/locale_provider.dart';
import 'l10n/l10n.dart';
import 'core/services/notification_navigation_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/app_lifecycle_service.dart';
import 'widgets/config_required_screen.dart';

final GlobalKey<ScaffoldMessengerState> scafoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!ApiConfig.isConfigured) {
    // No backend URL was provided at build time: refuse to run.
    runApp(const ConfigRequiredApp());
    return;
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Saved language (English/Hindi) and Hindi month/day names for dates.
  final savedLocale = await LocaleNotifier.loadSaved();
  await initializeDateFormatting('en');
  await initializeDateFormatting('hi');
  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleNotifier(savedLocale)),
      ],
      child: const TradeHubApp(),
    ),
  );
}

class TradeHubApp extends StatelessWidget {
  const TradeHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NotificationBootstrap();
  }
}

class _NotificationBootstrap extends ConsumerStatefulWidget {
  const _NotificationBootstrap();

  @override
  ConsumerState<_NotificationBootstrap> createState() =>
      _NotificationBootstrapState();
}

class _NotificationBootstrapState extends ConsumerState<_NotificationBootstrap>
    with WidgetsBindingObserver {
  ProviderSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // ✓ NEW: Initialize app lifecycle observer for token refresh on resume
    AppLifecycleService().initialize();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = ref.listenManual<AuthState>(authProvider, (
      previous,
      next,
    ) {
      NotificationNavigationService.instance.updateAuthentication(
        next.isAuthenticated,
      );

      final justAuthenticated =
          previous != null &&
          next.isAuthenticated &&
          previous.isAuthenticated != true;
      if (justAuthenticated) {
        unawaited(_registerNotificationsForAuthenticatedUser());
      }
      // Keep the account's language in sync (used for notifications).
      if (next.isAuthenticated) {
        unawaited(ref.read(localeProvider.notifier).syncWithServer());
      }
    }, fireImmediately: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    unawaited(ref.read(appUpdateControllerProvider).checkAndShow(context));
  }

  Future<void> _registerNotificationsForAuthenticatedUser() async {
    try {
      await ref.read(notificationServiceProvider).initialize();
    } catch (error) {
      debugPrint('[Notifications] Login registration skipped: $error');
    }
  }

  @override
  void dispose() {
    // ✓ NEW: Dispose app lifecycle observer
    AppLifecycleService().dispose();
    WidgetsBinding.instance.removeObserver(this);

    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scafoldMessengerKey,
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: LocaleNotifier.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
