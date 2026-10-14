import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';

class VerifiedSellerBadge extends StatelessWidget {
  final bool compact;
  final bool showLabel;
  final bool showTickBackground;

  const VerifiedSellerBadge({
    super.key,
    this.compact = true,
    this.showLabel = true,
    this.showTickBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 14.0 : 16.0;
    final fontSize = compact ? 11.5 : 12.5;
    final vPad = compact ? 4.0 : 5.0;
    final hPad = compact ? 8.0 : 10.0;
    final plainIconSize = compact ? 20.0 : 22.0;

    const tick = HugeIcons.strokeRoundedCheckmarkBadge01;

    if (!showLabel && !showTickBackground) {
      return HugeIcon(
        icon: tick,
        size: plainIconSize,
        color: AppColors.primary,
      );
    }

    if (!showLabel && showTickBackground) {
      return Container(
        width: compact ? 40 : 44,
        height: compact ? 28 : 30,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Center(
          child: HugeIcon(
            icon: tick,
            size: plainIconSize,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: tick, size: iconSize, color: AppColors.primary),
          if (showLabel) ...[
            SizedBox(width: compact ? 4 : 6),
            Text(
              context.l10n.productVerifiedSeller,
              style: AppFonts.jakarta(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
