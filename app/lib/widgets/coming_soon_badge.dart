import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import '../l10n/l10n.dart';

const comingSoonColor = Color(0xFF0284C7);

/// Blue "Coming Soon" pill for product cards and the product page.
class ComingSoonBadge extends StatelessWidget {
  const ComingSoonBadge({
    super.key,
    this.fontSize = 9,
    this.uppercase = true,
    this.compact = false,
  });

  final double fontSize;
  final bool uppercase;
  // Product cards: same size as the SALE / HOT badges, no icon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.comingSoonBadge;
    return Container(
      key: const ValueKey('coming-soon-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: comingSoonColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(
              Icons.schedule_rounded,
              size: fontSize + 2,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            uppercase ? label.toUpperCase() : label,
            style: AppFonts.outfit(
              fontSize: compact ? 7.5 : fontSize,
              fontWeight: compact ? FontWeight.w800 : FontWeight.w700,
              color: Colors.white,
              letterSpacing: compact ? 0.5 : null,
            ),
          ),
        ],
      ),
    );
  }
}
