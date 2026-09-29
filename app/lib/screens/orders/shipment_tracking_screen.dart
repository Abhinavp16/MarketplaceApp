import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/customer_order_presentation.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class ShipmentTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ShipmentTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<ShipmentTrackingScreen> createState() =>
      _ShipmentTrackingScreenState();
}

class _ShipmentTrackingScreenState
    extends ConsumerState<ShipmentTrackingScreen> {
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

  Color _getStatusColor(String status) =>
      CustomerOrderPresentation.color(status);

  IconData _getStatusIcon(String status) =>
      CustomerOrderPresentation.icon(status);

  String? _timelineTimestamp(
    Map<String, dynamic> order,
    List<dynamic> history,
    String stage,
  ) {
    dynamic value;
    switch (stage) {
      case 'awaiting_acceptance':
        value = order['createdAt'];
      case 'accepted_awaiting_payment':
        value = order['acceptedAt'];
      case 'rejected':
        value = order['rejectedAt'];
      default:
        for (final item in history) {
          if (item is Map && item['status'] == stage) {
            value = item['timestamp'];
            break;
          }
        }
    }
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null
        ? null
        : _formatDate(parsed.toLocal(), 'MMM dd, yyyy hh:mm a');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundLight,
          elevation: 0,
          leading: IconButton(
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
            ),
          ),
          title: Text(
            l10n.trackingTitle,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundLight,
          elevation: 0,
          leading: IconButton(
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
            ),
          ),
          title: Text(
            l10n.trackingTitle,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorText(l10n, _error),
                  textAlign: TextAlign.center,
                  style: AppFonts.jakarta(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                if (_requiresLogin)
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: Text(l10n.commonLogin),
                  )
                else
                  FilledButton.icon(
                    onPressed: _fetchOrder,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.commonTryAgain),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/previous-orders'),
                  child: Text(l10n.trackingViewPreviousOrders),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final orderNumber = order['orderNumber'] ?? '';
    final status = CustomerOrderPresentation.stage(order);
    final trackingNumber = order['trackingNumber'];
    final courierName = order['courierName'];
    final shippedAt = order['shippedAt'];
    final deliveredAt = order['deliveredAt'];
    final statusHistory = order['statusHistory'] as List? ?? [];
    final items = order['items'] as List? ?? [];

    final statusColor = _getStatusColor(status);
    final statusDisplay = _getStatusDisplay(status);
    final timelineStatuses = CustomerOrderPresentation.timeline(order);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        ),
        title: Text(
          l10n.trackingTitle,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrder,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.orderIdLabel,
                                style: AppFonts.jakarta(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '#$orderNumber',
                                style: AppFonts.jakarta(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusDisplay,
                                textAlign: TextAlign.center,
                                style: AppFonts.jakarta(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.gray100),
                        const SizedBox(height: 16),
                        ...items
                            .take(2)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child:
                                          item['productSnapshot']?['image'] !=
                                              null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                item['productSnapshot']['image'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.agriculture,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.agriculture,
                                              color: AppColors.primary,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            localizedName(
                                              context,
                                              item['productSnapshot'] is Map
                                                  ? item['productSnapshot']
                                                        as Map
                                                  : null,
                                              fallback:
                                                  l10n.ordersProductFallback,
                                            ),
                                            style: AppFonts.jakarta(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            l10n.trackingItemQtyTotal(
                                              '${item['quantity']}',
                                              NumberFormatter.formatPrice(
                                                item['totalPrice'],
                                              ),
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
                              ),
                            ),
                        if (items.length > 2)
                          Text(
                            l10n.trackingMoreItems(items.length - 2),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // Order Journey Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.trackingOrderJourney,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (status == 'rejected')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trackingNotApproved,
                          style: AppFonts.jakarta(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order['rejectionReason']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? order['rejectionReason'].toString()
                              : l10n.trackingContactSupport,
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            height: 1.4,
                            color: const Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Timeline
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: timelineStatuses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final s = entry.value;
                    final isLast = index == timelineStatuses.length - 1;
                    final isCompleted = true;
                    final isCurrent = index == timelineStatuses.length - 1;
                    final subtitle =
                        _timelineTimestamp(order, statusHistory, s) ?? '';

                    return _buildTimelineItem(
                      icon: _getStatusIcon(s),
                      iconColor: isCurrent ? statusColor : AppColors.success,
                      title: _getStatusDisplay(s),
                      subtitle: subtitle,
                      isCompleted: isCompleted,
                      isLast: isLast,
                      isCurrent: isCurrent,
                      badge: isCurrent ? l10n.trackingLatestBadge : null,
                    );
                  }).toList(),
                ),
              ),

              // Courier Information (only show if shipped)
              if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.trackingCourierInfo,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray100),
                    ),
                    child: Column(
                      children: [
                        if (courierName != null && courierName.isNotEmpty)
                          _buildInfoRow(l10n.trackingCourier, courierName),
                        if (courierName != null && courierName.isNotEmpty)
                          const SizedBox(height: 12),
                        _buildInfoRow(l10n.trackingNumberLabel, trackingNumber),
                        if (shippedAt != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            l10n.trackingShippedDate,
                            _formatDate(
                              DateTime.parse(shippedAt),
                              'MMM dd, yyyy',
                            ),
                          ),
                        ],
                        if (deliveredAt != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            l10n.trackingDeliveredDate,
                            _formatDate(
                              DateTime.parse(deliveredAt),
                              'MMM dd, yyyy',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Shipping Address
              if (order['shippingAddress'] != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.checkoutShippingAddress,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['shippingAddress']['fullName'] ?? '',
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${order['shippingAddress']['addressLine1'] ?? ''}${order['shippingAddress']['addressLine2'] != null ? ', ${order['shippingAddress']['addressLine2']}' : ''}',
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${order['shippingAddress']['city'] ?? ''}, ${order['shippingAddress']['state'] ?? ''} - ${order['shippingAddress']['pincode'] ?? ''}',
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (order['shippingAddress']['phone'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.checkoutPhoneValue(
                              '${order['shippingAddress']['phone']}',
                            ),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
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
              Text(
                value,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isLast,
    bool isCurrent = false,
    String? badge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppColors.success : AppColors.gray300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withOpacity(0.7),
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: AppFonts.jakarta(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
