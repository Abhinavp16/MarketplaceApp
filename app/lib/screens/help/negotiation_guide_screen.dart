import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

class NegotiationGuideScreen extends StatelessWidget {
  const NegotiationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: l10n.guideTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        icon: HugeIcons.strokeRoundedAgreement02,
                        color: AppColors.primaryDeep,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.guideHeroTitle,
                    style: AppFonts.jakarta(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.guideHeroSubtitle,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.guideHowItWorksTitle,
              style: AppFonts.jakarta(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.guideHowItWorksBody,
              style: AppFonts.jakarta(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
              child: Column(
                children: [
                  _GuideStep(
                    number: '1',
                    icon: HugeIcons.strokeRoundedNote01,
                    title: l10n.guideStep1Title,
                    description: l10n.guideStep1Body,
                  ),
                  _GuideStep(
                    number: '2',
                    icon: HugeIcons.strokeRoundedExchange01,
                    title: l10n.guideStep2Title,
                    description: l10n.guideStep2Body,
                  ),
                  _GuideStep(
                    number: '3',
                    icon: HugeIcons.strokeRoundedInvoice01,
                    title: l10n.guideStep3Title,
                    description: l10n.guideStep3Body,
                  ),
                  _GuideStep(
                    number: '4',
                    icon: HugeIcons.strokeRoundedShield01,
                    title: l10n.guideStep4Title,
                    description: l10n.guideStep4Body,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.primarySoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedIdea01,
                    color: AppColors.primaryDeep,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.guideTip,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: l10n.guideViewNegotiations,
              icon: HugeIcons.strokeRoundedAgreement02,
              onPressed: () => context.go('/negotiations'),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: l10n.guideContactSupport,
              icon: HugeIcons.strokeRoundedCustomerSupport,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push('/help'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: AppText.price(
                      fontSize: 14,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(icon: icon, color: AppColors.textTertiary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
