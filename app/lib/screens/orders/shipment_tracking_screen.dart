import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/brand_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/customer_order_presentation.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';
import '../../widgets/app_image.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../widgets/ui/ui.dart';
import 'order_parts.dart';

class ShipmentTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ShipmentTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<ShipmentTrackingScreen> createState() =>
      _ShipmentTrackingScreenState();
}

class _ShipmentTrackingScreenState
    extends ConsumerState<ShipmentTrackingScreen> {
  /// Delivered orders whose celebration already played this session.
  static final Set<String> _celebrated = {};

  late final Dio _dio;
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _requiresLogin = false;
  _TrackingError? _error;

  @override
  void initState() {
    super.initState();
    _dio =
        Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
            ),
          )
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                final token = await StorageService.getAccessToken();
                if (token != null) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
                return handler.next(options);
              },
            ),
          );
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    final orderId = widget.orderId.trim();
    if (orderId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = _TrackingError.invalidOrder;
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _requiresLogin = false;
        _error = null;
      });
    }

    try {
      final response = await _dio.get(
        '/orders/${Uri.encodeComponent(orderId)}',
      );
      final responseData = response.data;
      final orderData = responseData is Map ? responseData['data'] : null;
      if (response.statusCode == 200 &&
          responseData is Map &&
          responseData['success'] == true &&
          orderData is Map) {
        if (!mounted) return;
        setState(() {
          _order = Map<String, dynamic>.from(orderData);
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = _TrackingError.unavailable;
        _isLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final statusCode = error.response?.statusCode;
      setState(() {
        _requiresLogin = statusCode == 401 || statusCode == 403;
        _error = switch (statusCode) {
          401 || 403 => _TrackingError.signInRequired,
          404 => _TrackingError.orderGone,
          _ => _TrackingError.loadFailed,
        };
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error fetching order: $error');
      if (!mounted) return;
      setState(() {
        _error = _TrackingError.loadFailed;
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/previous-orders');
    }
  }

  String _getStatusDisplay(String status) {
    return CustomerOrderPresentation.label(context.l10n, status);
  }

  String _errorText(AppLocalizations l10n, _TrackingError? error) {
    switch (error) {
      case _TrackingError.invalidOrder:
        return l10n.trackingInvalidOrder;
      case _TrackingError.unavailable:
        return l10n.trackingUnavailable;
      case _TrackingError.signInRequired:
        return l10n.trackingSignInToView;
      case _TrackingError.orderGone:
        return l10n.trackingOrderGone;
      case _TrackingError.loadFailed:
        return l10n.trackingLoadFailed;
      case null:
        return l10n.trackingOrderNotFound;
    }
  }

  String _formatDate(DateTime value, String pattern) {
    return DateFormat(
      pattern,
      Localizations.localeOf(context).languageCode,
    ).format(value);
  }

  String? _formatRaw(dynamic value, String pattern) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null ? null : _formatDate(parsed.toLocal(), pattern);
  }

  Future<void> _callShop() async {
    final uri = Uri(
      scheme: 'tel',
      path: BrandConfig.supportPhone.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      showAppSnack(
        context,
        context.l10n.commonSomethingWentWrong,
        tone: SnackTone.error,
      );
    }
  }

  Future<void> _emailShop(String orderNumber) async {
    final uri = Uri(
      scheme: 'mailto',
      path: BrandConfig.supportEmail,
      query: 'subject=${Uri.encodeComponent(orderNumber)}',
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      showAppSnack(
        context,
        context.l10n.commonSomethingWentWrong,
        tone: SnackTone.error,
      );
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showAppSnack(context, context.l10n.commonCopied, tone: SnackTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = _order;
    final orderNumber = order?['orderNumber']?.toString() ?? '';

    final Widget body;
    if (_isLoading && order == null) {
      body = const _TrackingSkeleton(key: ValueKey('loading'));
    } else if (_error != null || order == null) {
      body = _buildError(l10n);
    } else {
      body = KeyedSubtree(
        key: const ValueKey('content'),
        child: _buildContent(order),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(
        title: l10n.trackingTitle,
        subtitle: orderNumber.isEmpty ? null : '#$orderNumber',
        onBack: _goBack,
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.exit,
        child: body,
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      key: const ValueKey('error'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: _requiresLogin
                  ? HugeIcons.strokeRoundedUserCircle
                  : HugeIcons.strokeRoundedAlert02,
              tone: _requiresLogin ? ChipTone.brand : ChipTone.neutral,
              title: _errorText(l10n, _error),
              actionLabel: _requiresLogin
                  ? l10n.commonLogin
                  : l10n.commonTryAgain,
              onAction: _requiresLogin
                  ? () => context.go('/login')
                  : _fetchOrder,
            ),
            TextButton(
              onPressed: () => context.go('/previous-orders'),
              child: Text(l10n.trackingViewPreviousOrders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: AppFonts.jakarta(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> order) {
    final l10n = context.l10n;
    final orderNumber = order['orderNumber']?.toString() ?? '';
    final status = CustomerOrderPresentation.stage(order);
    final trackingNumber = order['trackingNumber']?.toString() ?? '';
    final courierName = order['courierName']?.toString() ?? '';
    final shippedAt = _formatRaw(order['shippedAt'], 'MMM dd, yyyy');
    final deliveredAt = _formatRaw(order['deliveredAt'], 'MMM dd, yyyy');
    final statusHistory = order['statusHistory'] as List? ?? [];
    final items = order['items'] as List? ?? [];
    final steps = CustomerOrderPresentation.journey(order);
    final action = CustomerOrderPresentation.customerAction(l10n, status);
    final orderKey = order['_id']?.toString() ?? orderNumber;
    final delivered = status == 'delivered';
    final celebrate = delivered && !_celebrated.contains(orderKey);
    if (delivered) _celebrated.add(orderKey);
    final placedOn = _formatRaw(order['createdAt'], 'MMM dd, yyyy · hh:mm a');
    final address = order['shippingAddress'] is Map
        ? Map<String, dynamic>.from(order['shippingAddress'] as Map)
        : null;

    return RefreshIndicator(
      onRefresh: _fetchOrder,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Summary
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (delivered) ...[
                  Center(
                    child: OrderSuccessBadge(
                      size: 60,
                      animate: celebrate,
                      icon: HugeIcons.strokeRoundedPackageDelivered,
                    ),
                  ),
                  Center(
                    child: Text(
                      l10n.ordDeliveredTitle,
                      textAlign: TextAlign.center,
                      style: AppFonts.jakarta(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.orderIdLabel,
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#$orderNumber',
                            style: AppFonts.jakarta(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (placedOn != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              l10n.ordPlacedOn(placedOn),
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: StatusChip(
                        label: _getStatusDisplay(status),
                        tone: CustomerOrderPresentation.chipTone(status),
                        icon: CustomerOrderPresentation.hugeIcon(status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OrderProgressBar(
                  value: CustomerOrderPresentation.progress(order),
                  color: CustomerOrderPresentation.toneColor(status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // What the customer needs to do / why the order stopped
          if (action != null) ...[
            OrderInfoPanel(
              title: l10n.ordActionTitle,
              message: action,
              tone: ChipTone.warning,
              icon: HugeIcons.strokeRoundedTask01,
            ),
            const SizedBox(height: 12),
          ] else if (status == 'awaiting_acceptance') ...[
            OrderInfoPanel(
              message: l10n.checkoutApprovalNote,
              tone: ChipTone.info,
              icon: HugeIcons.strokeRoundedClock01,
            ),
            const SizedBox(height: 12),
          ],
          if (status == 'rejected') ...[
            OrderInfoPanel(
              title: l10n.trackingNotApproved,
              message:
                  order['rejectionReason']?.toString().trim().isNotEmpty == true
                  ? order['rejectionReason'].toString()
                  : l10n.trackingContactSupport,
              tone: ChipTone.error,
              icon: HugeIcons.strokeRoundedCancelCircle,
            ),
            const SizedBox(height: 12),
          ] else if (status == 'cancelled') ...[
            OrderInfoPanel(
              title: l10n.ordCancelledTitle,
              message: l10n.trackingContactSupport,
              tone: ChipTone.error,
              icon: HugeIcons.strokeRoundedCancel01,
            ),
            const SizedBox(height: 12),
          ],

          // Journey
          const SizedBox(height: 12),
          _sectionTitle(l10n.trackingOrderJourney),
          AppCard(
            child: OrderStepTracker(
              steps: steps,
              label: _getStatusDisplay,
              currentBadge: l10n.trackingLatestBadge,
              subtitle: (step) {
                if (step.at != null) {
                  return _formatDate(step.at!, 'MMM dd, yyyy · hh:mm a');
                }
                return step.state == OrderStepState.upcoming
                    ? l10n.ordStepUpcoming
                    : null;
              },
            ),
          ),

          // Transport
          if (trackingNumber.isNotEmpty || courierName.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle(l10n.trackingCourierInfo),
            AppCard(
              child: Column(
                children: [
                  if (courierName.isNotEmpty)
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedDeliveryTruck01,
                      label: l10n.ordTransporterLabel,
                      value: courierName,
                    ),
                  if (trackingNumber.isNotEmpty) ...[
                    if (courierName.isNotEmpty) const SizedBox(height: 12),
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedInvoice01,
                      label: l10n.ordLrNumberLabel,
                      value: trackingNumber,
                      trailing: IconButton(
                        tooltip: l10n.commonCopy,
                        onPressed: () => _copy(trackingNumber),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(44, 44),
                        ),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCopy01,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                  if (shippedAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedCalendar03,
                      label: l10n.trackingShippedDate,
                      value: shippedAt,
                    ),
                  ],
                  if (deliveredAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: HugeIcons.strokeRoundedPackageDelivered,
                      label: l10n.trackingDeliveredDate,
                      value: deliveredAt,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Items
          if (items.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle(l10n.commonItemsCount(items.length)),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items.take(3)) _buildItemRow(item),
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.trackingMoreItems(items.length - 3),
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Dated history
          if (statusHistory.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle(l10n.ordersStatusHistory),
            AppCard(
              child: Column(
                children: [
                  for (final raw in statusHistory.reversed)
                    if (raw is Map) _buildHistoryRow(raw),
                ],
              ),
            ),
          ],

          // Shipping address
          if (address != null) ...[
            const SizedBox(height: 24),
            _sectionTitle(l10n.checkoutShippingAddress),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedLocation01,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address['fullName']?.toString() ?? '',
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${address['addressLine1'] ?? ''}${address['addressLine2'] != null ? ', ${address['addressLine2']}' : ''}',
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          '${address['city'] ?? ''}, ${localizedStateName(context, address['state']?.toString() ?? '')} - ${address['pincode'] ?? ''}',
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (address['phone'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.checkoutPhoneValue('${address['phone']}'),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Help
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ordNeedHelp,
                  style: AppFonts.jakarta(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.ordNeedHelpSubtitle,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: l10n.commonCall,
                        icon: HugeIcons.strokeRoundedCall02,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.medium,
                        onPressed: _callShop,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: l10n.helpEmailUs,
                        icon: HugeIcons.strokeRoundedMail01,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.medium,
                        onPressed: () => _emailShop(orderNumber),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic rawItem) {
    final l10n = context.l10n;
    final item = rawItem is Map ? rawItem : const {};
    final snapshot = item['productSnapshot'] is Map
        ? item['productSnapshot'] as Map
        : null;
    final name = localizedName(
      context,
      snapshot,
      fallback: l10n.ordersProductFallback,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: AppImage(
                imageUrl: snapshot?['image']?.toString() ?? '',
                category: '',
                name: name,
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.trackingItemQtyTotal(
                    '${item['quantity']}',
                    NumberFormatter.formatPrice(item['totalPrice']),
                  ),
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map entry) {
    final status = entry['status']?.toString() ?? '';
    final note = entry['note']?.toString();
    final when = _formatRaw(entry['timestamp'], 'MMM dd, yyyy · hh:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
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
                  _getStatusDisplay(status),
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  [
                    ?when,
                    if (note != null && note.isNotEmpty) note,
                  ].join(' · '),
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.secondarySoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 18, color: AppColors.secondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _TrackingSkeleton extends StatelessWidget {
  const _TrackingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 60, height: 10),
                SizedBox(height: 8),
                Row(
                  children: [
                    Skeleton(width: 140, height: 18),
                    Spacer(),
                    Skeleton(width: 90, height: 24, radius: AppRadius.pill),
                  ],
                ),
                SizedBox(height: 16),
                Skeleton(height: 4, radius: AppRadius.pill),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Skeleton(width: 150, height: 16),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Skeleton(width: 32, height: 32, radius: AppRadius.pill),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(width: 160, height: 12),
                              SizedBox(height: 6),
                              Skeleton(width: 100, height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrackingError {
  invalidOrder,
  unavailable,
  signInRequired,
  orderGone,
  loadFailed,
}
