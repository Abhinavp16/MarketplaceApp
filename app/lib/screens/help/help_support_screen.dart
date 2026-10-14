import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/brand_config.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const String _supportEmail = BrandConfig.supportEmail;

  int _expandedFaq = -1;
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  List<Map<String, String>> _faqs(AppLocalizations l10n) => [
    {'q': l10n.helpFaqBulkOrderQuestion, 'a': l10n.helpFaqBulkOrderAnswer},
    {'q': l10n.helpFaqPaymentQuestion, 'a': l10n.helpFaqPaymentAnswer},
    {'q': l10n.helpFaqDeliveryQuestion, 'a': l10n.helpFaqDeliveryAnswer},
    {'q': l10n.helpFaqTrackQuestion, 'a': l10n.helpFaqTrackAnswer},
    {'q': l10n.helpFaqReturnQuestion, 'a': l10n.helpFaqReturnAnswer},
    {'q': l10n.helpFaqNegotiationQuestion, 'a': l10n.helpFaqNegotiationAnswer},
    {'q': l10n.helpFaqWholesalerQuestion, 'a': l10n.helpFaqWholesalerAnswer},
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(title: context.l10n.helpSupportTitle),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 12),
              _buildQuickContactRow(),
              const SizedBox(height: 24),
              _buildFaqSection(),
              const SizedBox(height: 24),
              _buildContactCard(),
              const SizedBox(height: 24),
              _buildAppInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCustomerSupport,
                color: AppColors.primaryDeep,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.helpHeroTitle,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.helpHeroSubtitle,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactRow() {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: l10n.helpCallUs,
            icon: HugeIcons.strokeRoundedCall02,
            variant: AppButtonVariant.secondary,
            onPressed: () => _handleQuickAction('call'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: l10n.helpEmailUs,
            icon: HugeIcons.strokeRoundedMail01,
            variant: AppButtonVariant.secondary,
            onPressed: () => _handleQuickAction('email'),
          ),
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    final faqs = _faqs(context.l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.helpFaqTitle,
          padding: const EdgeInsets.only(left: 4, bottom: 12),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < faqs.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildFaqTile(faqs[i], i),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqTile(Map<String, String> faq, int index) {
    final isExpanded = _expandedFaq == index;
    final duration = AppMotion.of(context, AppMotion.base);
    return Pressable(
      onTap: () => setState(() => _expandedFaq = isExpanded ? -1 : index),
      scale: 0.99,
      borderRadius: BorderRadius.zero,
      semanticLabel: faq['q'],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    faq['q']!,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: duration,
                  curve: AppMotion.standard,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    color: isExpanded
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: duration,
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, right: 20),
                      child: Text(
                        faq['a']!,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.helpContactInfoTitle,
          subtitle: l10n.helpContactInfoSubtitle,
          padding: const EdgeInsets.only(left: 4, bottom: 12),
        ),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: HugeIcons.strokeRoundedMail01,
              title: l10n.helpEmailUs,
              subtitle: _supportEmail,
              onTap: () =>
                  _openContactLink(Uri(scheme: 'mailto', path: _supportEmail)),
            ),
            SettingsTile(
              icon: HugeIcons.strokeRoundedCall02,
              title: l10n.helpCallUs,
              subtitle: BrandConfig.supportPhone,
              onTap: () => _openContactLink(_phoneUri),
            ),
            _InfoRow(
              icon: HugeIcons.strokeRoundedClock01,
              title: l10n.helpWorkingHours,
              subtitle: l10n.helpWorkingHoursValue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppInfoCard() {
    return AppCard(
      color: AppColors.surfaceMuted,
      borderColor: AppColors.surfaceMuted,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(
                'assets/images/logo.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.helpBrandName,
              style: AppFonts.jakarta(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) => Text(
                snapshot.hasData
                    ? context.l10n.helpVersion(snapshot.data!.version)
                    : context.l10n.helpVersionLabel,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.helpAppTagline,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Uri get _phoneUri => Uri(
    scheme: 'tel',
    path: BrandConfig.supportPhone.replaceAll(RegExp(r'[^\d+]'), ''),
  );

  void _handleQuickAction(String action) {
    _openContactLink(
      action == 'call' ? _phoneUri : Uri(scheme: 'mailto', path: _supportEmail),
    );
  }

  /// Email / phone rows: opens the mail or dialer app. launchUrl is called
  /// directly (canLaunchUrl can report false on Android 11+ when the scheme
  /// isn't listed in the manifest's `queries`).
  Future<void> _openContactLink(Uri uri) async {
    try {
      await launchUrl(uri);
    } catch (_) {
      // No app to handle it; nothing else to do.
    }
  }
}

/// Non-tappable row styled like a SettingsTile (icon, title, subtitle).
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.jakarta(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
