import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/negotiation_socket_service.dart';
import '../../core/utils/number_formatter.dart';
import '../../widgets/app_image.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'deal_desk_widgets.dart';

class NegotiationDetailScreen extends ConsumerStatefulWidget {
  final String negotiationId;
  const NegotiationDetailScreen({super.key, required this.negotiationId});

  @override
  ConsumerState<NegotiationDetailScreen> createState() =>
      _NegotiationDetailScreenState();
}

class _NegotiationDetailScreenState
    extends ConsumerState<NegotiationDetailScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  // A chat message is on its way. The text field stays enabled (so the
  // keyboard stays open); only the send button waits.
  bool _isSending = false;
  bool _summaryExpanded = true;
  // The summary shows for a moment when the deal opens, then folds away.
  Timer? _autoCollapseTimer;
  // The first load jumps straight to the newest message; later ones glide.
  bool _openedAtBottom = false;
  String? _error;
  Map<String, dynamic>? _negotiation;
  final List<Map<String, dynamic>> _optimisticMessages = [];
  final Map<String, String> _typingUsers = {}; // { userId: displayName }
  final Map<String, bool> _readReceipts = {}; // { messageId: isRead }
  final _counterMessageController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  Timer? _localTypingTimer;
  Timer? _remoteTypingTimer;
  bool _isTyping = false;
  final NegotiationSocketService _socketService = NegotiationSocketService();
  // Read once while mounted: `ref` can't be used in dispose(), where the
  // socket still needs it to leave the room.
  String? _userId;
  int _detailRequestSequence = 0;
  bool _refreshAfterInitialLoad = false;
  static const int maxMessageLength = 280;

  /// Consecutive messages from one side within this gap share one timestamp.
  static const Duration _groupGap = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerFocus.addListener(_onComposerFocusChanged);
    _fetchDetail();
    _initializeSocket();
    // The REST response remains canonical. Keep a short fallback refresh even
    // when Socket.IO reports connected because a stale room subscription can
    // otherwise leave this screen unchanged until it is reopened.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _fetchDetail(background: true);
    });
    // "How Deal Desk works", once per device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showDealDeskExplainerOnce(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _fetchDetail(background: true);
    }
  }

  void _onComposerFocusChanged() {
    if (!_composerFocus.hasFocus || !mounted) return;
    // Give the chat the room while typing.
    if (_summaryExpanded) setState(() => _summaryExpanded = false);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _scrollToBottom();
    });
  }

  void _initializeSocket() {
    final auth = ref.read(authProvider);
    _userId = auth.user?.id;

    _socketService.onMessageReceived = (data) {
      if (data['negotiationId']?.toString() != widget.negotiationId) return;
      if (mounted) {
        setState(_typingUsers.clear);
      }
      _refreshFromSocket();
    };
    _socketService.onNegotiationChanged = _refreshFromSocket;

    _socketService.onUserTyping = (userId, username) {
      if (mounted) {
        setState(() {
          // Empty name -> shown as the localized "DemoMart" label.
          _typingUsers[userId] = username.trim();
        });
        _remoteTypingTimer?.cancel();
        _remoteTypingTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(_typingUsers.clear);
        });
      }
    };

    _socketService.onStopTyping = (userId, _) {
      if (mounted) {
        setState(() {
          _typingUsers.remove(userId);
        });
        if (_typingUsers.isEmpty) _remoteTypingTimer?.cancel();
      }
    };

    _socketService.onUserStatus = (userId, _, isOnline) {
      if (!isOnline && mounted) {
        setState(() => _typingUsers.remove(userId));
      }
    };

    _socketService.onReadReceipt = (messageId, userId) {
      if (mounted) {
        setState(() {
          _readReceipts[messageId] = true;
        });
      }
    };

    _socketService.onConnect = () {
      if (mounted) {
        setState(_typingUsers.clear);
      }
      _remoteTypingTimer?.cancel();
    };
    _socketService.onReconnect = _refreshFromSocket;

    _socketService.onDisconnect = () {
      debugPrint('[Socket] Disconnected');
      if (mounted) {
        setState(_typingUsers.clear);
      }
      _remoteTypingTimer?.cancel();
    };

    if (auth.user?.id != null) {
      _socketService.connect(
        serverUrl: ApiConfig.publicBaseUrl,
        negotiationId: widget.negotiationId,
        userId: auth.user!.id,
        userRole: 'wholesaler',
        username: auth.user?.name ?? 'Wholesaler',
      );
    }
  }

  void _refreshFromSocket() {
    if (!mounted) return;
    if (_negotiation == null || _isLoading) {
      _refreshAfterInitialLoad = true;
      return;
    }
    _fetchDetail(background: true);
  }

  void _flushQueuedRefresh() {
    if (!_refreshAfterInitialLoad || _negotiation == null || _isLoading) return;
    _refreshAfterInitialLoad = false;
    _fetchDetail(background: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _autoCollapseTimer?.cancel();
    _localTypingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    _emitStopTyping();
    _composerFocus.removeListener(_onComposerFocusChanged);
    _composerFocus.dispose();
    _counterMessageController.dispose();
    _scrollController.dispose();

    // Disconnect from socket (no `ref` here; it's gone once disposing).
    final userId = _userId;
    if (userId != null) {
      _socketService.leaveNegotiation(userId: userId, userRole: 'wholesaler');
    }
    _socketService.disconnect();

    super.dispose();
  }

  Future<bool> _fetchDetail({bool background = false}) async {
    if (!mounted) return false;
    final requestSequence = ++_detailRequestSequence;
    if (!background) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/negotiations/${widget.negotiationId}');
      if (!mounted || requestSequence != _detailRequestSequence) return false;

      if (response.data['success'] == true) {
        final previousHistoryLength =
            (_negotiation?['history'] as List?)?.length ?? 0;
        setState(() {
          _negotiation = response.data['data'];
          final history = (_negotiation?['history'] as List?) ?? const [];
          final confirmedMessageIds = history
              .map(
                (entry) => entry is Map ? entry['messageId']?.toString() : null,
              )
              .whereType<String>()
              .toSet();
          _optimisticMessages.removeWhere(
            (entry) => confirmedMessageIds.contains(entry['messageId']),
          );
          _error = null;
          _isLoading = false;
        });
        _flushQueuedRefresh();
        final currentHistoryLength =
            (_negotiation?['history'] as List?)?.length ?? 0;
        if (!background || currentHistoryLength > previousHistoryLength) {
          final animate = _openedAtBottom;
          _openedAtBottom = true;
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _scrollToBottom(animate: animate);
          });
        }
        // First load: show the summary for a moment, then fold it away.
        _autoCollapseTimer ??= Timer(const Duration(milliseconds: 1200), () {
          if (mounted && _summaryExpanded) {
            setState(() => _summaryExpanded = false);
          }
        });
        return true;
      } else {
        if (!background) {
          setState(() {
            _error =
                response.data['message']?.toString() ??
                context.l10n.dealLoadFailed;
            _isLoading = false;
          });
          _flushQueuedRefresh();
        }
      }
    } on DioException catch (e) {
      if (!mounted || requestSequence != _detailRequestSequence) return false;
      if (!background) {
        setState(() {
          _error =
              e.response?.data?['message']?.toString() ??
              context.l10n.dealLoadFailed;
          _isLoading = false;
        });
        _flushQueuedRefresh();
      }
    } catch (_) {
      if (!mounted || requestSequence != _detailRequestSequence) return false;
      if (!background) {
        setState(() {
          _error = context.l10n.commonSomethingWentWrong;
          _isLoading = false;
        });
        _flushQueuedRefresh();
      }
    }
    return false;
  }

  // NOTE: wholesalers negotiate through chat messages only. Accept, counter
  // and reject are admin/member actions performed from the admin panel, which
  // also creates the order, so the app has no order step.

  void _showError(String msg) {
    if (!mounted) return;
    showAppSnack(context, msg, tone: SnackTone.error);
  }

  // NOTE: counter sheet removed — wholesalers reply through chat messages only.

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = _negotiation;
    final negotiationNumber = n?['negotiationNumber'] as String? ?? '';
    final Widget body;
    if (_isLoading) {
      body = const _DetailSkeleton(key: ValueKey('loading'));
    } else if (_error != null) {
      body = ListView(
        key: const ValueKey('error'),
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: HugeIcons.strokeRoundedAlert02,
            tone: ChipTone.error,
            title: _error!,
            actionLabel: l10n.commonRetry,
            onAction: _fetchDetail,
          ),
        ],
      );
    } else {
      body = KeyedSubtree(
        key: const ValueKey('content'),
        child: _buildContent(),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(
          title: negotiationNumber.isNotEmpty
              ? negotiationNumber
              : l10n.negotiationTitleFallback,
          subtitle: n == null
              ? null
              : localizedName(
                  context,
                  n['productSnapshot'] as Map<String, dynamic>?,
                  fallback: l10n.dealProductFallback,
                ),
          actions: [
            HeaderIconButton(
              icon: HugeIcons.strokeRoundedInformationCircle,
              tooltip: l10n.dealExplainerTitle,
              onPressed: () => showDealDeskExplainer(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        // No cross-fade here: the chat list owns _scrollController, and an
        // outgoing copy must never share it with the incoming one.
        body: body,
      ),
    );
  }

  Widget _buildContent() {
    final n = _negotiation!;
    final status = n['status'] as String? ?? 'pending';
    final currentOfferBy = n['currentOfferBy'] as String? ?? '';

    return Column(
      children: [
        _buildSummaryCard(n),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _fetchDetail,
            child: _buildChatList(n),
          ),
        ),

        // Bottom Action Bar — chat stays open on converted orders so the
        // wholesaler can follow up; only closed states hide the composer.
        if (!['rejected', 'expired'].contains(status))
          _buildBottomActions(status, currentOfferBy)
        else
          _buildClosedBar(n),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pinned summary
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(Map<String, dynamic> n) {
    final l10n = context.l10n;
    final productSnapshot = n['productSnapshot'] as Map<String, dynamic>? ?? {};
    final quantity = n['requestedQuantity'] ?? 0;
    final currentPrice = n['currentPricePerUnit'] ?? 0;
    final currentTotal = n['currentTotalPrice'] ?? 0;
    final imageUrl = productSnapshot['image'] as String? ?? '';
    final productName = localizedName(
      context,
      productSnapshot,
      fallback: l10n.dealProductFallback,
    );
    final suffix = DealDeskPresentation.unitSuffix(productSnapshot, l10n);
    final quantityText = dealQuantityText(
      l10n,
      productSnapshot,
      _quantityCount(quantity),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: () {
              // The user took over: no more folding it on a timer.
              _autoCollapseTimer?.cancel();
              setState(() => _summaryExpanded = !_summaryExpanded);
            },
            scale: 0.99,
            borderRadius: BorderRadius.zero,
            semanticLabel: _summaryExpanded
                ? l10n.dealSummaryHideDetails
                : l10n.dealSummaryShowDetails,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: AppColors.gray50,
                      child: AppImage(
                        imageUrl: imageUrl,
                        category: (productSnapshot['category'] ?? '')
                            .toString(),
                        name: productName,
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          maxLines: _summaryExpanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              quantityText,
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            DealStatusChip(negotiation: n, dense: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: DealDeskPresentation.rupees(currentPrice),
                              style: AppText.price(fontSize: 15),
                            ),
                            TextSpan(
                              text: suffix,
                              style: AppFonts.jakarta(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DealDeskPresentation.rupees(currentTotal),
                        style: AppText.price(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 32,
                    height: 44,
                    child: Center(
                      child: AnimatedRotation(
                        turns: _summaryExpanded ? 0.5 : 0,
                        duration: AppMotion.of(context, AppMotion.base),
                        curve: AppMotion.standard,
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: _summaryExpanded
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      child: _buildSummaryDetails(n, suffix),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetails(Map<String, dynamic> n, String suffix) {
    final l10n = context.l10n;
    final productSnapshot = n['productSnapshot'] as Map<String, dynamic>? ?? {};
    final quantity = n['requestedQuantity'] ?? 0;
    final currentTotal = n['currentTotalPrice'] ?? 0;
    final originalPrice = productSnapshot['price'] ?? 0;
    final kind = DealDeskPresentation.statusKind(n);
    final agreed =
        kind == DealStatusKind.acceptedOrderPending ||
        kind == DealStatusKind.orderCreated;
    final yourPrice = DealDeskPresentation.latestPriceBy(n, 'wholesaler');
    final rawCurrent = n['currentPricePerUnit'];
    final currentPrice = rawCurrent is num
        ? rawCurrent
        : num.tryParse(rawCurrent?.toString() ?? '');
    final platformPrice = agreed
        ? currentPrice ?? DealDeskPresentation.latestPriceBy(n, 'admin')
        : DealDeskPresentation.latestPriceBy(n, 'admin');
    final orderRef = n['orderId'];
    final orderId = orderRef is Map
        ? orderRef['_id']?.toString()
        : orderRef?.toString();
    final orderNumber = orderRef is Map
        ? orderRef['orderNumber']?.toString() ?? ''
        : (n['orderNumber']?.toString() ?? '');
    final approvedBy = n['approvedBy'] as Map<String, dynamic>?;
    final approvedByName = approvedBy?['name']?.toString() ?? '';
    final approvedByLabel = approvedBy == null
        ? null
        : approvedByName.isNotEmpty
        ? l10n.dealAcceptedByPlatformName(approvedByName)
        : l10n.dealAcceptedByPlatform;

    Widget priceCell(String label, num? price, {bool highlight = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: highlight ? AppColors.primaryTint : AppColors.gray50,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: highlight ? AppColors.primarySoft : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              if (price != null)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: DealDeskPresentation.rupees(price),
                        style: AppText.price(
                          fontSize: 16,
                          color: highlight
                              ? AppColors.primaryDeep
                              : AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: suffix,
                        style: AppFonts.jakarta(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  l10n.dealAwaitingPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              priceCell(l10n.dealPriceYours, yourPrice),
              const SizedBox(width: 8),
              priceCell(
                agreed ? l10n.dealPriceAgreed : l10n.dealPricePlatform,
                platformPrice,
                highlight: platformPrice != null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SummaryRow(
            label: l10n.dealTotalForUnits(_quantityCount(quantity)),
            value: DealDeskPresentation.rupees(currentTotal),
            emphasize: true,
          ),
          Text(
            l10n.dealRetailPrice(NumberFormatter.formatPrice(originalPrice)),
            style: AppFonts.jakarta(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          if (DealDeskPresentation.stepIndex(n) >= 0) ...[
            const SizedBox(height: 14),
            DealStatusStepper(negotiation: n),
          ],
          if (approvedByLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                    color: AppColors.primaryDeep,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      approvedByLabel,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (orderId != null && orderId.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppButton(
              label: orderNumber.isNotEmpty
                  ? l10n.dealViewOrderNumber(orderNumber)
                  : l10n.dealViewOrder,
              icon: HugeIcons.strokeRoundedTruckDelivery,
              variant: AppButtonVariant.tonal,
              size: AppButtonSize.medium,
              onPressed: () => context.push('/tracking/$orderId'),
            ),
            const SizedBox(height: 8),
            _buildOrderTrackingCard(
              orderRef is Map
                  ? Map<String, dynamic>.from(orderRef as Map)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderTrackingCard(Map<String, dynamic>? order) {
    if (order == null) return const SizedBox.shrink();
    final status = (order['status'] ?? 'pending_payment').toString();
    final tracking = (order['trackingNumber'] ?? '').toString();
    final courier = (order['courierName'] ?? '').toString();
    final history = (order['statusHistory'] as List?) ?? [];
    final l10n = context.l10n;
    String label(String s) {
      switch (s) {
        case 'pending_payment':
          return l10n.dealOrderStatusPaymentPending;
        case 'payment_uploaded':
          return l10n.dealOrderStatusPaymentVerificationPending;
        case 'payment_verified':
          return l10n.dealOrderStatusPaymentVerified;
        case 'processing':
          return l10n.dealOrderStatusPacking;
        case 'shipped':
          return l10n.dealOrderStatusDispatched;
        case 'delivered':
          return l10n.dealOrderStatusDelivered;
        case 'cancelled':
          return l10n.dealOrderStatusCancelled;
        default:
          return s;
      }
    }

    const stages = [
      'pending_payment',
      'payment_verified',
      'processing',
      'shipped',
      'delivered',
    ];
    int currentIdx = stages.indexOf(status);
    // payment_uploaded maps to step 0 pending visually
    if (status == 'payment_uploaded') currentIdx = 0;
    if (currentIdx < 0) currentIdx = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedInvoice01,
                size: 18,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.dealOrderStatusLine(
                    (order['orderNumber'] ?? '').toString(),
                    label(status),
                  ),
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(stages.length, (i) {
              final done = i <= currentIdx;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    right: i == stages.length - 1 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: done ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          if (tracking.isNotEmpty || courier.isNotEmpty)
            Text(
              courier.isNotEmpty
                  ? l10n.dealLrLineWithCourier(
                      tracking.isNotEmpty ? tracking : '-',
                      courier,
                    )
                  : l10n.dealLrLine(tracking.isNotEmpty ? tracking : '-'),
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          if (history.isNotEmpty)
            ...history.reversed.take(3).map((h) {
              final m = (h as Map?)?.cast<String, dynamic>() ?? {};
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${label((m['status'] ?? '').toString())}',
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          Text(
            l10n.dealOrderTrackingNote,
            style: AppFonts.jakarta(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  int _quantityCount(dynamic quantity) =>
      int.tryParse(NumberFormatter.formatQuantity(quantity)) ?? 0;

  String _entryActorName(Map<String, dynamic> entry) {
    final actor = entry['actorId'];
    if (actor is Map) {
      final name =
          actor['name']?.toString() ?? actor['username']?.toString() ?? '';
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  bool _isLegacyAcceptedMessage(String message) {
    return RegExp(
      r'^accepted by\b',
      caseSensitive: false,
    ).hasMatch(message.trim());
  }

  String _platformActorLabel(String actorName) {
    return actorName.isEmpty
        ? context.l10n.dealPlatform
        : context.l10n.dealPlatformActor(actorName);
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  DateTime? _entryTime(Map<String, dynamic> entry) {
    final raw = entry['timestamp'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whether [b] continues [a]'s message group (same sender, same day, close
  /// in time, both plain messages).
  bool _continuesGroup(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return false;
    if (a['action'] != 'message' || b['action'] != 'message') return false;
    if (a['by'] != b['by']) return false;
    final ta = _entryTime(a);
    final tb = _entryTime(b);
    if (ta == null || tb == null) return ta == tb;
    return _sameDay(ta, tb) && tb.difference(ta).abs() <= _groupGap;
  }

  Widget _buildChatList(Map<String, dynamic> n) {
    final history = (n['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final entries = <Map<String, dynamic>>[...history, ..._optimisticMessages];
    final timeFormat = DateFormat(
      'h:mm a',
      Localizations.localeOf(context).languageCode,
    );

    final children = <Widget>[];
    DateTime? lastDay;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final time = _entryTime(entry);
      if (time != null && (lastDay == null || !_sameDay(lastDay, time))) {
        children.add(DealDateSeparator(label: dealDayLabel(context, time)));
        lastDay = time;
      }
      final previous = i > 0 ? entries[i - 1] : null;
      final next = i < entries.length - 1 ? entries[i + 1] : null;
      final timeText = time == null
          ? ''
          : NumberFormatter.ensureEnglishNumerals(timeFormat.format(time));

      if (entry['action'] == 'message') {
        children.add(
          _buildChatMessage(
            entry['by'] as String? ?? '',
            entry['message'] as String? ?? '',
            timeText,
            messageId: entry['messageId'] as String?,
            actorName: _entryActorName(entry),
            sending: entry['isOptimistic'] == true,
            isFirstInGroup: !_continuesGroup(previous, entry),
            isLastInGroup: !_continuesGroup(entry, next),
          ),
        );
      } else {
        children.add(_buildHistoryItem(entry, n, timeText));
      }
    }

    // Scrolling the chat folds the summary away, to give the chat the room.
    // Only the chat list itself counts (depth 0), not scrollables inside it.
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.direction != ScrollDirection.idle &&
            _summaryExpanded) {
          _autoCollapseTimer?.cancel();
          setState(() => _summaryExpanded = false);
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: children,
      ),
    );
  }

  /// A price event (requested / countered / accepted / rejected) as an offer
  /// card. Same information as before: who, what, price, total and note.
  Widget _buildHistoryItem(
    Map<String, dynamic> entry,
    Map<String, dynamic> n,
    String formattedTime,
  ) {
    final action = entry['action'] as String? ?? '';
    final by = entry['by'] as String? ?? '';
    final price = entry['pricePerUnit'];
    final total = entry['totalPrice'];
    final message = entry['message'] as String? ?? '';
    final actorName = _entryActorName(entry);
    final l10n = context.l10n;
    final productSnapshot = n['productSnapshot'] as Map<String, dynamic>? ?? {};

    IconData actionIcon;
    String actionLabel;
    ChipTone tone;

    switch (action) {
      case 'requested':
        tone = ChipTone.info;
        actionIcon = HugeIcons.strokeRoundedSent;
        actionLabel = l10n.dealStatusRequirementSent;
        break;
      case 'countered':
        tone = ChipTone.warning;
        actionIcon = HugeIcons.strokeRoundedExchange01;
        actionLabel = by == 'admin'
            ? l10n.dealStatusNewPriceFromPlatform
            : l10n.dealStatusYourCounterOffer;
        break;
      case 'accepted':
        tone = ChipTone.success;
        actionIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
        actionLabel = by == 'admin'
            ? (actorName.isNotEmpty
                  ? l10n.dealAcceptedByPlatformName(actorName)
                  : l10n.dealAcceptedByPlatform)
            : l10n.dealYouAccepted;
        break;
      case 'rejected':
        tone = ChipTone.error;
        actionIcon = HugeIcons.strokeRoundedCancelCircle;
        actionLabel = by == 'admin'
            ? l10n.dealDeclinedByPlatform
            : l10n.dealYouCancelled;
        break;
      default:
        tone = ChipTone.neutral;
        actionIcon = HugeIcons.strokeRoundedInformationCircle;
        actionLabel = action;
    }

    final isAdmin = by == 'admin';
    final showMessage =
        message.isNotEmpty &&
        !(action == 'accepted' && _isLegacyAcceptedMessage(message));
    return DealOfferCard(
      title: actionLabel,
      icon: actionIcon,
      tone: tone,
      fromPlatform: isAdmin,
      senderLabel: isAdmin
          ? _platformActorLabel(actorName)
          : context.l10n.dealYou,
      itemName: localizedName(
        context,
        productSnapshot,
        fallback: l10n.dealProductFallback,
      ),
      quantityText: dealQuantityText(
        l10n,
        productSnapshot,
        _quantityCount(n['requestedQuantity']),
      ),
      pricePerUnit: price != null ? DealDeskPresentation.rupees(price) : null,
      unitSuffix: DealDeskPresentation.unitSuffix(productSnapshot, l10n),
      total: price != null && total != null
          ? DealDeskPresentation.rupees(total)
          : null,
      message: showMessage ? message : null,
      time: formattedTime,
      // The accepted price gets the teal, dithered card.
      highlight: action == 'accepted',
    );
  }

  Widget _buildChatMessage(
    String by,
    String message,
    String timestamp, {
    String? messageId,
    String actorName = '',
    bool sending = false,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    final isAdmin = by == 'admin';
    final isRead = messageId != null
        ? _readReceipts[messageId] ?? false
        : false;

    return DealMessageBubble(
      text: message,
      outgoing: !isAdmin,
      senderLabel: isAdmin
          ? _platformActorLabel(actorName)
          : context.l10n.dealYou,
      time: timestamp,
      read: !isAdmin && isRead,
      sending: sending,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
    );
  }

  void _handleChatInputChanged(String value) {
    setState(() {});
    final user = ref.read(authProvider).user;
    if (user?.id == null) return;

    _localTypingTimer?.cancel();
    if (value.trim().isEmpty) {
      _emitStopTyping();
      return;
    }

    _isTyping = true;
    _socketService.emitTyping(
      userId: user!.id,
      username: user.name,
      userRole: 'wholesaler',
    );
    _localTypingTimer = Timer(const Duration(seconds: 3), _emitStopTyping);
  }

  void _emitStopTyping() {
    _localTypingTimer?.cancel();
    _localTypingTimer = null;
    if (!_isTyping) return;

    // Also runs from dispose(), so it uses the id saved at start.
    final userId = _userId;
    if (userId != null) {
      _socketService.emitStopTyping(userId: userId);
    }
    _isTyping = false;
  }

  Future<void> _sendChatMessage() async {
    // One message at a time; the text field stays usable meanwhile.
    if (_isSending) return;
    final messageText = _counterMessageController.text.trim();
    if (messageText.isEmpty) {
      _showError(context.l10n.dealEnterMessage);
      return;
    }

    if (messageText.length > maxMessageLength) {
      _showError(context.l10n.dealMessageTooLong('$maxMessageLength'));
      return;
    }

    _emitStopTyping();

    // Optimistic update - show message immediately
    final optimisticMessage = {
      'action': 'message',
      'by': 'wholesaler',
      'message': messageText,
      'timestamp': DateTime.now().toIso8601String(),
      'messageId': 'temp-${DateTime.now().millisecondsSinceEpoch}',
      'isOptimistic': true,
    };

    setState(() {
      _optimisticMessages.add(optimisticMessage);
      _counterMessageController.clear();
      _isSending = true;
    });

    // Auto-scroll to newest message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _scrollToBottom();
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/negotiations/${widget.negotiationId}/message',
        data: {
          'message': messageText,
          'messageId': optimisticMessage['messageId'],
        },
      );
      if (mounted) {
        await _fetchDetail(background: true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(
        e.response?.data?['message']?.toString() ??
            context.l10n.dealSendMessageFailed,
      );
      // Remove optimistic message on error
      setState(
        () => _optimisticMessages.removeWhere(
          (m) => m['messageId'] == optimisticMessage['messageId'],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Quick reply: send a ready-made message through [_sendChatMessage].
  void _sendQuickReply(String text) {
    if (_isSending) return;
    _counterMessageController.text = text;
    _sendChatMessage();
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.positions.length != 1) return;
    final target = _scrollController.position.maxScrollExtent;
    if (!animate || AppMotion.reduced(context)) {
      _scrollController.jumpTo(target);
      _settleAtBottom();
      return;
    }
    _scrollController
        .animateTo(target, duration: AppMotion.slow, curve: AppMotion.standard)
        .then((_) => _settleAtBottom());
  }

  /// The list only knows its full length once its last rows are laid out,
  /// so a scroll to "the end" can stop short. Keep following the end for a
  /// few frames until it stops moving.
  void _settleAtBottom([int tries = 6]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tries == 0 || _scrollController.positions.length != 1) {
        return;
      }
      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels > 1) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
      // The end can still move on the next frame, so keep looking.
      _settleAtBottom(tries - 1);
    });
  }

  // ---------------------------------------------------------------------------
  // Bottom bar: composer / legacy proceed / completed
  // ---------------------------------------------------------------------------

  Widget _buildBottomActions(String status, String currentOfferBy) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: _buildActionRow(status, currentOfferBy),
      ),
    );
  }

  Widget _buildActionRow(String status, String currentOfferBy) {
    if (status == 'accepted' &&
        !DealDeskPresentation.hasLinkedOrder(_negotiation ?? const {})) {
      // Accepted before orders were created on acceptance: DemoMart
      // creates the order (with delivery charges) from the admin panel.
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              color: AppColors.primaryDeep,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.dealAwaitingOrderConfirmation,
                style: AppFonts.jakarta(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDeep,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Accepted with its order: the deal is done.
    if (status == 'accepted') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              color: AppColors.primaryDeep,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.l10n.negotiationCompleted,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDeep,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Chat input for open + converted negotiations (admin confirms the order;
    // wholesalers reply through chat only)
    return _buildChatInput();
  }

  /// Declined / expired: no composer, just say why.
  Widget _buildClosedBar(Map<String, dynamic> n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedInformationCircle,
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                DealDeskPresentation.statusLabel(n, l10n: context.l10n),
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final l10n = context.l10n;
    final typingName = _typingUsers.values.isEmpty
        ? ''
        : _typingUsers.values.first;
    final typingIndicatorText = _typingUsers.isNotEmpty
        ? l10n.dealTyping(_platformActorLabel(typingName))
        : '';
    final text = _counterMessageController.text;
    final canSend = text.trim().isNotEmpty && !_isSending;
    final quickReplies = [
      l10n.dealQuickBetterPrice,
      l10n.dealQuickDeliveryTime,
      l10n.dealQuickConfirmStock,
    ];
    final duration = AppMotion.of(context, AppMotion.fast);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: duration,
          alignment: Alignment.bottomCenter,
          child: typingIndicatorText.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DealTypingIndicator(label: typingIndicatorText),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        AnimatedSize(
          duration: duration,
          alignment: Alignment.bottomCenter,
          child: text.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  // Inside the text field's tap region: tapping a chip keeps
                  // the keyboard open.
                  child: TextFieldTapRegion(
                    child: Semantics(
                      label: l10n.dealQuickRepliesLabel,
                      container: true,
                      child: SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          itemCount: quickReplies.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => _QuickReplyChip(
                            label: quickReplies[index],
                            enabled: !_isSending,
                            onTap: () => _sendQuickReply(quickReplies[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _counterMessageController,
                focusNode: _composerFocus,
                maxLines: 4,
                minLines: 1,
                maxLength: maxMessageLength,
                textCapitalization: TextCapitalization.sentences,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                onChanged: _handleChatInputChanged,
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  _emitStopTyping();
                },
                style: AppFonts.jakarta(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.dealMessageHint,
                  filled: true,
                  fillColor: AppColors.gray50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Inside the text field's tap region: sending doesn't close the
            // keyboard.
            TextFieldTapRegion(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: IconButton(
                    tooltip: l10n.dealSend,
                    onPressed: canSend
                        ? () {
                            HapticFeedback.lightImpact();
                            _sendChatMessage();
                          }
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.gray200,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    icon: AnimatedSwitcher(
                      duration: duration,
                      child: _isSending
                          ? const SizedBox(
                              key: ValueKey('sending'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textTertiary,
                              ),
                            )
                          : HugeIcon(
                              key: const ValueKey('send'),
                              icon: HugeIcons.strokeRoundedSent,
                              size: 20,
                              color: canSend
                                  ? Colors.white
                                  : AppColors.textTertiary,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 60),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${text.length}/$maxMessageLength',
                style: AppText.price(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: text.length > maxMessageLength
                      ? AppColors.error
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      haptic: true,
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.primarySoft),
        ),
        child: Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.primaryDeep : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder: summary card and a few chat bubbles.
/// Placeholder laid out like the loaded screen: the pinned summary (open,
/// as it is for the first moment), a date, an offer card from you and a reply,
/// then the composer bar at the bottom.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final card = BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.border),
    );

    Widget dot() =>
        const Skeleton(width: 16, height: 16, radius: AppRadius.pill);
    Widget line() => const Expanded(child: Skeleton(height: 3));

    final summary = Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: card,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: SkeletonShimmer(
        child: Column(
          children: [
            const Row(
              children: [
                Skeleton(width: 48, height: 48, radius: AppRadius.md),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 170, height: 15),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Skeleton(width: 48, height: 11),
                          SizedBox(width: 8),
                          Skeleton(
                            width: 110,
                            height: 20,
                            radius: AppRadius.pill,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Skeleton(width: 72, height: 15),
                    SizedBox(height: 6),
                    Skeleton(width: 52, height: 11),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: Skeleton(height: 56, radius: AppRadius.md)),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 56, radius: AppRadius.md)),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Skeleton(width: 110, height: 16),
                Spacer(),
                Skeleton(width: 84, height: 18),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [dot(), line(), dot(), line(), dot(), line(), dot()]),
          ],
        ),
      ),
    );

    final offer = Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.86,
        child: Container(
          decoration: card,
          clipBehavior: Clip.antiAlias,
          child: const SkeletonShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Skeleton(height: 34, radius: 0),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 170, height: 14),
                      SizedBox(height: 6),
                      Skeleton(width: 56, height: 11),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Skeleton(width: 60, height: 12),
                          Spacer(),
                          Skeleton(width: 80, height: 12),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Skeleton(width: 40, height: 12),
                          Spacer(),
                          Skeleton(width: 64, height: 12),
                        ],
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

    return Column(
      children: [
        summary,
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              const SkeletonShimmer(
                child: Center(
                  child: Skeleton(
                    width: 92,
                    height: 24,
                    radius: AppRadius.pill,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: SkeletonShimmer(child: Skeleton(width: 28, height: 11)),
              ),
              const SizedBox(height: 6),
              offer,
              const SizedBox(height: 14),
              const SkeletonShimmer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Skeleton(width: 200, height: 44, radius: AppRadius.lg),
                ),
              ),
            ],
          ),
        ),
        // The composer bar: quick replies above the message field.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: const SafeArea(
            top: false,
            child: SkeletonShimmer(
              child: Column(
                children: [
                  Row(
                    children: [
                      Skeleton(width: 150, height: 32, radius: AppRadius.pill),
                      SizedBox(width: 8),
                      Skeleton(width: 150, height: 32, radius: AppRadius.pill),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Skeleton(height: 44, radius: AppRadius.pill),
                      ),
                      SizedBox(width: 8),
                      Skeleton(width: 44, height: 44, radius: AppRadius.pill),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
