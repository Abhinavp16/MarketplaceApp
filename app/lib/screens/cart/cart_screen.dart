import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/config/feature_flags.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/services/shipping_address_service.dart';
import '../../widgets/cart_requirement.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';
import 'cart_parts.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isCheckingOut = false;
  bool _isValidating = false;
  // Coupon state
  String _couponCode = '';
  double _discount = 0;
  String? _appliedCouponCode;
  bool _isApplyingCoupon = false;
  String? _couponError;
  bool _couponSuccess = false;

  /// Delivery fee the server stated (coupon preview); the cart endpoint
  /// doesn't send one, so the cart's own fee is used until then.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(guestModeProvider)) {
        _refreshCartAndValidate();
      }
    });
  }

  Future<void> _refreshCartAndValidate() async {
    await ref.read(cartProvider.notifier).fetchCart();
    if (!mounted) return;
    final cart = ref.read(cartProvider);
    if (cart.items.isNotEmpty) {
      await ref.read(cartProvider.notifier).validateStock();
    }
  }

  String _fmt(double price) => NumberFormatter.formatPrice(price.round());

  String _count(num value) => NumberFormatter.formatPrice(value);

  /// Localized text for one issue returned by `POST /cart/validate`.
  String _stockIssueText(Map<String, dynamic> issue) {
    final l10n = context.l10n;
    final productId = issue['productId']?.toString();
    CartItem? cartItem;
    for (final item in ref.read(cartProvider).items) {
      if (item.productId == productId) {
        cartItem = item;
        break;
      }
    }
    final product = cartItem != null
        ? pickLocalizedName(context, cartItem.name, cartItem.nameHindi)
        : (issue['name']?.toString() ?? '');
    final available = (issue['availableStock'] as num?)?.toInt() ?? 0;
    switch (issue['type']) {
      case 'unavailable':
        return product.isEmpty
            ? l10n.cartItemUnavailable
            : l10n.cartIssueUnavailable(product);
      case 'out_of_stock':
        return product.isEmpty
            ? l10n.cartItemOutOfStock
            : l10n.cartIssueOutOfStock(product);
      case 'insufficient_stock':
        return product.isEmpty
            ? l10n.cartOnlyUnitsAvailable(available)
            : l10n.cartIssueInsufficientStock(available, product);
      case 'minimum_wholesale_quantity':
        final minimum = issue['minimumWholesaleQuantity'] as num? ?? 0;
        return product.isEmpty
            ? l10n.cartItemMinWholesale(_count(minimum))
            : l10n.cartIssueMinWholesale(product, _count(minimum));
      default:
        final message = issue['message']?.toString();
        return message != null && message.isNotEmpty && !context.isHindi
            ? message
            : l10n.cartIssueGeneric;
    }
  }

  Future<void> _applyCoupon() async {
    if (_couponCode.isEmpty) {
      setState(() {
        _couponError = context.l10n.cartCouponEnterCode;
        _couponSuccess = false;
      });
      return;
    }

    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final cart = ref.read(cartProvider);

      // Calculate subtotal
      final subtotal = cart.items.fold(0.0, (sum, item) => sum + item.total);

      // Call backend to validate coupon
      final response = await api.post(
        '/orders/preview-coupon',
        data: {'couponCode': _couponCode, 'subtotal': subtotal},
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        setState(() {
          _discount = (response.data['data']['discount'] ?? 0).toDouble();
          _appliedCouponCode = _couponCode;
          _couponSuccess = true;
          _couponError = null;
        });
      } else {
        setState(() {
          _couponError = context.isHindi
              ? context.l10n.cartCouponInvalid
              : (response.data['message']?.toString() ??
                    context.l10n.cartCouponInvalid);
          _couponSuccess = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponError = apiErrorText(
          context,
          e,
          fallback: context.l10n.cartCouponFailed,
        );
        _couponSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingCoupon = false;
        });
      }
    }
  }

  Future<void> _handleSuccessfulCheckout(
    dynamic api,
    dynamic responseData,
  ) async {
    await OrderCheckoutActionsSheet.handleSuccessfulCheckout(
      context: context,
      apiClient: api,
      responseData: responseData,
    );
  }

  Future<void> _sendRequirement() async {
    if (ref.read(cartProvider).items.isEmpty) return;
    setState(() => _isCheckingOut = true);
    final sent = await sendCartRequirement(context, ref);
    if (!mounted) return;
    setState(() => _isCheckingOut = false);
    if (sent) context.go('/home', extra: {'tab': 3});
  }

  Future<void> _proceedToCheckout() async {
    if (ref.read(guestModeProvider)) {
      _showCustomerPreviewMessage();
      return;
    }
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;
    if (!ref.read(authProvider).isAuthenticated) {
      await _showLoginRequiredPopup();
      return;
    }

    // Validate stock before checkout
    setState(() => _isValidating = true);
    final result = await ref.read(cartProvider.notifier).validateStock();
    if (!mounted) return;
    setState(() => _isValidating = false);

    final bool valid = result['valid'] ?? true;
    if (!valid) {
      final issues = (result['issues'] as List<dynamic>?) ?? [];
      _showStockIssueDialog(issues.cast<Map<String, dynamic>>());
      return;
    }

    // Show shipping address dialog
    final address = await _showAddressDialog();
    if (address == null || !mounted) return;

    setState(() => _isCheckingOut = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/orders',
        data: {
          'shippingAddress': address,
          if (_appliedCouponCode != null && _appliedCouponCode!.isNotEmpty)
            'couponCode': _appliedCouponCode,
        },
      );

      if (!mounted) return;
      setState(() => _isCheckingOut = false);

      if (response.data['success'] == true) {
        await ref
            .read(cartProvider.notifier)
            .fetchCart(); // refresh (cart cleared server-side)
        await _handleSuccessfulCheckout(api, response.data);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
      if (e.response?.statusCode == 401) {
        await _showLoginRequiredPopup();
        return;
      }
      final data = e.response?.data;
      final map = data is Map ? data : null;
      final error = map?['error'];
      final errorMap = error is Map ? error : null;
      final msg = apiErrorText(
        context,
        e,
        fallback: context.l10n.cartCheckoutFailed,
      );
      final code = map?['code']?.toString() ?? errorMap?['code']?.toString();
      // If stock issue from server, refresh cart to show updated stock
      if (code == 'INSUFFICIENT_STOCK' ||
          code == 'MIN_WHOLESALE_QUANTITY_NOT_MET') {
        await ref.read(cartProvider.notifier).fetchCart();
        await ref.read(cartProvider.notifier).validateStock();
      }
      if (!mounted) return;
      showAppSnack(context, msg, tone: SnackTone.error);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _showLoginRequiredPopup() async {
    final l10n = context.l10n;
    final shouldOpenLogin = await showConfirmDialog(
      context,
      title: l10n.cartLoginRequiredTitle,
      message: l10n.cartLoginRequiredMessage,
      confirmLabel: l10n.commonLogin,
      cancelLabel: l10n.cartNotNow,
      icon: HugeIcons.strokeRoundedUserCircle,
    );

    if (!mounted) return;
    if (shouldOpenLogin) {
      context.push('/login');
    }
  }

  Future<void> _confirmClearCart() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.cartClearTitle,
      message: l10n.cartClearMessage,
      confirmLabel: l10n.cartClearConfirm,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      icon: HugeIcons.strokeRoundedShoppingCartRemove01,
    );
    if (!confirmed || !mounted) return;
    ref.read(cartProvider.notifier).clearCart();
  }

  void _showStockIssueDialog(List<Map<String, dynamic>> issues) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.warningSoft,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 24,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.cartStockIssuesTitle,
                style: AppFonts.jakarta(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.cartStockIssuesMessage,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final issue in issues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CartNotice(
                            message: _stockIssueText(issue),
                            tone:
                                issue['type'] == 'out_of_stock' ||
                                    issue['type'] == 'unavailable'
                                ? ChipTone.error
                                : ChipTone.warning,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l10n.commonGotIt,
                size: AppButtonSize.medium,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
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
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SheetHandle(),
                        const SizedBox(height: 8),
                        Text(
                          l10n.checkoutShippingAddress,
                          style: AppFonts.jakarta(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _field(l10n.checkoutFullName, nameCtrl),
                        const SizedBox(height: 12),
                        _field(
                          l10n.checkoutPhone,
                          phoneCtrl,
                          keyboard: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _field(l10n.checkoutAddressLine1, addr1Ctrl),
                        const SizedBox(height: 12),
                        StateCityPincodeFields(
                          stateController: stateCtrl,
                          cityController: cityCtrl,
                          pincodeController: pinCtrl,
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: l10n.cartPlaceOrderRequest,
                          icon: HugeIcons.strokeRoundedSent,
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(ctx).pop({
                                'fullName': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'addressLine1': addr1Ctrl.text.trim(),
                                'city': cityCtrl.text.trim(),
                                'state': stateCtrl.text.trim(),
                                'pincode': pinCtrl.text.trim(),
                              });
                            }
                          },
                        ),
                      ],
                    ),
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
      result = address.toOrderPayload();
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    addr1Ctrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    pinCtrl.dispose();
    return result;
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
  }) {
    final requiredText = context.l10n.commonRequired;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: (v) => (v == null || v.trim().isEmpty) ? requiredText : null,
      style: AppFonts.jakarta(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _changeQuantity(CartItem item, int quantity) async {
    final l10n = context.l10n;
    final err = await ref
        .read(cartProvider.notifier)
        .updateQuantity(item.productId, quantity);
    if (err != null && mounted) {
      // The provider's message is English.
      showAppSnack(
        context,
        cartStockLimitText(l10n, item, ref.read(effectiveIsWholesalerProvider)),
        tone: SnackTone.info,
      );
    }
  }

  void _removeWithUndo(CartItem item) {
    final l10n = context.l10n;
    final notifier = ref.read(cartProvider.notifier);
    notifier.removeItem(item.productId);
    showAppSnack(
      context,
      l10n.uiItemRemoved(pickLocalizedName(context, item.name, item.nameHindi)),
      actionLabel: l10n.uiUndo,
      duration: const Duration(seconds: 5),
      onAction: () async {
        final error = await restoreCartItem(notifier, item);
        if (error != null && mounted) {
          showAppSnack(
            context,
            apiErrorText(context, error),
            tone: SnackTone.error,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(guestModeProvider)) {
      return _buildCustomerPreviewCart();
    }
    final cart = ref.watch(cartProvider);
    final l10n = context.l10n;
    final isWholesaler = ref.watch(effectiveIsWholesalerProvider);
    final count = cart.displayItemCount(isWholesaler);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(
        title: l10n.cartTitle,
        subtitle: cart.items.isEmpty ? null : l10n.commonItemsCount(count),
        actions: [
          if (cart.items.isNotEmpty)
            HeaderIconButton(
              icon: HugeIcons.strokeRoundedDelete02,
              tooltip: l10n.commonClear,
              onPressed: _confirmClearCart,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.exit,
        child: cart.isLoading && cart.items.isEmpty
            ? const SingleChildScrollView(
                key: ValueKey('loading'),
                padding: EdgeInsets.all(16),
                child: CartLinesSkeleton(),
              )
            : cart.items.isEmpty
            ? EmptyState(
                key: const ValueKey('empty'),
                icon: HugeIcons.strokeRoundedShoppingCart01,
                title: l10n.cartEmpty,
                actionLabel: l10n.cartBrowseProducts,
                onAction: () => context.go('/home'),
              )
            : KeyedSubtree(
                key: const ValueKey('content'),
                child: _buildContent(cart, isWholesaler),
              ),
      ),
    );
  }

  Widget _buildContent(CartState cart, bool isWholesaler) {
    final l10n = context.l10n;
    // Delivery is added by DemoMart when it confirms the order.
    final total = math.max(cart.subtotal - _discount, 0).toDouble();
    final savings = cartMrpSavings(cart.items) + _discount;
    final busy = _isCheckingOut || _isValidating;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCartAndValidate,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final item in cart.items) ...[
                  CartLineCard(
                    key: ValueKey(item.cartItemKey),
                    item: item,
                    isWholesaler: isWholesaler,
                    onQuantityChanged: (quantity) =>
                        _changeQuantity(item, quantity),
                    onRemove: () => _removeWithUndo(item),
                    onLimitReached: (message) =>
                        showAppSnack(context, message, tone: SnackTone.info),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!kHideOfferCouponUi) ...[
                  CartCouponField(
                    onChanged: (value) {
                      setState(() {
                        _couponCode = value.toUpperCase();
                      });
                    },
                    applying: _isApplyingCoupon,
                    onApply: _isApplyingCoupon || _couponCode.isEmpty
                        ? null
                        : _applyCoupon,
                    error: _couponError,
                    successText: _couponSuccess && _appliedCouponCode != null
                        ? l10n.cartCouponApplied(_fmt(_discount))
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                CartBillCard(
                  itemTotal: cart.subtotal,
                  discount: _discount,
                  couponCode: _appliedCouponCode,
                  total: total,
                  savings: savings,
                  itemCount: cart.displayItemCount(isWholesaler),
                ),
              ],
            ),
          ),
        ),
        CartCheckoutBar(
          total: total,
          notice: cart.hasStockIssues ? l10n.cartStockIssuesBanner : null,
          label: isWholesaler
              ? (_isCheckingOut
                    ? l10n.cartSendingRequirement
                    : l10n.productSendRequirement)
              : (_isValidating
                    ? l10n.cartCheckingStock
                    : _isCheckingOut
                    ? l10n.cartProcessing
                    : cart.hasStockIssues
                    ? l10n.cartFixStockIssues
                    : l10n.cartProceedToCheckout),
          icon: isWholesaler ? HugeIcons.strokeRoundedSent : null,
          trailingIcon: isWholesaler
              ? null
              : HugeIcons.strokeRoundedArrowRight01,
          loading: busy,
          onPressed: isWholesaler
              ? _sendRequirement
              : (cart.hasStockIssues ? null : _proceedToCheckout),
        ),
      ],
    );
  }

  Widget _buildCustomerPreviewCart() {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: l10n.cartPreviewTitle),
      body: EmptyState(
        icon: HugeIcons.strokeRoundedShoppingCart01,
        title: l10n.cartPreviewDisabled,
        message: l10n.cartPreviewPrivate,
      ),
    );
  }

  void _showCustomerPreviewMessage() {
    if (!mounted) return;
    showAppSnack(
      context,
      context.l10n.cartPreviewCheckoutDisabled,
      tone: SnackTone.info,
    );
  }
}
