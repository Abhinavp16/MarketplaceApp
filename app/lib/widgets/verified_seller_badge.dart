import 'package:flutter/material.dart';
import '../core/theme/app_fonts.dart';
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
    final iconSize = compact ? 12.0 : 14.0;
    final fontSize = compact ? 11.0 : 12.5;
    final vPad = compact ? 4.0 : 5.5;
    final hPad = compact ? 9.0 : 11.0;
    final plainIconSize = compact ? 22.0 : 24.0;

    if (!showLabel && !showTickBackground) {
      return Icon(
        Icons.verified_rounded,
        size: plainIconSize,
        color: const Color(0xFF3B82F6),
      );
    }

    if (!showLabel && showTickBackground) {
      return Container(
        width: compact ? 40 : 44,
        height: compact ? 28 : 30,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.verified_rounded,
          size: plainIconSize,
          color: const Color(0xFF3B82F6),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 18 : 20,
            height: compact ? 18 : 20,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              size: iconSize,
              color: Colors.white,
            ),
          ),
          if (showLabel) ...[
            SizedBox(width: compact ? 6 : 7),
            Text(
              context.l10n.productVerifiedSeller,
              style: AppFonts.jakarta(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A8A),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
