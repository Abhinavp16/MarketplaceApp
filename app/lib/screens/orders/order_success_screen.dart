import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';
import 'order_parts.dart';

class OrderSuccessScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, this.orderId = 'AG-12345'});

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> {
  /// The order's own number (e.g. "LA-2024-0012"), once loaded.
  String? _orderNumber;
  bool _loadingNumber = false;

  String get _orderId => widget.orderId.trim();

  @override
  void initState() {
    super.initState();
    _loadOrderNumber();
  }

  /// The route carries the order's id; show its real number when the order
  /// can be read, otherwise the id itself.
  Future<void> _loadOrderNumber() async {
    if (_orderId.isEmpty) return;
    setState(() => _loadingNumber = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get('/orders/${Uri.encodeComponent(_orderId)}');
      final data = response.data is Map ? response.data['data'] : null;
      final number = data is Map
          ? data['orderNumber']?.toString().trim()
          : null;
      if (!mounted) return;
      setState(() {
        _orderNumber = (number == null || number.isEmpty) ? null : number;
        _loadingNumber = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNumber = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shownNumber = _orderNumber ?? _orderId;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            children: [
              const Spacer(),
              const OrderSuccessBadge(size: 84),
              const SizedBox(height: 8),
              Text(
                l10n.orderSuccessTitle,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.orderSuccessMessage,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Order Details Card
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Column(
                  children: [
                    if (_orderId.isNotEmpty) ...[
                      _buildDetailRow(
                        l10n.orderIdLabel,
                        child: AnimatedSwitcher(
                          duration: AppMotion.of(context, AppMotion.base),
                          child: _loadingNumber
                              ? const SkeletonShimmer(
                                  key: ValueKey('loading'),
                                  child: Skeleton(width: 110, height: 14),
                                )
                              : Text(
                                  '#$shownNumber',
                                  key: ValueKey(shownNumber),
                                  textAlign: TextAlign.end,
                                  style: AppText.price(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    _buildDetailRow(
                      l10n.commonStatus,
                      child: StatusChip(
                        label: l10n.orderSuccessPaymentPending,
                        tone: ChipTone.warning,
                        icon: HugeIcons.strokeRoundedClock01,
                      ),
                    ),
                    const Divider(height: 1),
                    _buildDetailRow(
                      l10n.ordersDelivery,
                      child: Text(
                        l10n.orderSuccessDeliveryNote,
                        textAlign: TextAlign.end,
                        style: AppFonts.jakarta(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Action Buttons
              AppButton(
                label: l10n.ordersTrackOrder,
                icon: HugeIcons.strokeRoundedDeliveryTruck01,
                onPressed: () => context.push('/tracking/${widget.orderId}'),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l10n.checkoutContinueShopping,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: AppFonts.jakarta(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}
