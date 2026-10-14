import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/order_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/customer_order_presentation.dart';
import '../../core/utils/order_pagination.dart';
import '../../widgets/app_image.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/l10n.dart';
import 'order_parts.dart';

class PreviousOrdersScreen extends ConsumerStatefulWidget {
  const PreviousOrdersScreen({super.key});

  @override
  ConsumerState<PreviousOrdersScreen> createState() =>
      _PreviousOrdersScreenState();
}

class _PreviousOrdersScreenState extends ConsumerState<PreviousOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  final Set<String> _expanded = {};
  String? _sendingReceiptFor;

  /// Cards built in the first frame after loading fade in; later ones don't.
  bool _animateEntrance = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      final allOrders = <Map<String, dynamic>>[];
      var page = 1;
      var hasNext = true;
      // Backend clamps limit to 50; page through until the server says done.
      while (hasNext) {
        final response = await api.get(
          '/orders',
          queryParameters: {'page': page, 'limit': 50},
        );
        if (response.data['success'] != true) {
          throw StateError('Order request was unsuccessful');
        }

        final data = response.data['data'] as List<dynamic>? ?? [];
        allOrders.addAll(data.cast<Map<String, dynamic>>());
        hasNext = hasNextOrderPage(
          Map<String, dynamic>.from(response.data as Map),
        );
        page += 1;
      }
      if (!mounted) return;
      setState(() {
        _orders = allOrders;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateEntrance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  String _fmt(num? price) {
    return NumberFormatter.formatPrice((price ?? 0).round());
  }

  String _rupees(num? price) => context.l10n.commonRupees(_fmt(price));

  String _formatDate(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed == null) return '—';
    return DateFormat(
      'MMM dd, yyyy · hh:mm a',
      Localizations.localeOf(context).languageCode,
    ).format(parsed.toLocal());
  }

  String _statusLabel(String status) =>
      CustomerOrderPresentation.label(context.l10n, status);

  String _orderKey(Map<String, dynamic> order, int index) =>
      order['id']?.toString() ?? order['orderNumber']?.toString() ?? '$index';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: context.l10n.ordersTitle),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.exit,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return SkeletonShimmer(
        key: const ValueKey('loading'),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const OrderCardSkeleton(),
        ),
      );
    }

    final l10n = context.l10n;
    if (_loadFailed) {
      return EmptyState(
        key: const ValueKey('error'),
        icon: HugeIcons.strokeRoundedAlert02,
        tone: ChipTone.error,
        title: l10n.ordersLoadFailed,
        actionLabel: l10n.commonRetry,
        onAction: _fetchOrders,
      );
    }

    if (_orders.isEmpty) {
      return EmptyState(
        key: const ValueKey('empty'),
        icon: HugeIcons.strokeRoundedPackage,
        title: l10n.ordersEmpty,
        actionLabel: l10n.ordersStartShopping,
        onAction: () => context.go('/home'),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: _fetchOrders,
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _FadeSlideIn(
          animate: _animateEntrance && index < 6,
          child: _buildOrderCard(_orders[index], index),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final l10n = context.l10n;
    final fulfillmentStatus = order['status']?.toString() ?? '';
    final status = CustomerOrderPresentation.stage(order);
    final items = order['items'] as List<dynamic>? ?? [];
    final orderNumber = order['orderNumber']?.toString() ?? '';
    final orderType = order['orderType']?.toString() == 'wholesale'
        ? l10n.ordersTypeWholesale
        : l10n.ordersTypeRetail;
    final isNegotiated =
        order['negotiationId'] != null &&
        order['negotiationId'].toString().isNotEmpty;
    final key = _orderKey(order, index);
    final expanded = _expanded.contains(key);
    final duration = AppMotion.of(context, AppMotion.base);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: () => setState(() {
              if (!_expanded.remove(key)) _expanded.add(key);
            }),
            scale: 0.99,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            semanticLabel: orderNumber,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderNumber,
                              style: AppFonts.jakarta(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isNegotiated
                                  ? l10n.ordersCardSubtitleNegotiated(
                                      orderType,
                                      _formatDate(order['createdAt']),
                                    )
                                  : l10n.ordersCardSubtitle(
                                      orderType,
                                      _formatDate(order['createdAt']),
                                    ),
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _rupees(order['total'] as num?),
                            style: AppText.price(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.commonItemsCount(items.length),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                        label: _statusLabel(status),
                        tone: CustomerOrderPresentation.chipTone(status),
                        icon: CustomerOrderPresentation.hugeIcon(status),
                      ),
                      if (isNegotiated)
                        StatusChip(
                          label: l10n.ordersNegotiatedChip,
                          tone: ChipTone.neutral,
                          icon: HugeIcons.strokeRoundedAgreement01,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OrderProgressBar(
                    value: CustomerOrderPresentation.progress(order),
                    color: CustomerOrderPresentation.toneColor(status),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ItemThumbs(items: items),
                      const Spacer(),
                      Text(
                        expanded ? l10n.ordHideDetails : l10n.commonViewDetails,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: duration,
                        curve: AppMotion.standard,
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      _buildItems(items),
                      const Divider(height: 1),
                      _buildPriceBreakdown(order),
                      _buildShippingAddress(order),
                      _buildTrackingDetails(order),
                      _buildRejectionDetails(order),
                      _buildStatusHistory(order),
                      _buildActions(order, fulfillmentStatus, key),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(List<dynamic> items) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: items.map<Widget>((rawItem) {
          final item = rawItem as Map<String, dynamic>;
          final image = item['image']?.toString();
          final quantity = item['quantity'] as num? ?? 1;
          final price = item['pricePerUnit'] as num? ?? 0;
          final totalPrice = item['totalPrice'] as num? ?? quantity * price;
          final mrpPerUnit = item['mrpPerUnit'] as num?;
          final discountPercent = item['discountPercent'] as num?;
          final hasCatalogDiscount =
              discountPercent != null &&
              discountPercent > 0 &&
              mrpPerUnit != null &&
              mrpPerUnit > price;
          final name = localizedName(
            context,
            item,
            fallback: l10n.ordersProductFallback,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(image: image, name: name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.ordersItemQtyPrice(
                          NumberFormatter.formatPrice(quantity),
                          _fmt(price),
                        ),
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (hasCatalogDiscount) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          children: [
                            Text(
                              l10n.ordersMrpValue(_fmt(mrpPerUnit)),
                              style: AppText.mrp(fontSize: 11),
                            ),
                            Text(
                              l10n.commonPercentOff(
                                '${discountPercent % 1 == 0 ? discountPercent.toInt() : discountPercent}',
                              ),
                              style: AppFonts.jakarta(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _rupees(totalPrice),
                  style: AppText.price(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceBreakdown(Map<String, dynamic> order) {
    final subtotal = order['subtotal'] as num? ?? order['total'] as num? ?? 0;
    final delivery = order['deliveryFee'] as num? ?? 0;
    final discount = order['discount'] as num? ?? 0;
    final l10n = context.l10n;
    // Delivery is added by DemoMart when it accepts the order.
    final awaitingAcceptance =
        order['acceptanceStatus']?.toString().toLowerCase() == 'pending';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          SummaryRow(label: l10n.commonSubtotal, value: _rupees(subtotal)),
          SummaryRow(
            label: l10n.ordersDelivery,
            value: awaitingAcceptance && delivery == 0
                ? l10n.dealDeliveryOnConfirmation
                : delivery == 0
                ? l10n.ordersFree
                : _rupees(delivery),
          ),
          if (discount > 0)
            SummaryRow(
              label: l10n.cartDiscount,
              value: l10n.cartMinusRupees(_fmt(discount)),
              valueColor: AppColors.primary,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          SummaryRow(
            label: awaitingAcceptance
                ? l10n.dealEstimatedTotal
                : l10n.cartGrandTotal,
            value: _rupees(order['total'] as num?),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddress(Map<String, dynamic> order) {
    final rawAddress = order['shippingAddress'];
    if (rawAddress is! Map) return const SizedBox.shrink();
    final address = Map<String, dynamic>.from(rawAddress);
    final state = address['state']?.toString() ?? '';
    final addressLines = [
      address['addressLine1'],
      address['addressLine2'],
      [
            address['city'],
            state.isEmpty ? null : localizedStateName(context, state),
          ]
          .where((value) => value != null && value.toString().isNotEmpty)
          .join(', '),
      address['pincode'],
    ].where((value) => value != null && value.toString().trim().isNotEmpty);

    return _infoSection(
      icon: HugeIcons.strokeRoundedLocation01,
      title: context.l10n.checkoutShippingAddress,
      children: [
        Text(
          address['fullName']?.toString() ?? '',
          style: AppFonts.jakarta(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          addressLines.join('\n'),
          style: AppFonts.jakarta(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        if (address['phone']?.toString().isNotEmpty == true) ...[
          const SizedBox(height: 3),
          Text(address['phone'].toString(), style: _infoTextStyle()),
        ],
      ],
    );
  }

  Widget _buildTrackingDetails(Map<String, dynamic> order) {
    final tracking = order['trackingNumber']?.toString();
    final courier = order['courierName']?.toString();
    if ((tracking == null || tracking.isEmpty) &&
        (courier == null || courier.isEmpty)) {
      return const SizedBox.shrink();
    }

    return _infoSection(
      icon: HugeIcons.strokeRoundedDeliveryTruck01,
      title: context.l10n.ordersDeliveryDetails,
      children: [
        if (courier != null && courier.isNotEmpty)
          Text(
            context.l10n.ordersCourierValue(courier),
            style: _infoTextStyle(),
          ),
        if (tracking != null && tracking.isNotEmpty)
          Text(
            context.l10n.ordersTrackingValue(tracking),
            style: _infoTextStyle(),
          ),
      ],
    );
  }

  Widget _buildRejectionDetails(Map<String, dynamic> order) {
    if (CustomerOrderPresentation.acceptanceStatus(order) != 'rejected') {
      return const SizedBox.shrink();
    }
    final reason = order['rejectionReason']?.toString().trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: OrderInfoPanel(
        title: context.l10n.ordersRejectedTitle,
        message: reason == null || reason.isEmpty
            ? context.l10n.ordersRejectedNoReason
            : reason,
        tone: ChipTone.error,
        icon: HugeIcons.strokeRoundedCancelCircle,
      ),
    );
  }

  Widget _buildStatusHistory(Map<String, dynamic> order) {
    final history = order['statusHistory'] as List<dynamic>? ?? [];
    if (history.isEmpty) return const SizedBox.shrink();

    return _infoSection(
      icon: HugeIcons.strokeRoundedWorkHistory,
      title: context.l10n.ordersStatusHistory,
      children: history.reversed.map<Widget>((raw) {
        final entry = raw as Map;
        final status = entry['status']?.toString() ?? '';
        final note = entry['note']?.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5, right: 10),
                decoration: BoxDecoration(
                  color: CustomerOrderPresentation.toneColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(status),
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        _formatDate(entry['timestamp']),
                        if (note != null && note.isNotEmpty) note,
                      ].join(' · '),
                      style: _infoTextStyle(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  TextStyle _infoTextStyle() {
    return AppFonts.jakarta(fontSize: 12, color: AppColors.textSecondary);
  }

  Widget _infoSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Future<void> _sendReceipt(Map<String, dynamic> order, String key) async {
    if (_sendingReceiptFor != null) return;
    setState(() => _sendingReceiptFor = key);
    final api = ref.read(apiClientProvider);
    try {
      // The order has `id`, not the checkout's `orderId`; wrap it the way the
      // checkout response looks so the same PDF / share flow works.
      await OrderCheckoutActionsSheet.handleSuccessfulCheckout(
        context: context,
        apiClient: api,
        responseData: OrderExportService.receiptResponseFromOrder(order),
      );
    } finally {
      if (mounted) setState(() => _sendingReceiptFor = null);
    }
  }

  Widget _buildActions(Map<String, dynamic> order, String status, String key) {
    final orderId = order['id']?.toString() ?? '';
    final trackingNumber = order['trackingNumber']?.toString();
    final canShareReceipt =
        CustomerOrderPresentation.acceptanceStatus(order).isEmpty &&
        (status == 'pending_payment' || status == 'payment_uploaded');
    final hasAcceptance = CustomerOrderPresentation.acceptanceStatus(
      order,
    ).isNotEmpty;
    final l10n = context.l10n;

    final actions = <Widget>[
      if (canShareReceipt)
        AppButton(
          label: l10n.ordersSendReceipt,
          icon: HugeIcons.strokeRoundedInvoice01,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.medium,
          expand: false,
          loading: _sendingReceiptFor == key,
          onPressed: () => _sendReceipt(order, key),
        ),
      if (trackingNumber != null && trackingNumber.isNotEmpty)
        AppButton(
          label: l10n.ordersTrackOrder,
          icon: HugeIcons.strokeRoundedDeliveryTruck01,
          size: AppButtonSize.medium,
          expand: false,
          onPressed: () => context.push('/tracking/$orderId'),
        )
      else if (hasAcceptance ||
          status == 'payment_verified' ||
          status == 'processing')
        AppButton(
          label: l10n.ordersViewStatus,
          icon: HugeIcons.strokeRoundedWorkHistory,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.medium,
          expand: false,
          onPressed: () => context.push('/tracking/$orderId'),
        ),
      if (status == 'delivered')
        StatusChip(
          label: l10n.statusDelivered,
          tone: ChipTone.success,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
      if (status == 'cancelled')
        StatusChip(
          label: l10n.statusCancelled,
          tone: ChipTone.error,
          icon: HugeIcons.strokeRoundedCancel01,
        ),
    ];
    if (actions.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: actions,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.name, required this.size});

  final String? image;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: AppImage(
          imageUrl: image ?? '',
          category: '',
          name: name,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Up to three overlapping item thumbnails for the order card header.
class _ItemThumbs extends StatelessWidget {
  const _ItemThumbs({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final shown = items.whereType<Map>().take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const size = 32.0;
    const step = 22.0;
    return SizedBox(
      width: size + (shown.length - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: _Thumb(
                  image: shown[i]['image']?.toString(),
                  name: shown[i]['name']?.toString() ?? '',
                  size: size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Short fade + upward drift the first time the list appears.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, required this.animate});

  final Widget child;
  final bool animate;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || AppMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
