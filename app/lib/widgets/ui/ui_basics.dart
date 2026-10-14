import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import 'app_button.dart';

/// Tone of a status chip. Semantic colours are separate from the brand accent.
enum ChipTone { brand, success, info, warning, error, neutral, accent }

(Color, Color) _toneColors(ChipTone tone) => switch (tone) {
  ChipTone.brand => (AppColors.primarySoft, AppColors.primaryDeep),
  ChipTone.success => (AppColors.successSoft, AppColors.primaryDeep),
  ChipTone.info => (AppColors.infoSoft, AppColors.secondary),
  ChipTone.warning => (AppColors.warningSoft, AppColors.warning),
  ChipTone.error => (AppColors.errorSoft, AppColors.error),
  ChipTone.neutral => (AppColors.gray100, AppColors.textSecondary),
  ChipTone.accent => (AppColors.accentSoft, AppColors.accent),
};

/// Small pill that states something's status ("Shipped", "New price").
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _toneColors(tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon!, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional subtitle and "See all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 8, 0),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(44, 40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Friendly empty / error state: icon in a soft circle, title, message and an
/// optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = ChipTone.brand,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ChipTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _toneColors(tone);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 20 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Center(
                child: HugeIcon(icon: icon, size: compact ? 28 : 36, color: fg),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grey shimmering placeholder block.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps skeleton blocks in one shared shimmer (static when motion is reduced).
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return Shimmer.fromColors(
      baseColor: AppColors.gray100,
      highlightColor: AppColors.gray50,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Placeholder shaped like a [ProductCard].
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: const SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Skeleton(height: double.infinity, radius: AppRadius.md),
            ),
            SizedBox(height: 10),
            Skeleton(width: 56, height: 10),
            SizedBox(height: 8),
            Skeleton(height: 12),
            SizedBox(height: 6),
            Skeleton(width: 90, height: 12),
            Spacer(),
            Row(
              children: [
                Skeleton(width: 60, height: 16),
                Spacer(),
                Skeleton(width: 54, height: 30, radius: AppRadius.sm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Price with optional unit, struck-through MRP and "% off".
class PriceView extends StatelessWidget {
  const PriceView({
    super.key,
    required this.price,
    this.mrp,
    this.unit,
    this.size = 16,
    this.color = AppColors.textPrimary,
    this.offLabel,
    this.wrap = true,
  });

  final num price;
  final num? mrp;

  /// Suffix after the price, e.g. "/m" or "/pc".
  final String? unit;
  final double size;
  final Color color;

  /// Localised "{percent}% OFF" builder; the discount is hidden without it.
  final String Function(int percent)? offLabel;
  final bool wrap;

  int get _percent {
    final m = mrp;
    if (m == null || m <= 0 || m <= price) return 0;
    return (((m - price) / m) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final percent = _percent;
    final main = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '₹${NumberFormatter.formatPrice(price)}',
            style: AppText.price(fontSize: size, color: color),
          ),
          if (unit != null && unit!.isNotEmpty)
            TextSpan(
              text: unit,
              style: AppFonts.jakarta(
                fontSize: (size * 0.72).clamp(11, 14).toDouble(),
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final extras = <Widget>[
      if (percent > 0)
        Text(
          '₹${NumberFormatter.formatPrice(mrp)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.mrp(fontSize: (size * 0.72).clamp(11, 13).toDouble()),
        ),
      if (percent > 0 && offLabel != null)
        Text(
          offLabel!(percent),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.jakarta(
            fontSize: (size * 0.72).clamp(11, 13).toDouble(),
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
    ];
    if (!wrap) {
      // One line: the price stays whole, the MRP / discount shorten instead.
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          main,
          for (final e in extras) ...[
            const SizedBox(width: 6),
            Flexible(child: e),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [main, ...extras],
    );
  }
}

/// One tidy row inside a bill / summary card.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.jakarta(
                fontSize: emphasize ? 16 : 14,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                color:
                    labelColor ??
                    (emphasize
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
              ),
            ),
          ),
          Text(
            value,
            style: AppText.price(
              fontSize: emphasize ? 18 : 14,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// White card with the standard hairline border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color = AppColors.surfaceLight,
    this.radius = AppRadius.lg,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
