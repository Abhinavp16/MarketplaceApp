import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_image.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/utils/deal_desk_presentation.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class NegotiationsScreen extends ConsumerStatefulWidget {
  const NegotiationsScreen({super.key});

  @override
  ConsumerState<NegotiationsScreen> createState() => _NegotiationsScreenState();
}

class _NegotiationsScreenState extends ConsumerState<NegotiationsScreen>
    with WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _negotiations = [];

  static const Color primaryBlue = Color(0xFF0F766E);
  static const Color backgroundWhite = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color slateBlue = Color(0xFF4C669A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchNegotiations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchNegotiations();
    }
  }

  Future<void> _fetchNegotiations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/negotiations');
      if (!mounted) return;

      final data = response.data;
      if (data['success'] == true) {
        final List items = data['data'] ?? [];
        setState(() {
          _negotiations = items.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              data['message']?.toString() ??
              context.l10n.negotiationsLoadFailed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.negotiationsLoadFailed;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredNegotiations {
    if (_selectedTab == 0) {
      return _negotiations
          .where((n) => ['pending', 'countered'].contains(n['status']))
          .toList();
    }
    // Completed tab
    return _negotiations
        .where(
          (n) => [
            'accepted',
            'rejected',
            'expired',
            'converted',
          ].contains(n['status']),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundWhite,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                color: backgroundWhite,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 20,
                        color: textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.negotiationsTitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Tabs
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderLight, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildTab(l10n.negotiationsTabActive, 0),
                      const SizedBox(width: 32),
                      _buildTab(l10n.negotiationsTabCompleted, 1),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: _fetchNegotiations,
                  child: _isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 200),
                            Center(
                              child: CircularProgressIndicator(
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        )
                      : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 200),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    style: AppFonts.jakarta(color: textMuted),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _fetchNegotiations,
                                    child: Text(l10n.commonRetry),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : _filteredNegotiations.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 200),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.handshake_outlined,
                                    size: 48,
                                    color: textMuted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedTab == 0
                                        ? l10n.negotiationsEmptyActive
                                        : l10n.negotiationsEmptyCompleted,
                                    style: AppFonts.jakarta(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.negotiationsEmptyHint,
                                    style: AppFonts.jakarta(
                                      fontSize: 13,
                                      color: slateBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          itemCount: _filteredNegotiations.length,
                          itemBuilder: (context, index) =>
                              _buildNegotiationCard(
                                _filteredNegotiations[index],
                              ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: isSelected ? primaryBlue : slateBlue,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusDisplay(
    String status,
    Map<String, dynamic> negotiation,
  ) {
    final l10n = context.l10n;
    final orderStatusLabel = DealDeskPresentation.orderStatusLabel(
      negotiation,
      l10n: l10n,
    );
    switch (status) {
      case 'pending':
        return {
          'label': (orderStatusLabel ?? l10n.dealStatusRequirementSent)
              .toUpperCase(),
          'color': const Color(0xFF6B7280),
          'bg': const Color(0xFFF3F4F6),
        };
      case 'countered':
        return {
          'label': (orderStatusLabel ?? l10n.dealStatusNewPriceReceived)
              .toUpperCase(),
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFFFEF3C7),
        };
      case 'accepted':
        return {
          'label': (orderStatusLabel ?? l10n.dealStatusAccepted).toUpperCase(),
          'color': const Color(0xFF16A34A),
          'bg': const Color(0xFFDCFCE7),
        };
      case 'rejected':
        return {
          'label': (orderStatusLabel ?? l10n.dealStatusRequirementDeclined)
              .toUpperCase(),
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
        };
      case 'expired':
        return {
          'label': (orderStatusLabel ?? l10n.dealStatusRequirementExpired)
              .toUpperCase(),
          'color': const Color(0xFF9CA3AF),
          'bg': const Color(0xFFF3F4F6),
        };
      case 'converted':
        return {
          'label': (orderStatusLabel ?? l10n.statusDealOrderCreated)
              .toUpperCase(),
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFF3E8FF),
        };
      default:
        return {
          'label': orderStatusLabel?.toUpperCase() ?? status.toUpperCase(),
          'color': const Color(0xFF6B7280),
          'bg': const Color(0xFFF3F4F6),
        };
    }
  }

  Widget _buildNegotiationCard(Map<String, dynamic> negotiation) {
    final status = negotiation['status'] as String? ?? 'pending';
    final l10n = context.l10n;
    final statusDisplay = _getStatusDisplay(status, negotiation);
    final product = negotiation['product'] as Map<String, dynamic>? ?? {};
    final productName = localizedName(
      context,
      product,
      fallback: l10n.negotiationsUnknownProduct,
    );
    final imageUrl = product['image'] as String? ?? '';
    final quantity = negotiation['requestedQuantity'] ?? 0;
    final requestedPrice = negotiation['requestedPricePerUnit'] ?? 0;
    final currentPrice = negotiation['currentPricePerUnit'] ?? 0;
    final currentTotal = negotiation['currentTotalPrice'] ?? 0;
    final currentOfferBy = negotiation['currentOfferBy'] as String? ?? '';
    final negotiationNumber = negotiation['negotiationNumber'] as String? ?? '';
    final negotiationId = (negotiation['id'] ?? negotiation['_id'] ?? '')
        .toString();
    final canPay = negotiation['canPay'] == true;
    final hasOrder =
        negotiation['orderId'] != null &&
        negotiation['orderId'].toString().isNotEmpty;
    final createdAt = negotiation['createdAt'] as String? ?? '';

    String formattedDate = '';
    String formattedTime = '';
    if (createdAt.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(createdAt);
        final localeCode = Localizations.localeOf(context).languageCode;
        formattedDate = DateFormat('MMM d, yyyy', localeCode).format(dateTime);
        formattedTime = DateFormat('h:mm a', localeCode).format(dateTime);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () async {
          final result = await context.push(
            '/negotiation-detail/$negotiationId',
          );
          if (result == true) _fetchNegotiations();
        },
        child: Container(
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Product Image (Smaller)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: imageUrl.isNotEmpty
                        ? AppImage(
                            imageUrl: imageUrl,
                            blurHash: product['blurHash'] as String?,
                            category: product['category'] as String? ?? '',
                            name: productName,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: backgroundWhite,
                            child: Icon(
                              Icons.image_outlined,
                              color: textMuted,
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Right: All Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Date, Time, Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate.isNotEmpty
                                    ? formattedDate
                                    : l10n.negotiationsNoDate,
                                style: AppFonts.jakarta(
                                  fontSize: 11,
                                  color: textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (formattedTime.isNotEmpty)
                                Text(
                                  formattedTime,
                                  style: AppFonts.jakarta(
                                    fontSize: 10,
                                    color: textMuted,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusDisplay['bg'] as Color,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              statusDisplay['label'] as String,
                              style: AppFonts.jakarta(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusDisplay['color'] as Color,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // SKU / Negotiation Number
                      Text(
                        negotiationNumber.isNotEmpty
                            ? negotiationNumber
                            : l10n.negotiationsNumberFallback,
                        style: AppFonts.jakarta(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: slateBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Product Name
                      Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Quantity
                      Text(
                        l10n.dealQtyUnits(
                          int.tryParse(
                                NumberFormatter.formatQuantity(quantity),
                              ) ??
                              0,
                        ),
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: slateBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Price Info (Compact)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: backgroundWhite,
                          borderRadius: BorderRadius.circular(6),
                          border: status == 'accepted'
                              ? const Border(
                                  left: BorderSide(
                                    color: Color(0xFF16A34A),
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.negotiationsYourExpectedPrice,
                                  style: AppFonts.jakarta(
                                    fontSize: 11,
                                    color: slateBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${NumberFormatter.formatPrice(requestedPrice)}',
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  status == 'countered' &&
                                          currentOfferBy == 'admin'
                                      ? l10n.negotiationsNewPriceFromPlatformLabel
                                      : l10n.negotiationsCurrentLabel,
                                  style: AppFonts.jakarta(
                                    fontSize: 11,
                                    color: slateBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${NumberFormatter.formatPrice(currentPrice)}',
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: status == 'accepted'
                                        ? const Color(0xFF16A34A)
                                        : primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.negotiationsTotalLabel,
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  '₹${NumberFormatter.formatPrice(currentTotal)}',
                                  style: AppFonts.jakarta(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: status == 'accepted'
                                        ? const Color(0xFF16A34A)
                                        : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Action Button
                      _buildActionButton(
                        status,
                        currentOfferBy,
                        canPay,
                        negotiationId,
                        hasOrder,
                        negotiation['orderId']?.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String status,
    String currentOfferBy,
    bool canPay,
    String negotiationId,
    bool hasOrder,
    String? orderId,
  ) {
    final l10n = context.l10n;
    String label;
    String style;
    IconData? icon;
    VoidCallback? onTap;

    Future<void> openDetail() async {
      final result = await context.push('/negotiation-detail/$negotiationId');
      if (result == true) _fetchNegotiations();
    }

    if (hasOrder || status == 'converted') {
      label = l10n.dealViewOrder;
      style = 'primary';
      icon = Icons.local_shipping_outlined;
      onTap = () {
        if (orderId != null && orderId.isNotEmpty && orderId != 'null') {
          context.push('/tracking/$orderId');
        } else {
          context.push('/previous-orders');
        }
      };
    } else if (status == 'countered' && currentOfferBy == 'admin') {
      label = l10n.dealReplyInChat;
      style = 'primary';
      icon = Icons.reply_rounded;
      onTap = openDetail;
    } else if (status == 'accepted' && canPay) {
      // Legacy rows accepted before order auto-creation.
      label = l10n.commonViewDetails;
      style = 'primary';
      icon = Icons.account_balance_wallet_rounded;
      onTap = openDetail;
    } else if (status == 'pending') {
      label = l10n.dealStatusRequirementSent;
      style = 'disabled';
    } else if (status == 'rejected') {
      label = l10n.dealStatusRequirementDeclined;
      style = 'disabled';
    } else if (status == 'expired') {
      label = l10n.dealStatusRequirementExpired;
      style = 'disabled';
    } else {
      label = l10n.commonViewDetails;
      style = 'outline';
      onTap = openDetail;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: style == 'primary'
              ? primaryBlue
              : style == 'disabled'
              ? borderLight
              : surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          border: style == 'outline' ? Border.all(color: borderLight) : null,
          boxShadow: style == 'primary' && icon != null
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: style == 'primary'
                    ? Colors.white
                    : style == 'disabled'
                    ? const Color(0xFF9CA3AF)
                    : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
