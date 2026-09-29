import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/app_update_provider.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait minimum splash time, but also ensure auth check has completed
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    final updateRequired = await ref
        .read(appUpdateControllerProvider)
        .checkAndShow(context, isInitialCheck: true);
    if (!mounted || updateRequired) return;

    // Wait for auth loading to finish (max 3 more seconds)
    for (int i = 0; i < 30; i++) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (!authState.isLoading) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;
    final authState = ref.read(authProvider);

    try {
      await ref.read(notificationServiceProvider).initialize();
    } catch (error) {
      debugPrint('[Notifications] Initialization skipped: $error');
    }
    if (!mounted) return;

    debugPrint(
      '[Splash] Auth check done: isAuthenticated=${authState.isAuthenticated}, user=${authState.user?.name}',
    );

    final isFirstLaunch = await StorageService.isFirstLaunch();
    if (!mounted) return;

    if (isFirstLaunch) {
      context.go('/permissions-onboarding');
      return;
    }

    final openedNotification = NotificationNavigationService.instance
        .completeStartup(isAuthenticated: authState.isAuthenticated);
    if (!openedNotification && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.appTitle,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.splashTagline,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
