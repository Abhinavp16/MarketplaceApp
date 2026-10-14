import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/app_update_provider.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: AppFonts.jakarta(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.splashTagline,
                  textAlign: TextAlign.center,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
