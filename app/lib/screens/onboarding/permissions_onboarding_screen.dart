import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class PermissionsOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends ConsumerState<PermissionsOnboardingScreen> {
  bool _isContinuing = false;

  /// Shown once, until the user has picked a language on this device.
  bool _showLanguageChoice = false;

  @override
  void initState() {
    super.initState();
    _checkLanguageChoice();
  }

  Future<void> _checkLanguageChoice() async {
    final hasChoice = await LocaleNotifier.hasSavedChoice();
    if (!mounted || hasChoice) return;
    setState(() => _showLanguageChoice = true);
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await ref
          .read(notificationServiceProvider)
          .initialize(requestPermission: true);
    } catch (error) {
      debugPrint('[Notifications] Permission setup skipped: $error');
    }
  }

  Future<void> _complete({required bool requestNotificationPermission}) async {
    if (_isContinuing) return;
    setState(() => _isContinuing = true);

    try {
      if (requestNotificationPermission) {
        // Native notification setup can wait on an iOS permission or APNs call.
        // It must not block a user from completing onboarding.
        unawaited(_requestNotificationPermission());
      }

      await StorageService.setFirstLaunchComplete();
      if (!mounted) return;

      final openedNotification = NotificationNavigationService.instance
          .completeStartup(
            isAuthenticated: ref.read(authProvider).isAuthenticated,
          );
      if (!openedNotification && mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF134E4A);
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF475569);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showLanguageChoice) ...[
                    const _LanguageChoice(),
                    const SizedBox(height: 28),
                  ],
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.onboardingTitle,
                    style: AppFonts.jakarta(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.onboardingSubtitle,
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      height: 1.55,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _PermissionBenefit(
                    icon: Icons.notifications_outlined,
                    title: l10n.onboardingNotificationsTitle,
                    description: l10n.onboardingNotificationsBody,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.onboardingOtherPermissionsNote,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      height: 1.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isContinuing
                          ? null
                          : () =>
                                _complete(requestNotificationPermission: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isContinuing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l10n.onboardingEnableNotifications,
                              style: AppFonts.jakarta(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isContinuing
                          ? null
                          : () =>
                                _complete(requestNotificationPermission: false),
                      child: Text(
                        l10n.onboardingNotNow,
                        style: AppFonts.jakarta(
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two big buttons to pick the app language (English / हिंदी).
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeProvider).languageCode;

    Widget option(Locale locale, String label) {
      final selected = current == locale.languageCode;
      const primary = Color(0xFF134E4A);
      return Expanded(
        child: Material(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ref.read(localeProvider.notifier).setLocale(locale),
            child: Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? primary : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: AppFonts.jakarta(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.languageChooseTitle,
          style: AppFonts.jakarta(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.languageChooseSubtitle,
          style: AppFonts.jakarta(
            fontSize: 13,
            height: 1.5,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            option(LocaleNotifier.english, l10n.languageEnglish),
            const SizedBox(width: 12),
            option(LocaleNotifier.hindi, l10n.languageHindi),
          ],
        ),
      ],
    );
  }
}

class _PermissionBenefit extends StatelessWidget {
  const _PermissionBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF134E4A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF134E4A), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.jakarta(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
