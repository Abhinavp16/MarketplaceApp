import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

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
      color: Color(0xFF0891B2),
    ),
    LegalPolicyItem(
      id: 'terms-conditions',
      title: 'Terms & Conditions',
      assetPath: 'assets/legal/demo_terms_of_service.txt',
      icon: HugeIcons.strokeRoundedFile01,
      color: Color(0xFF0EA5E9),
    ),
    LegalPolicyItem(
      id: 'shipping-policy',
      title: 'Shipping Policy',
      assetPath: 'assets/legal/demo_cod_delivery_policy.txt',
      icon: HugeIcons.strokeRoundedDeliveryBox01,
      color: Color(0xFF0F766E),
    ),
    LegalPolicyItem(
      id: 'refund-return-policy',
      title: 'Refund & Return Policy',
      assetPath: 'assets/legal/demo_return_refund_policy.txt',
      icon: HugeIcons.strokeRoundedRefresh,
      color: Color(0xFF7C3AED),
    ),
    LegalPolicyItem(
      id: 'cancellation-policy',
      title: 'Cancellation Policy',
      assetPath: 'assets/legal/demo_comprehensive_policies.txt',
      icon: HugeIcons.strokeRoundedCancel01,
      color: Color(0xFFDC2626),
    ),
    LegalPolicyItem(
      id: 'cod-delivery-policy',
      title: 'COD Delivery Policy',
      assetPath: 'assets/legal/demo_cod_delivery_policy.txt',
      icon: HugeIcons.strokeRoundedDeliveryBox01,
      color: Color(0xFF0F766E),
    ),
    LegalPolicyItem(
      id: 'dealer-agreement',
      title: 'Dealer Agreement',
      assetPath: 'assets/legal/demo_dealer_agreement.txt',
      icon: HugeIcons.strokeRoundedUserGroup,
      color: Color(0xFF059669),
    ),
    LegalPolicyItem(
      id: 'dealer-pricing-map-policy',
      title: 'Dealer Pricing Policy',
      assetPath: 'assets/legal/demo_dealer_pricing_policy.txt',
      icon: HugeIcons.strokeRoundedChartLineData01,
      color: Color(0xFFD97706),
    ),
    LegalPolicyItem(
      id: 'warranty-policy',
      title: 'Warranty Policy',
      assetPath: 'assets/legal/demo_warranty_policy.txt',
      icon: HugeIcons.strokeRoundedShield02,
      color: Color(0xFF4F46E5),
    ),
    LegalPolicyItem(
      id: 'comprehensive-legal-policies',
      title: 'Comprehensive Legal Policies',
      assetPath: 'assets/legal/demo_comprehensive_policies.txt',
      icon: HugeIcons.strokeRoundedLegal01,
      color: Color(0xFF4338CA),
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
        appBar: AppBar(title: Text(context.l10n.legalHubTitle)),
        body: Center(
          child: Text(
            context.l10n.legalNotFound,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.localizedTitle(context),
          style: AppFonts.jakarta(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(item.assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.l10n.legalLoadFailed,
                  style: AppFonts.jakarta(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          final content = snapshot.data ?? '';
          final blocks = _parsePolicyBlocks(content);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(context, item),
                if (context.isHindi) ...[
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.legalEnglishOnlyNote,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ...blocks.map((block) => _buildBlock(block, item.color)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, LegalPolicyItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: item.color.withValues(alpha: 0.2)),
            ),
            child: HugeIcon(icon: item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.localizedTitle(context),
              style: AppFonts.jakarta(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Text(
            context.l10n.legalPolicyBadge,
            style: AppFonts.jakarta(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(_PolicyBlock block, Color accent) {
    switch (block.type) {
      case _PolicyBlockType.section:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSparkles,
                color: accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.text,
                  style: AppFonts.jakarta(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      case _PolicyBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.text,
                  style: AppFonts.jakarta(
                    fontSize: 15,
                    height: 1.55,
                    color: const Color(0xFF1F2937),
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
              fontSize: 15,
              height: 1.65,
              color: const Color(0xFF1F2937),
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
        blocks.add(_PolicyBlock(_PolicyBlockType.section, _normalizeTitle(line)));
        continue;
      }

      if (_isBullet(line)) {
        blocks.add(
          _PolicyBlock(_PolicyBlockType.bullet, line.replaceFirst(RegExp(r'^[\u2022\-\*]\s*'), '')),
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
