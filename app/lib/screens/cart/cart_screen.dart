import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/config/feature_flags.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/services/shipping_address_service.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';

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

  String _rupees(double price) => context.l10n.commonRupees(_fmt(price));

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

  /// Localized text for the stock problem shown under a cart item.
  String _itemIssueText(CartItem item, int minimumQuantity) {
    final l10n = context.l10n;
    if (item.stock == 0) return l10n.cartItemOutOfStock;
    if (item.quantity < minimumQuantity) {
      return l10n.cartItemMinWholesale(_count(minimumQuantity));
    }
    if (item.quantity > item.stock) {
      return l10n.cartItemOnlyAvailable(
        _count(item.stock),
        _count(item.quantity),
      );
    }
    return l10n.cartItemOnlyStockAvailable(_count(item.stock));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _showLoginRequiredPopup() async {
    final shouldOpenLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.cartLoginRequiredTitle),
          content: Text(l10n.cartLoginRequiredMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cartNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonLogin),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (shouldOpenLogin == true) {
      context.push('/login');
    }
  }

  void _showStockIssueDialog(List<Map<String, dynamic>> issues) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.cartStockIssuesTitle,
              style: AppFonts.jakarta(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cartStockIssuesMessage,
              style: AppFonts.jakarta(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      issue['type'] == 'out_of_stock' ||
                              issue['type'] == 'unavailable'
                          ? Icons.cancel_rounded
                          : Icons.error_rounded,
                      color:
                          issue['type'] == 'out_of_stock' ||
                              issue['type'] == 'unavailable'
                          ? AppColors.error
                          : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _stockIssueText(issue),
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonGotIt,
              style: AppFonts.jakarta(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
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
              color: Colors.white,
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
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Text(
                        l10n.checkoutShippingAddress,
                        style: AppFonts.jakarta(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.checkoutConfirmAndPay,
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppFonts.jakarta(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.gray50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(guestModeProvider)) {
      return _buildCustomerPreviewCart();
    }
    final cart = ref.watch(cartProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        ),
        title: Text(
          l10n.cartTitle,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              onPressed: () => ref.read(cartProvider.notifier).clearCart(),
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
      body: cart.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppColors.gray300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.cartEmpty,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      l10n.cartBrowseProducts,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshCartAndValidate,
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.gray50),
                      itemBuilder: (_, i) => _buildCartItem(cart.items[i]),
                    ),
                  ),
                ),

                // Price Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.gray200)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.cartPriceSummary,
                          style: AppFonts.jakarta(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPriceRow(
                          l10n.commonSubtotal,
                          _rupees(cart.subtotal),
                        ),
                        const SizedBox(height: 8),
                        _buildPriceRow(
                          l10n.cartDeliveryFee,
                          _rupees(cart.deliveryFee),
                        ),
                        if (_discount > 0) ...[
                          const SizedBox(height: 8),
                          _buildPriceRow(
                            l10n.cartDiscount,
                            l10n.cartMinusRupees(_fmt(_discount)),
                            isDiscount: true,
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.gray100),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.cartGrandTotal,
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _rupees(cart.grandTotal - _discount),
                              style: AppFonts.jakarta(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        if (!kHideOfferCouponUi) ...[
                          const SizedBox(height: 16),

                          // Coupon Input Row
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gray300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_offer_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _couponCode = value.toUpperCase();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: l10n.cartCouponHint,
                                      hintStyle: AppFonts.jakarta(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppColors.gray300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppColors.gray300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    style: AppFonts.jakarta(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isApplyingCoupon || _couponCode.isEmpty
                                        ? null
                                        : _applyCoupon,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isApplyingCoupon
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            l10n.commonApply,
                                            style: AppFonts.jakarta(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Coupon message
                          if (_couponError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _couponError!,
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          if (_couponSuccess && _appliedCouponCode != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.cartCouponApplied(_fmt(_discount)),
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],

                        const SizedBox(height: 20),
                        if (cart.hasStockIssues)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange.shade700,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.cartStockIssuesBanner,
                                      style: AppFonts.jakarta(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                (_isCheckingOut ||
                                    _isValidating ||
                                    cart.hasStockIssues)
                                ? null
                                : _proceedToCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cart.hasStockIssues
                                  ? AppColors.gray300
                                  : AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.gray300,
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: (_isCheckingOut || _isValidating)
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isValidating
                                            ? l10n.cartCheckingStock
                                            : l10n.cartProcessing,
                                        style: AppFonts.jakarta(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        cart.hasStockIssues
                                            ? l10n.cartFixStockIssues
                                            : l10n.cartProceedToCheckout,
                                        style: AppFonts.jakarta(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerPreviewCart() {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        ),
        title: Text(
          l10n.cartPreviewTitle,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 68,
                color: AppColors.primary,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.cartPreviewDisabled,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.cartPreviewPrivate,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerPreviewMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cartPreviewCheckoutDisabled)),
    );
  }

  Widget _buildCartItem(CartItem item) {
    final hasIssue = item.hasStockIssue;
    final isOutOfStock = item.stock == 0;
    final bool atStockLimit = item.stock > 0 && item.quantity >= item.stock;
    final isWholesaler = ref.watch(authProvider).user?.isWholesaler == true;
    final minimumQuantity = isWholesaler ? item.minWholesaleQuantity : 1;
    final isAtMinimum = item.quantity <= minimumQuantity;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: hasIssue ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hasIssue
            ? Border.all(color: Colors.red.shade200, width: 1)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.image != null
                      ? CachedNetworkImage(
                          imageUrl: item.image!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.gray100,
                            width: 72,
                            height: 72,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.gray100,
                            width: 72,
                            height: 72,
                            child: const Icon(Icons.image),
                          ),
                        )
                      : Container(
                          color: AppColors.gray100,
                          width: 72,
                          height: 72,
                          child: const Icon(Icons.image),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickLocalizedName(context, item.name, item.nameHindi),
                        style: AppFonts.jakarta(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rupees(item.price),
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (item.stock > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l10n.cartInStockCount(_count(item.stock)),
                            style: AppFonts.jakarta(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: item.stock <= 5
                                  ? Colors.orange.shade700
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isOutOfStock)
                  Container(
                    decoration: BoxDecoration(
                      color: hasIssue ? Colors.red.shade100 : AppColors.gray100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: isAtMinimum
                              ? null
                              : () => ref
                                    .read(cartProvider.notifier)
                                    .updateQuantity(
                                      item.productId,
                                      item.quantity - 1,
                                    ),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: Text(
                              '-',
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isAtMinimum
                                    ? AppColors.gray300
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}',
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: hasIssue
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: atStockLimit
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.cartOnlyUnitsAvailable(item.stock),
                                        style: AppFonts.jakarta(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                }
                              : () async {
                                  final err = await ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(
                                        item.productId,
                                        item.quantity < minimumQuantity
                                            ? minimumQuantity
                                            : item.quantity + 1,
                                      );
                                  if (err != null && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        // The provider's message is English.
                                        content: Text(
                                          l10n.cartOnlyUnitsAvailable(
                                            item.stock,
                                          ),
                                          style: AppFonts.jakarta(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                  }
                                },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: Text(
                              '+',
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: atStockLimit
                                    ? AppColors.gray300
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isOutOfStock)
                  IconButton(
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .removeItem(item.productId),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
              ],
            ),
            // Stock issue message
            if (hasIssue)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOutOfStock
                            ? Icons.cancel_rounded
                            : Icons.warning_amber_rounded,
                        color: isOutOfStock
                            ? AppColors.error
                            : Colors.orange.shade800,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _itemIssueText(item, minimumQuantity),
                          style: AppFonts.jakarta(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock
                                ? AppColors.error
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      if (!isOutOfStock && item.stock > 0)
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(cartProvider.notifier)
                                .updateQuantity(item.productId, item.stock);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.cartSetQuantity(_count(item.stock)),
                              style: AppFonts.jakarta(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    Color? valueColor,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.jakarta(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppFonts.jakarta(
            fontSize: 14,
            fontWeight: isDiscount ? FontWeight.w600 : FontWeight.w500,
            color: isDiscount
                ? AppColors.success
                : (valueColor ?? AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
