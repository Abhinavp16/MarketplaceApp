import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

class LegalPolicyItem {
  final String id;
  final String title;
  final String assetPath;
  final IconData icon;
  final Color color;

  const LegalPolicyItem({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.icon,
    required this.color,
  });

  /// Policy name in the current language. The policy text itself stays English.
  String localizedTitle(BuildContext context) {
    final l10n = context.l10n;
    switch (id) {
      case 'privacy-policy':
        return l10n.legalPrivacyPolicy;
      case 'terms-conditions':
        return l10n.legalTermsConditions;
      case 'shipping-policy':
        return l10n.legalShippingPolicy;
      case 'refund-return-policy':
        return l10n.legalRefundReturnPolicy;
      case 'cancellation-policy':
        return l10n.legalCancellationPolicy;
      case 'cod-delivery-policy':
        return l10n.legalCodDeliveryPolicy;
      case 'dealer-agreement':
        return l10n.legalDealerAgreement;
      case 'dealer-pricing-map-policy':
        return l10n.legalDealerPricingPolicy;
      case 'warranty-policy':
        return l10n.legalWarrantyPolicy;
      case 'comprehensive-legal-policies':
        return l10n.legalComprehensivePolicies;
      default:
        return title;
    }
  }
}

class LegalPolicyCatalog {
  static const List<LegalPolicyItem> items = [
    LegalPolicyItem(
      id: 'privacy-policy',
      title: 'Privacy Policy',
      assetPath: 'assets/legal/demo_privacy_policy.txt',
      icon: HugeIcons.strokeRoundedShield01,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'terms-conditions',
      title: 'Terms & Conditions',
      assetPath: 'assets/legal/demo_terms_of_service.txt',
      icon: HugeIcons.strokeRoundedFile01,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'shipping-policy',
      title: 'Shipping Policy',
      // This file is the "Shipping and COD Policy".
      assetPath: 'assets/legal/demo_cod_delivery_policy.txt',
      icon: HugeIcons.strokeRoundedDeliveryBox01,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'refund-return-policy',
      title: 'Refund & Return Policy',
      assetPath: 'assets/legal/demo_return_refund_policy.txt',
      icon: HugeIcons.strokeRoundedRefresh,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'cancellation-policy',
      title: 'Cancellation Policy',
      // No separate cancellation text exists; cancellations, returns and
      // refunds are covered by the refund & return policy.
      assetPath: 'assets/legal/demo_return_refund_policy.txt',
      icon: HugeIcons.strokeRoundedCancel01,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'cod-delivery-policy',
      title: 'COD Delivery Policy',
      assetPath: 'assets/legal/demo_cod_delivery_policy.txt',
      icon: HugeIcons.strokeRoundedDeliveryBox01,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'dealer-agreement',
      title: 'Dealer Agreement',
      assetPath: 'assets/legal/demo_dealer_agreement.txt',
      icon: HugeIcons.strokeRoundedUserGroup,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'dealer-pricing-map-policy',
      title: 'Dealer Pricing Policy',
      assetPath: 'assets/legal/demo_dealer_pricing_policy.txt',
      icon: HugeIcons.strokeRoundedChartLineData01,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'warranty-policy',
      title: 'Warranty Policy',
      assetPath: 'assets/legal/demo_warranty_policy.txt',
      icon: HugeIcons.strokeRoundedShield02,
      color: AppColors.primary,
    ),
    LegalPolicyItem(
      id: 'comprehensive-legal-policies',
      title: 'Comprehensive Legal Policies',
      assetPath: 'assets/legal/demo_comprehensive_policies.txt',
      icon: HugeIcons.strokeRoundedLegal01,
      color: AppColors.primary,
    ),
  ];

  static LegalPolicyItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class LegalPolicyScreen extends StatelessWidget {
  final String policyId;
  const LegalPolicyScreen({super.key, required this.policyId});

  @override
  Widget build(BuildContext context) {
    final item = LegalPolicyCatalog.byId(policyId);
    if (item == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(title: context.l10n.legalHubTitle),
        body: EmptyState(
          icon: HugeIcons.strokeRoundedLegal01,
          tone: ChipTone.neutral,
          title: context.l10n.legalNotFound,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: item.localizedTitle(context)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(item.assetPath),
        builder: (context, snapshot) {
          final Widget child;
          if (snapshot.connectionState != ConnectionState.done) {
            child = const _PolicySkeleton(key: ValueKey('loading'));
          } else if (snapshot.hasError) {
            child = EmptyState(
              key: const ValueKey('error'),
              icon: HugeIcons.strokeRoundedAlert02,
              tone: ChipTone.error,
              title: context.l10n.legalLoadFailed,
            );
          } else {
            final content = snapshot.data ?? '';
            final blocks = _parsePolicyBlocks(content);
            child = SingleChildScrollView(
              key: const ValueKey('content'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context, item),
                  if (context.isHindi) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.legalEnglishOnlyNote,
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: blocks.map(_buildBlock).toList(),
                    ),
                  ),
                ],
              ),
            );
          }
          return AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.base),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, LegalPolicyItem item) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: item.icon,
                color: AppColors.primaryDeep,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.localizedTitle(context),
              style: AppFonts.jakarta(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: context.l10n.legalPolicyBadge,
            tone: ChipTone.neutral,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(_PolicyBlock block) {
    switch (block.type) {
      case _PolicyBlockType.section:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            block.text,
            style: AppFonts.jakarta(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        );
      case _PolicyBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9, left: 2, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  block.text,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      case _PolicyBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            block.text,
            style: AppFonts.jakarta(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        );
      case _PolicyBlockType.spacer:
        return const SizedBox(height: 4);
    }
  }

  List<_PolicyBlock> _parsePolicyBlocks(String raw) {
    var lines = raw.replaceAll('\r\n', '\n').split('\n');
    lines = lines.map((e) => e.trim()).toList();

    final blocks = <_PolicyBlock>[];
    String? prevNormalized;

    for (final line in lines) {
      if (line.isEmpty) {
        if (blocks.isNotEmpty && blocks.last.type != _PolicyBlockType.spacer) {
          blocks.add(const _PolicyBlock(_PolicyBlockType.spacer, ''));
        }
        continue;
      }

      final normalized = line
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (normalized.isNotEmpty && normalized == prevNormalized) {
        continue;
      }
      prevNormalized = normalized;

      if (_isSectionTitle(line)) {
        blocks.add(
          _PolicyBlock(_PolicyBlockType.section, _normalizeTitle(line)),
        );
        continue;
      }

      if (_isBullet(line)) {
        blocks.add(
          _PolicyBlock(
            _PolicyBlockType.bullet,
            line.replaceFirst(RegExp(r'^[\u2022\-\*]\s*'), ''),
          ),
        );
        continue;
      }

      blocks.add(_PolicyBlock(_PolicyBlockType.paragraph, line));
    }

    while (blocks.isNotEmpty && blocks.last.type == _PolicyBlockType.spacer) {
      blocks.removeLast();
    }
    return blocks;
  }

  bool _isBullet(String line) {
    return RegExp(r'^[\u2022\-\*]\s+').hasMatch(line);
  }

  bool _isSectionTitle(String line) {
    if (line.endsWith(':')) return true;
    final hasLetters = RegExp(r'[A-Za-z]').hasMatch(line);
    if (!hasLetters) return false;
    final isUpper = line == line.toUpperCase();
    return isUpper && line.length <= 80;
  }

  String _normalizeTitle(String line) {
    final cleaned = line.replaceAll(':', '').trim();
    if (cleaned == cleaned.toUpperCase()) {
      return cleaned
          .toLowerCase()
          .split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }
    return cleaned;
  }
}

enum _PolicyBlockType { section, paragraph, bullet, spacer }

class _PolicyBlock {
  final _PolicyBlockType type;
  final String text;
  const _PolicyBlock(this.type, this.text);
}

class _PolicySkeleton extends StatelessWidget {
  const _PolicySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 68, radius: AppRadius.lg),
            SizedBox(height: 16),
            Skeleton(width: 180, height: 16),
            SizedBox(height: 12),
            Skeleton(height: 12),
            SizedBox(height: 8),
            Skeleton(height: 12),
            SizedBox(height: 8),
            Skeleton(width: 240, height: 12),
            SizedBox(height: 20),
            Skeleton(width: 150, height: 16),
            SizedBox(height: 12),
            Skeleton(height: 12),
            SizedBox(height: 8),
            Skeleton(width: 200, height: 12),
          ],
        ),
      ),
    );
  }
}
