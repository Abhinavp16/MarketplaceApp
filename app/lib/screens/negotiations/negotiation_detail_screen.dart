import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/config/feature_flags.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/shipping_address_service.dart';
import '../../core/services/negotiation_socket_service.dart';
import '../../core/utils/deal_desk_presentation.dart';
import '../../core/utils/number_formatter.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

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
  bool _isActioning = false;
  String? _error;
  Map<String, dynamic>? _negotiation;
  final List<Map<String, dynamic>> _optimisticMessages = [];
  final Map<String, String> _typingUsers = {}; // { userId: displayName }
  final Map<String, bool> _readReceipts = {}; // { messageId: isRead }
  final _counterMessageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  Timer? _localTypingTimer;
  Timer? _remoteTypingTimer;
  bool _isTyping = false;
  final NegotiationSocketService _socketService = NegotiationSocketService();
  int _detailRequestSequence = 0;
  bool _refreshAfterInitialLoad = false;
  static const int maxMessageLength = 280;

  static const Color primaryBlue = Color(0xFF0F766E);
  static const Color backgroundWhite = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color slateBlue = Color(0xFF4C669A);
  static const Color greenAccent = Color(0xFF16A34A);
  static const Color redAccent = Color(0xFFDC2626);
  static const Color amberAccent = Color(0xFFF59E0B);
  static const Color incomingBubble = Color(0xFFFFFFFF);
  static const Color outgoingBubble = Color(0xFFD9FDD3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDetail();
    _initializeSocket();
    // The REST response remains canonical. Keep a short fallback refresh even
    // when Socket.IO reports connected because a stale room subscription can
    // otherwise leave this screen unchanged until it is reopened.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _fetchDetail(background: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _fetchDetail(background: true);
    }
  }

  void _initializeSocket() {
    final auth = ref.read(authProvider);

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
          // Empty name -> shown as the localized platform label.
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
    _localTypingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    _emitStopTyping();
    _counterMessageController.dispose();
    _scrollController.dispose();

    // Disconnect from socket
    final auth = ref.read(authProvider);
    if (auth.user?.id != null) {
      _socketService.leaveNegotiation(
        userId: auth.user!.id,
        userRole: 'wholesaler',
      );
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
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _scrollToBottom();
          });
        }
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
  // and reject are admin/member actions performed from the admin panel, so the
  // corresponding app actions were removed. _proceedToOrder below is kept as a
  // legacy fallback for negotiations accepted before order auto-creation.
  Future<void> _proceedToOrder() async {
    debugPrint('_proceedToOrder called for ${widget.negotiationId}');
    try {
      final checkoutData = await _showAddressDialog();
      debugPrint('Address dialog returned: $checkoutData');
      if (checkoutData == null || !mounted) return;

      final address = Map<String, String>.from(checkoutData);
      final couponCode = (address.remove('couponCode') ?? '').trim();
      final payload = <String, dynamic>{
        'negotiationId': widget.negotiationId,
        'shippingAddress': address,
      };
      if (couponCode.isNotEmpty) {
        payload['couponCode'] = couponCode.toUpperCase();
      }

      setState(() => _isActioning = true);
      try {
        final api = ref.read(apiClientProvider);
        final response = await api.post(
          '/orders/from-negotiation',
          data: payload,
        );

        if (!mounted) return;
        if (response.data['success'] == true) {
          await OrderCheckoutActionsSheet.handleSuccessfulCheckout(
            context: context,
            apiClient: api,
            responseData: response.data,
          );
        }
      } on DioException catch (e) {
        if (mounted) {
          _showError(
            e.response?.data?['message']?.toString() ??
                context.l10n.dealCreateOrderFailed,
          );
        }
      } finally {
        if (mounted) setState(() => _isActioning = false);
      }
    } catch (e) {
      debugPrint('_proceedToOrder error: $e');
      if (mounted) _showError(context.l10n.dealErrorWithDetails('$e'));
    }
  }

  Future<Map<String, String>?> _showAddressDialog() async {
    final savedAddress = await ShippingAddressService.getSelectedAddress();
    if (!mounted) return null;
    final auth = ref.read(authProvider);
    final nameCtrl = TextEditingController(
      text: savedAddress?.fullName ?? auth.user?.name ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: savedAddress?.phone ?? auth.user?.phone ?? '',
    );
    final addr1Ctrl = TextEditingController(
      text: savedAddress?.addressLine1 ?? '',
    );
    final cityCtrl = TextEditingController(text: savedAddress?.city ?? '');
    final stateCtrl = TextEditingController(text: savedAddress?.state ?? '');
    final pinCtrl = TextEditingController(text: savedAddress?.pincode ?? '');
    final couponCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final l10n = context.l10n;

    Map<String, String>? result =
        await showModalBottomSheet<Map<String, String>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
            decoration: const BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: borderLight,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Text(
                        l10n.dealShippingAddressTitle,
                        style: AppFonts.jakarta(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _addrField(l10n.dealFieldFullName, nameCtrl),
                      const SizedBox(height: 12),
                      _addrField(
                        l10n.dealFieldPhone,
                        phoneCtrl,
                        keyboard: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _addrField(l10n.dealFieldAddressLine1, addr1Ctrl),
                      const SizedBox(height: 12),
                      StateCityPincodeFields(
                        stateController: stateCtrl,
                        cityController: cityCtrl,
                        pincodeController: pinCtrl,
                      ),
                      if (!kHideOfferCouponUi) ...[
                        const SizedBox(height: 12),
                        _addrField(
                          l10n.dealFieldCouponCode,
                          couponCtrl,
                          required: false,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(ctx).pop({
                                'fullName': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'addressLine1': addr1Ctrl.text.trim(),
                                'city': cityCtrl.text.trim(),
                                'state': stateCtrl.text.trim(),
                                'pincode': pinCtrl.text.trim(),
                                'couponCode': couponCtrl.text
                                    .trim()
                                    .toUpperCase(),
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: greenAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.dealConfirmAndProceed,
                            style: AppFonts.jakarta(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    if (result != null) {
      final address = ShippingAddress(
        id: savedAddress?.id ?? ShippingAddress.generateId(),
        slot: savedAddress?.slot ?? ShippingAddressService.slotPrimary,
        fullName: result['fullName'] ?? '',
        phone: result['phone'] ?? '',
        addressLine1: result['addressLine1'] ?? '',
        city: result['city'] ?? '',
        state: result['state'] ?? '',
        pincode: result['pincode'] ?? '',
      );
      await ShippingAddressService.upsertAddress(address);
      await ShippingAddressService.setSelectedAddressId(address.id);
      result = {
        ...address.toOrderPayload(),
        'couponCode': result['couponCode'] ?? '',
      };
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    addr1Ctrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    pinCtrl.dispose();
    couponCtrl.dispose();
    return result;
  }

  Widget _addrField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
                ? context.l10n.commonRequired
                : null
          : null,
      style: AppFonts.jakarta(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppFonts.jakarta(fontSize: 13, color: textMuted),
        filled: true,
        fillColor: backgroundWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppFonts.jakarta(fontWeight: FontWeight.w600),
        ),
        backgroundColor: redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // NOTE: counter sheet removed — wholesalers reply through chat messages only.

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundWhite,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                )
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: AppFonts.jakarta(color: textMuted)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _fetchDetail,
                        child: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = context.l10n;
    final timeFormat = DateFormat(
      'h:mm a',
      Localizations.localeOf(context).languageCode,
    );
    final n = _negotiation!;
    final status = n['status'] as String? ?? 'pending';
    final productSnapshot = n['productSnapshot'] as Map<String, dynamic>? ?? {};
    final history = (n['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final quantity = n['requestedQuantity'] ?? 0;
    final currentPrice = n['currentPricePerUnit'] ?? 0;
    final currentTotal = n['currentTotalPrice'] ?? 0;
    final currentOfferBy = n['currentOfferBy'] as String? ?? '';
    final negotiationNumber = n['negotiationNumber'] as String? ?? '';
    final imageUrl = productSnapshot['image'] as String? ?? '';
    final productName = localizedName(
      context,
      productSnapshot,
      fallback: l10n.dealProductFallback,
    );
    final originalPrice = productSnapshot['price'] ?? 0;
    final canPay = n['canPay'] == true;
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

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
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
                  negotiationNumber.isNotEmpty
                      ? negotiationNumber
                      : l10n.negotiationTitleFallback,
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDetail,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Product Card
                Container(
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderLight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      if (imageUrl.isNotEmpty)
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: backgroundWhite),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: AppFonts.jakarta(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.dealRetailPrice(
                                  NumberFormatter.formatPrice(originalPrice),
                                ),
                                style: AppFonts.jakarta(
                                  fontSize: 13,
                                  color: slateBlue,
                                ),
                              ),
                              Text(
                                l10n.dealQtyUnits(_quantityCount(quantity)),
                                style: AppFonts.jakarta(
                                  fontSize: 13,
                                  color: slateBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Optional buyer message / delivery requirement
                if ((n['message']?.toString().trim() ?? '').isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.negotiationBuyerMessage,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: slateBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['message'].toString().trim(),
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            color: textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Current Status Card
                _buildStatusCard(
                  n,
                  status,
                  currentPrice,
                  currentTotal,
                  currentOfferBy,
                  quantity,
                ),
                if (approvedByLabel != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: greenAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            approvedByLabel,
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: greenAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (orderId != null && orderId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/tracking/$orderId'),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text(
                        orderNumber.isNotEmpty
                            ? l10n.dealViewOrderNumber(orderNumber)
                            : l10n.dealViewOrder,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        side: BorderSide(color: primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOrderTrackingCard(
                    orderRef is Map
                        ? Map<String, dynamic>.from(orderRef as Map)
                        : null,
                  ),
                ],
                const SizedBox(height: 20),

                // History Timeline
                Text(
                  l10n.dealChatAndHistory,
                  style: AppFonts.jakarta(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                  child: Column(
                    children: [
                      ...history.map((entry) {
                        if (entry['action'] == 'message') {
                          return _buildChatMessage(
                            entry['by'] as String,
                            entry['message'] as String,
                            entry['timestamp'] != null
                                ? timeFormat.format(
                                    DateTime.parse(
                                      entry['timestamp'] as String,
                                    ),
                                  )
                                : '',
                            messageId: entry['messageId'] as String?,
                            actorName: _entryActorName(entry),
                          );
                        }
                        return _buildHistoryItem(entry);
                      }),
                      ..._optimisticMessages.map(
                        (msg) => _buildChatMessage(
                          msg['by'] as String,
                          msg['message'] as String,
                          timeFormat.format(
                            DateTime.parse(msg['timestamp'] as String),
                          ),
                          messageId: msg['messageId'] as String?,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Bottom Action Bar — chat stays open on converted orders so the
        // wholesaler can follow up; only closed states hide it.
        if (!['rejected', 'expired'].contains(status))
          _buildBottomActions(status, currentOfferBy, canPay),
      ],
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
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: primaryBlue,
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
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
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
                    color: done ? greenAccent : borderLight,
                    borderRadius: BorderRadius.circular(100),
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
              style: AppFonts.jakarta(fontSize: 12, color: slateBlue),
            ),
          if (history.isNotEmpty)
            ...history.reversed.take(3).map((h) {
              final m = (h as Map?)?.cast<String, dynamic>() ?? {};
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${label((m['status'] ?? '').toString())}',
                  style: AppFonts.jakarta(fontSize: 11, color: textMuted),
                ),
              );
            }),
          const SizedBox(height: 4),
          Text(
            l10n.dealOrderTrackingNote,
            style: AppFonts.jakarta(fontSize: 11, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    Map<String, dynamic> negotiation,
    String status,
    dynamic currentPrice,
    dynamic currentTotal,
    String currentOfferBy,
    dynamic quantity,
  ) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    final l10n = context.l10n;
    final orderStatusLabel = DealDeskPresentation.orderStatusLabel(
      negotiation,
      l10n: l10n,
    );

    switch (status) {
      case 'pending':
        statusColor = textMuted;
        statusLabel = l10n.dealStatusRequirementSent;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'countered':
        statusColor = amberAccent;
        statusLabel = currentOfferBy == 'admin'
            ? l10n.dealStatusNewPriceFromPlatform
            : l10n.dealStatusYourCounterOffer;
        statusIcon = Icons.swap_horiz_rounded;
        break;
      case 'accepted':
        statusColor = greenAccent;
        statusLabel = orderStatusLabel ?? l10n.statusDealAcceptedOrderPending;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'converted':
        statusColor = greenAccent;
        statusLabel = orderStatusLabel ?? l10n.statusDealOrderCreated;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = redAccent;
        statusLabel = l10n.dealStatusRequirementDeclined;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'expired':
        statusColor = textMuted;
        statusLabel = l10n.dealStatusRequirementExpired;
        statusIcon = Icons.info_outline;
        break;
      default:
        statusColor = textMuted;
        statusLabel = status.toUpperCase();
        statusIcon = Icons.info_outline;
    }
    statusLabel = orderStatusLabel ?? statusLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: AppFonts.jakarta(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dealCurrentPricePerUnit,
                style: AppFonts.jakarta(fontSize: 13, color: slateBlue),
              ),
              Text(
                '₹${NumberFormatter.formatPrice(currentPrice)}',
                style: AppFonts.jakarta(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dealTotalForUnits(_quantityCount(quantity)),
                style: AppFonts.jakarta(fontSize: 13, color: slateBlue),
              ),
              Text(
                '₹${NumberFormatter.formatPrice(currentTotal)}',
                style: AppFonts.jakarta(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
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

  Widget _buildHistoryItem(Map<String, dynamic> entry) {
    final action = entry['action'] as String? ?? '';
    final by = entry['by'] as String? ?? '';
    final price = entry['pricePerUnit'];
    final total = entry['totalPrice'];
    final message = entry['message'] as String? ?? '';
    final timestamp = entry['timestamp'] as String? ?? '';
    final actorName = _entryActorName(entry);
    final l10n = context.l10n;

    String formattedTime = '';
    if (timestamp.isNotEmpty) {
      try {
        formattedTime = DateFormat(
          'MMM d, h:mm a',
          Localizations.localeOf(context).languageCode,
        ).format(DateTime.parse(timestamp));
      } catch (_) {}
    }

    // Handle chat messages differently
    if (action == 'message') {
      return _buildChatMessage(
        by,
        message,
        formattedTime,
        actorName: actorName,
      );
    }

    Color accentColor;
    IconData actionIcon;
    String actionLabel;

    switch (action) {
      case 'requested':
        accentColor = primaryBlue;
        actionIcon = Icons.send_rounded;
        actionLabel = l10n.dealStatusRequirementSent;
        break;
      case 'countered':
        accentColor = amberAccent;
        actionIcon = Icons.swap_horiz_rounded;
        actionLabel = by == 'admin'
            ? l10n.dealStatusNewPriceFromPlatform
            : l10n.dealStatusYourCounterOffer;
        break;
      case 'accepted':
        accentColor = greenAccent;
        actionIcon = Icons.check_circle_rounded;
        actionLabel = by == 'admin'
            ? (actorName.isNotEmpty
                  ? l10n.dealAcceptedByPlatformName(actorName)
                  : l10n.dealAcceptedByPlatform)
            : l10n.dealYouAccepted;
        break;
      case 'rejected':
        accentColor = redAccent;
        actionIcon = Icons.cancel_rounded;
        actionLabel = by == 'admin'
            ? l10n.dealDeclinedByPlatform
            : l10n.dealYouCancelled;
        break;
      default:
        accentColor = textMuted;
        actionIcon = Icons.circle;
        actionLabel = action;
    }

    final isAdmin = by == 'admin';
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.84,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
          decoration: BoxDecoration(
            color: isAdmin ? incomingBubble : outgoingBubble,
            borderRadius: _chatBubbleRadius(isAdmin),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin
                    ? _platformActorLabel(actorName)
                    : context.l10n.dealYou,
                style: AppFonts.jakarta(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isAdmin ? primaryBlue : greenAccent,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(actionIcon, size: 15, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      actionLabel,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (price != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  children: [
                    Text(
                      l10n.commonPricePerUnit(
                        NumberFormatter.formatPrice(price),
                      ),
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    if (total != null)
                      Text(
                        l10n.dealBulletTotal(
                          NumberFormatter.formatPrice(total),
                        ),
                        style: AppFonts.jakarta(fontSize: 12, color: slateBlue),
                      ),
                  ],
                ),
              ],
              if (message.isNotEmpty &&
                  !(action == 'accepted' &&
                      _isLegacyAcceptedMessage(message))) ...[
                const SizedBox(height: 5),
                Text(
                  message,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    color: textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
              if (formattedTime.isNotEmpty) ...[
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formattedTime,
                    style: AppFonts.jakarta(
                      fontSize: 9.5,
                      color: const Color(0xFF667781),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius _chatBubbleRadius(bool isAdmin) {
    return BorderRadius.only(
      topLeft: Radius.circular(isAdmin ? 4 : 14),
      topRight: Radius.circular(isAdmin ? 14 : 4),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
  }

  Widget _buildChatMessage(
    String by,
    String message,
    String timestamp, {
    String? messageId,
    String actorName = '',
  }) {
    final isAdmin = by == 'admin';
    final isRead = messageId != null
        ? _readReceipts[messageId] ?? false
        : false;

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.78,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(11, 8, 9, 6),
          decoration: BoxDecoration(
            color: isAdmin ? incomingBubble : outgoingBubble,
            borderRadius: _chatBubbleRadius(isAdmin),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin
                    ? _platformActorLabel(actorName)
                    : context.l10n.dealYou,
                style: AppFonts.jakarta(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isAdmin ? primaryBlue : greenAccent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  height: 1.35,
                ),
              ),
              if (timestamp.isNotEmpty || (!isAdmin && isRead)) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timestamp.isNotEmpty)
                        Text(
                          timestamp,
                          style: AppFonts.jakarta(
                            fontSize: 9.5,
                            color: const Color(0xFF667781),
                          ),
                        ),
                      if (!isAdmin && isRead) ...[
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Color(0xFF53BDEB),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      _socketService.emitStopTyping(userId: userId);
    }
    _isTyping = false;
  }

  Future<void> _sendChatMessage() async {
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
    });

    // Auto-scroll to newest message
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });

    setState(() => _isActioning = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.dealMessageSent,
              style: AppFonts.jakarta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
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
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildBottomActions(
    String status,
    String currentOfferBy,
    bool canPay,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        border: const Border(top: BorderSide(color: borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(child: _buildActionRow(status, currentOfferBy, canPay)),
    );
  }

  Widget _buildActionRow(String status, String currentOfferBy, bool canPay) {
    if (status == 'accepted' && canPay) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _proceedToOrder,
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
          label: Text(
            context.l10n.commonViewDetails,
            style: AppFonts.jakarta(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: greenAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (status == 'accepted') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: greenAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              context.l10n.negotiationCompleted,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: greenAccent,
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

  Widget _buildChatInput() {
    final typingName = _typingUsers.values.isEmpty
        ? ''
        : _typingUsers.values.first;
    final typingIndicatorText = _typingUsers.isNotEmpty
        ? context.l10n.dealTyping(_platformActorLabel(typingName))
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (typingIndicatorText.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: backgroundWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: greenAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    typingIndicatorText,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      color: slateBlue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _counterMessageController,
                enabled: !_isActioning,
                maxLines: 3,
                minLines: 1,
                maxLength: maxMessageLength,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.dealMessageHint,
                  prefixIcon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 19,
                    color: textMuted,
                  ),
                  hintStyle: AppFonts.jakarta(color: textMuted),
                  filled: true,
                  fillColor: backgroundWhite,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: greenAccent, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: borderLight),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed:
                    (_isActioning || _counterMessageController.text.isEmpty)
                    ? null
                    : _sendChatMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: textMuted.withOpacity(0.3),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: _isActioning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_counterMessageController.text.length}/$maxMessageLength',
            style: AppFonts.jakarta(
              fontSize: 11,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
