import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';
import '../../widgets/language_picker_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final l10n = context.l10n;
    final isHindi = ref.watch(localeProvider).languageCode == 'hi';
    final profileName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : l10n.profileAccountFallback;
    final status = _accountStatus(context, user);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.textPrimary,
            size: 24,
          ),
          tooltip: l10n.commonBack,
        ),
        title: Text(
          l10n.profileTitle,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.push('/edit-profile'),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedPencilEdit01,
              color: AppColors.textPrimary,
              size: 22,
            ),
            tooltip: l10n.profileEditProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                children: [
                  _Avatar(user: user, name: profileName),
                  const SizedBox(height: 16),
                  Text(
                    profileName,
                    textAlign: TextAlign.center,
                    style: AppFonts.jakarta(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if ((user?.phone?.trim().isNotEmpty ?? false) ||
                      (user?.email.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Text(
                      user?.phone?.trim().isNotEmpty == true
                          ? user!.phone!.trim()
                          : user?.email.trim() ?? '',
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _StatusBadge(status: status),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Section(
              title: l10n.profileSectionAccount,
              children: [
                _MenuItem(
                  icon: HugeIcons.strokeRoundedUserEdit01,
                  title: l10n.profileEditProfile,
                  subtitle: l10n.profileEditProfileSubtitle,
                  onTap: () => context.push('/edit-profile'),
                ),
                _MenuItem(
                  icon: HugeIcons.strokeRoundedLocation01,
                  title: l10n.profileAddresses,
                  subtitle: l10n.profileAddressesSubtitle,
                  onTap: () => context.push('/addresses'),
                ),
                if (user?.businessInfo?.verified != true)
                  _MenuItem(
                    icon: HugeIcons.strokeRoundedStore01,
                    title: _wholesalerActionTitle(context, user),
                    subtitle: _wholesalerActionSubtitle(context, user),
                    onTap: () => context.push('/convert-to-wholesaler'),
                  ),
                _MenuItem(
                  icon: HugeIcons.strokeRoundedTranslate,
                  // Always show "भाषा" so Hindi readers can find it in English mode.
                  title: isHindi
                      ? l10n.languageTitle
                      : '${l10n.languageTitle} / भाषा',
                  subtitle: isHindi ? l10n.languageHindi : l10n.languageEnglish,
                  onTap: () => showLanguagePicker(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Section(
              title: l10n.profileSectionActivity,
              children: [
                _MenuItem(
                  icon: HugeIcons.strokeRoundedShoppingBag01,
                  title: l10n.profilePreviousOrders,
                  subtitle: l10n.profilePreviousOrdersSubtitle,
                  onTap: () => context.push('/previous-orders'),
                ),
                _MenuItem(
                  icon: HugeIcons.strokeRoundedHandGrip,
                  title: l10n.profileNegotiations,
                  subtitle: l10n.profileNegotiationsSubtitle,
                  onTap: () => context.push('/negotiations'),
                ),
                if (user?.isWholesaler == true)
                  _MenuItem(
                    icon: HugeIcons.strokeRoundedPackage,
                    title: l10n.profileAddProduct,
                    subtitle: l10n.profileAddProductSubtitle,
                    onTap: () => context.push('/add-product'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Show View Customer App only for wholesalers
            if (user?.isWholesaler == true)
              _Section(
                title: l10n.profileSectionWholesale,
                children: [
                  _MenuItem(
                    icon: HugeIcons.strokeRoundedShoppingCart01,
                    title: l10n.profileViewCustomerApp,
                    subtitle: l10n.profileViewCustomerAppSubtitle,
                    onTap: () async {
                      ref.read(guestModeProvider.notifier).enableGuestMode();
                      try {
                        await context.push('/guest-app-preview');
                      } finally {
                        await Future<void>.delayed(Duration.zero);
                        ref.read(guestModeProvider.notifier).disableGuestMode();
                      }
                    },
                  ),
                ],
              ),
            const SizedBox(height: 8),
            _Section(
              title: l10n.profileSectionSupportLegal,
              children: [
                _MenuItem(
                  icon: HugeIcons.strokeRoundedHelpCircle,
                  title: l10n.profileHelpSupport,
                  subtitle: l10n.profileHelpSupportSubtitle,
                  onTap: () => context.push('/help'),
                ),
                _MenuItem(
                  icon: HugeIcons.strokeRoundedShield01,
                  title: l10n.legalPrivacyPolicy,
                  subtitle: l10n.profilePrivacySubtitle,
                  onTap: () => context.push('/legal/privacy-policy'),
                ),
                _MenuItem(
                  icon: HugeIcons.strokeRoundedFile01,
                  title: l10n.legalTermsConditions,
                  subtitle: l10n.profileTermsSubtitle,
                  onTap: () => context.push('/legal/terms-conditions'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              child: _MenuItem(
                icon: HugeIcons.strokeRoundedLogout01,
                title: l10n.profileSignOut,
                subtitle: l10n.profileSignOutSubtitle,
                iconColor: AppColors.error,
                titleColor: AppColors.error,
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  _ProfileStatus _accountStatus(BuildContext context, UserModel? user) {
    final l10n = context.l10n;
    final businessInfo = user?.businessInfo;
    if (user?.isWholesaler == true && businessInfo?.verified == true) {
      return _ProfileStatus(
        label: l10n.profileStatusVerifiedWholesaler,
        color: AppColors.success,
        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
      );
    }
    if (businessInfo?.status == 'pending') {
      return _ProfileStatus(
        label: l10n.profileStatusApplicationPending,
        color: Color(0xFFD97706),
        icon: HugeIcons.strokeRoundedTime02,
      );
    }
    if (businessInfo?.status == 'rejected') {
      return _ProfileStatus(
        label: l10n.profileStatusApplicationRejected,
        color: AppColors.error,
        icon: HugeIcons.strokeRoundedAlert02,
      );
    }
    if (user?.isWholesaler == true) {
      return _ProfileStatus(
        label: l10n.profileStatusVerificationRequired,
        color: Color(0xFFD97706),
        icon: HugeIcons.strokeRoundedAlert02,
      );
    }
    return _ProfileStatus(
      label: l10n.profileStatusCustomer,
      color: AppColors.primary,
      icon: HugeIcons.strokeRoundedUser,
    );
  }

  String _wholesalerActionTitle(BuildContext context, UserModel? user) {
    final l10n = context.l10n;
    if (user?.businessInfo?.status == 'pending') {
      return l10n.profileWholesalerApplication;
    }
    return user?.isWholesaler == true
        ? l10n.profileCompleteWholesalerVerification
        : l10n.profileBecomeWholesaler;
  }

  String _wholesalerActionSubtitle(BuildContext context, UserModel? user) {
    final l10n = context.l10n;
    if (user?.businessInfo?.status == 'pending') {
      return l10n.profileViewApplicationStatus;
    }
    return user?.isWholesaler == true
        ? l10n.profileSubmitBusinessProof
        : l10n.profileSubmitBusinessDetails;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.name});

  final UserModel? user;
  final String name;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatar?.trim() ?? '';
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.primary, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Initials(name: name),
            )
          : _Initials(name: name),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0]).join().toUpperCase();
    return Center(
      child: Text(
        initials.isEmpty ? 'A' : initials,
        style: AppFonts.jakarta(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ProfileStatus {
  const _ProfileStatus({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _ProfileStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: status.icon, size: 15, color: status.color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: AppFonts.jakarta(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: AppFonts.jakarta(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: effectiveIconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.gray400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
