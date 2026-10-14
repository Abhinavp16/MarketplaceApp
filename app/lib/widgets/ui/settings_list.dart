import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'pressable.dart';

/// A titled white card holding [SettingsTile]s separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title!.toUpperCase(), style: AppText.eyebrow()),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 64),
                    child: Divider(height: 1),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in a [SettingsGroup]: icon in a soft circle, title, subtitle,
/// optional trailing widget and a chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.error : AppColors.textPrimary;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      borderRadius: BorderRadius.zero,
      semanticLabel: title,
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
                  color: destructive ? AppColors.errorSoft : AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: destructive
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 20,
                    color: destructive ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppFonts.jakarta(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Square shortcut tile (Orders, Wishlist...) with an optional count.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  /// Tints the tile teal (e.g. for the one action that matters most).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      color: highlight ? AppColors.primarySoft : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: highlight ? AppColors.primarySoft : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 22,
                  color: highlight ? AppColors.primaryDeep : AppColors.primary,
                ),
                const Spacer(),
                if ((count ?? 0) > 0)
                  Text(
                    '$count',
                    style: AppText.price(
                      fontSize: 15,
                      color: highlight ? AppColors.primaryDeep : AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primaryDeep : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
