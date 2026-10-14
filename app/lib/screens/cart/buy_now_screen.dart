import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/services/shipping_address_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';
import 'cart_parts.dart';

class BuyNowScreen extends ConsumerStatefulWidget {
  final String productId;
  final String productName;
  final String? productImage;
  final double price;
  final double? mrp;
  final int quantity;
  final int stock;

  const BuyNowScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.price,
    this.mrp,
    required this.quantity,
    this.stock = 99,
  });

  @override
  ConsumerState<BuyNowScreen> createState() => _BuyNowScreenState();
}

class _BuyNowScreenState extends ConsumerState<BuyNowScreen> {
  bool _isCheckingOut = false;

  // Address state
  List<ShippingAddress> _savedAddresses = [];
  String _selectedAddressId = '';
  String _fullAddress = '';
  String _name = '';
  String _phone = '';
  String _addressLine1 = '';
  String _city = '';
  String _state = '';
  String _pincode = '';

  @override
  void initState() {
    super.initState();
    if (!ref.read(guestModeProvider)) {
      _loadSavedAddresses();
    }
  }

  Future<void> _loadSavedAddresses() async {
    final addresses = await ShippingAddressService.getAddresses();
    if (!mounted) return;

    // Determine which address to select
    ShippingAddress? addressToSelect;
    if (addresses.isNotEmpty) {
      final primary = addresses.where((a) => a.slot == 'primary').toList();
      addressToSelect = primary.isNotEmpty ? primary.first : addresses.first;
    }

    if (!mounted) return;

    setState(() {
      _savedAddresses = addresses;
    });

    // Select address after setState completes
    if (addressToSelect != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectAddress(addressToSelect!);
        }
      });
    }
  }

  void _selectAddress(ShippingAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _name = address.fullName;
      _phone = address.phone;
      _addressLine1 = address.addressLine1;
      _city = address.city;
      _state = address.state;
      _pincode = address.pincode;
      _fullAddress =
          '${address.addressLine1}, ${address.city}, ${address.state} - ${address.pincode}';
    });
  }

  double get _itemTotal => widget.price * widget.quantity;

  double get _mrpSavings {
    final mrp = widget.mrp;
    if (mrp == null || mrp <= widget.price) return 0;
    return (mrp - widget.price) * widget.quantity;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (ref.watch(guestModeProvider)) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(title: l10n.buyNowPreviewTitle),
        body: EmptyState(
          icon: HugeIcons.strokeRoundedShoppingCart01,
          title: l10n.buyNowPreviewTitle,
          message: l10n.buyNowPreviewDisabled,
          tone: ChipTone.neutral,
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: l10n.buyNowTitle),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildProductCard(),
                const SizedBox(height: 12),
                CartAddressCard(
                  name: _name,
                  phone: _phone,
                  address: _fullAddress,
                  onTap: _showAddressSelectionDialog,
                ),
                const SizedBox(height: 12),
                CartBillCard(
                  itemTotal: _itemTotal,
                  // DemoMart adds delivery when it confirms the order.
                  total: _itemTotal,
                  savings: _mrpSavings,
                ),
              ],
            ),
          ),
          CartCheckoutBar(
            total: _itemTotal,
            label: l10n.cartPlaceOrderRequest,
            icon: HugeIcons.strokeRoundedSent,
            loading: _isCheckingOut,
            onPressed: _canProceed() || _isCheckingOut
                ? _proceedToCheckout
                : null,
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    return _fullAddress.isNotEmpty &&
        _name.isNotEmpty &&
        _phone.isNotEmpty &&
        !_isCheckingOut;
  }

  Widget _buildProductCard() {
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AppImage(
                imageUrl: widget.productImage ?? '',
                category: '',
                name: widget.productName,
                width: 72,
                height: 72,
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
                  widget.productName
                      .split(' ')
                      .map((word) {
                        if (word.isEmpty) return word;
                        return word[0].toUpperCase() +
                            word.substring(1).toLowerCase();
                      })
                      .join(' '),
                  style: AppFonts.jakarta(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                PriceView(
                  price: widget.price,
                  mrp: widget.mrp,
                  size: 16,
                  offLabel: (percent) => l10n.commonPercentOff('$percent'),
                ),
                const SizedBox(height: 6),
                StatusChip(
                  label: l10n.commonQtyValue(
                    NumberFormatter.formatPrice(widget.quantity),
                  ),
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Not reachable from the UI today; kept with the other address helpers.
  Future<void> _showAddressDialog() async {
    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone);
    final address1Controller = TextEditingController(text: _addressLine1);
    final cityController = TextEditingController(text: _city);
    final stateController = TextEditingController(text: _state);
    final pinController = TextEditingController(text: _pincode);
    final formKey = GlobalKey<FormState>();
    final l10n = context.l10n;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    _buildAddressField(
                      l10n.checkoutFullName,
                      nameController,
                      TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    _buildAddressField(
                      l10n.checkoutPhone,
                      phoneController,
                      TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildAddressField(
                      l10n.checkoutAddressLine1,
                      address1Controller,
                      TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    StateCityPincodeFields(
                      stateController: stateController,
                      cityController: cityController,
                      pincodeController: pinController,
                    ),
                    const SizedBox(height: 20),
                    // This sheet only saves the address; it doesn't order.
                    AppButton(
                      label: l10n.addressSaveButton,
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.of(ctx).pop({
                            'fullName': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'addressLine1': address1Controller.text.trim(),
                            'city': cityController.text.trim(),
                            'state': stateController.text.trim(),
                            'pincode': pinController.text.trim(),
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

    // Dispose controllers first
    nameController.dispose();
    phoneController.dispose();
    address1Controller.dispose();
    cityController.dispose();
    stateController.dispose();
    pinController.dispose();

    if (result != null) {
      final existingIndex = _savedAddresses.indexWhere(
        (address) => address.id == _selectedAddressId,
      );
      final existing = existingIndex >= 0
          ? _savedAddresses[existingIndex]
          : null;
      final savedAddress = ShippingAddress(
        id: existing?.id ?? ShippingAddress.generateId(),
        slot: existing?.slot ?? ShippingAddressService.slotPrimary,
        fullName: result['fullName'] ?? '',
        phone: result['phone'] ?? '',
        addressLine1: result['addressLine1'] ?? '',
        city: result['city'] ?? '',
        state: result['state'] ?? '',
        pincode: result['pincode'] ?? '',
      );
      await ShippingAddressService.upsertAddress(savedAddress);
      await ShippingAddressService.setSelectedAddressId(savedAddress.id);
      await _loadSavedAddresses();
      if (!mounted) return;
      _selectAddress(savedAddress);
    }
  }

  Widget _buildAddressField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? context.l10n.commonRequired : null,
      style: AppFonts.jakarta(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _showAddressSelectionDialog() async {
    // Refresh addresses first
    await _loadSavedAddresses();

    if (!mounted) return;

    if (_savedAddresses.isEmpty) {
      // No saved addresses, navigate to address screen to add new
      context.push('/addresses').then((_) => _loadSavedAddresses());
      return;
    }

    final l10n = context.l10n;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.buyNowSelectAddress,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to address screen to add new address
                        context.push('/addresses').then((_) {
                          // Reload addresses after returning
                          _loadSavedAddresses();
                        });
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(l10n.buyNowAddNewAddress),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final address in _savedAddresses) ...[
                  _AddressOption(
                    address: address,
                    selected: _selectedAddressId == address.id,
                    primaryLabel: l10n.buyNowPrimaryAddress,
                    phoneText: l10n.checkoutPhoneValue(address.phone),
                    onTap: () => Navigator.pop(context, address.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      final selectedAddress = _savedAddresses.firstWhere((a) => a.id == result);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectAddress(selectedAddress);
        }
      });
    }
  }

  Future<void> _showLoginRequiredPopup() async {
    final l10n = context.l10n;
    final shouldOpenLogin = await showConfirmDialog(
      context,
      title: l10n.cartLoginRequiredTitle,
      message: l10n.buyNowLoginRequiredMessage,
      confirmLabel: l10n.commonLogin,
      cancelLabel: l10n.cartNotNow,
      icon: HugeIcons.strokeRoundedUserCircle,
    );

    if (!mounted) return;
    if (shouldOpenLogin) {
      context.push('/login');
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
    if (ref.read(guestModeProvider)) return;
    if (!_canProceed()) return;
    if (!ref.read(authProvider).isAuthenticated) {
      await _showLoginRequiredPopup();
      return;
    }

    setState(() => _isCheckingOut = true);

    try {
      final api = ref.read(apiClientProvider);

      final address = {
        'fullName': _name,
        'phone': _phone,
        'addressLine1': _addressLine1.isNotEmpty ? _addressLine1 : _fullAddress,
        'city': _city,
        'state': _state,
        'pincode': _pincode,
      };

      final response = await api.post(
        '/orders',
        data: {
          'items': [
            {'productId': widget.productId, 'quantity': widget.quantity},
          ],
          'shippingAddress': address,
        },
      );

      if (!mounted) return;
      setState(() => _isCheckingOut = false);

      if (response.data['success'] == true) {
        await _handleSuccessfulCheckout(api, response.data);
      } else {
        showAppSnack(
          context,
          response.data['message']?.toString() ??
              context.l10n.buyNowOrderFailed,
          tone: SnackTone.error,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);

      final msg = apiErrorText(
        context,
        e,
        fallback: context.l10n.buyNowOrderFailed,
      );

      showAppSnack(context, msg, tone: SnackTone.error);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
      showAppSnack(
        context,
        context.l10n.buyNowOrderFailed,
        tone: SnackTone.error,
      );
    }
  }
}

/// One saved address in the "Select Address" sheet, with a radio mark.
class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.primaryLabel,
    required this.phoneText,
    required this.onTap,
  });

  final ShippingAddress address;
  final bool selected;
  final String primaryLabel;
  final String phoneText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.fast);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.99,
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: selected ? AppColors.primaryTint : AppColors.surfaceLight,
        child: AnimatedContainer(
          duration: duration,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: duration,
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.borderStrong,
                    width: selected ? 6 : 1.6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (address.slot == 'primary') ...[
                          const SizedBox(width: 8),
                          StatusChip(
                            label: primaryLabel,
                            tone: ChipTone.brand,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${address.addressLine1}, ${address.city}, ${localizedStateName(context, address.state)} - ${address.pincode}',
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phoneText,
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
