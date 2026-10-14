import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/language_wave.dart';
import '../../widgets/ui/ui.dart';

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
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showLanguageChoice) ...[
                    const _LanguageChoice(),
                    const SizedBox(height: 32),
                  ],
                  Text(
                    l10n.onboardingTitle,
                    style: AppFonts.jakarta(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingSubtitle,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PermissionBenefit(
                    icon: HugeIcons.strokeRoundedNotification02,
                    title: l10n.onboardingNotificationsTitle,
                    description: l10n.onboardingNotificationsBody,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.onboardingOtherPermissionsNote,
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: l10n.onboardingEnableNotifications,
                    icon: HugeIcons.strokeRoundedNotification02,
                    loading: _isContinuing,
                    onPressed: () =>
                        _complete(requestNotificationPermission: true),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: l10n.onboardingNotNow,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.medium,
                    onPressed: _isContinuing
                        ? null
                        : () => _complete(requestNotificationPermission: false),
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

/// Two big tiles to pick the app language, each written in its own script.
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeProvider).languageCode;

    Widget option(Locale locale, String label) {
      final selected = current == locale.languageCode;
      return Expanded(
        child: Semantics(
          selected: selected,
          child: Pressable(
            onTap: () {
              if (selected) return;
              LanguageWave.run(
                context,
                () => ref.read(localeProvider.notifier).setLocale(locale),
              );
            },
            semanticLabel: label,
            haptic: true,
            color: selected ? AppColors.primarySoft : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.base),
              curve: AppMotion.standard,
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppColors.primaryDeep
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.fast),
                    child: selected
                        ? const HugeIcon(
                            key: ValueKey('on'),
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            size: 22,
                            color: AppColors.primary,
                          )
                        : Container(
                            key: const ValueKey('off'),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderStrong,
                                width: 1.5,
                              ),
                            ),
                          ),
                  ),
                ],
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.languageChooseSubtitle,
          style: AppFonts.jakarta(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
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
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: AppColors.primaryDeep,
                size: 22,
              ),
            ),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
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
