import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import '../l10n/l10n.dart';

/// Shown to wholesalers under the price when sending a requirement: delivery
/// is set by DemoMart when the order is confirmed.
class DeliveryNote extends StatelessWidget {
  const DeliveryNote({super.key, this.color = const Color(0xFF64748B)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('delivery-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.local_shipping_outlined, size: 15, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.l10n.dealDeliveryNote,
            style: AppFonts.jakarta(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
