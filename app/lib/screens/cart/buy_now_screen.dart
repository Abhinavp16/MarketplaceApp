import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/services/shipping_address_service.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';

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

  String _fmt(double price) => NumberFormatter.formatPrice(price.round());

  String _rupees(double price) => context.l10n.commonRupees(_fmt(price));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (ref.watch(guestModeProvider)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          title: Text(l10n.buyNowPreviewTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.buyNowPreviewDisabled,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      body: Column(
        children: [
          // Custom App Bar
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFe2e8f0))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF0f172a),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.buyNowTitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0f172a),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Product Card
                _buildProductCard(),
                const SizedBox(height: 16),

                // Address Section
                _buildAddressSection(),
                const SizedBox(height: 16),

                // Price Summary
                _buildPriceSummary(),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom CTA
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFe2e8f0))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _proceedToCheckout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF94a3b8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCheckingOut
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.buyNowSubmitOrder,
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
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Row(
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.productImage != null
                ? CachedNetworkImage(
                    imageUrl: widget.productImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFf1f5f9),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFf1f5f9),
                      child: const Icon(Icons.image, color: Color(0xFF94a3b8)),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFFf1f5f9),
                    child: const Icon(Icons.image, color: Color(0xFF94a3b8)),
                  ),
          ),
          const SizedBox(width: 16),

          // Product Info
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF0f172a),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.commonQtyValue(
                    NumberFormatter.formatPrice(widget.quantity),
                  ),
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748b),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _rupees(widget.price),
                      style: AppFonts.jakarta(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    if (widget.mrp != null && widget.mrp! > widget.price) ...[
                      const SizedBox(width: 8),
                      Text(
                        _rupees(widget.mrp!),
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFEF4444),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.buyNowDeliveryAddress,
                style: AppFonts.jakarta(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0f172a),
                ),
              ),
              TextButton(
                onPressed: _showAddressSelectionDialog,
                child: Text(
                  _savedAddresses.isEmpty
                      ? l10n.buyNowAddAddress
                      : l10n.buyNowChangeAddress,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_savedAddresses.isEmpty)
            InkWell(
              onTap: () {
                context.push('/addresses').then((_) => _loadSavedAddresses());
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFe2e8f0),
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_location_alt,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.buyNowAddDeliveryAddress,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF64748b),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _name,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0f172a),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.phone,
                        size: 16,
                        color: Color(0xFF64748b),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _phone,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          color: const Color(0xFF64748b),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Color(0xFF64748b),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fullAddress,
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            color: const Color(0xFF64748b),
                          ),
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

  Widget _buildPriceSummary() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cartPriceSummary,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0f172a),
            ),
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            l10n.commonSubtotal,
            _rupees(widget.price * widget.quantity),
            const Color(0xFF64748b),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            l10n.cartDeliveryFee,
            _rupees(50),
            const Color(0xFF64748b),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 1,
            color: const Color(0xFFe2e8f0),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.commonTotal,
                style: AppFonts.jakarta(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a),
                ),
              ),
              Text(
                _rupees((widget.price * widget.quantity) + 50),
                style: AppFonts.jakarta(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF64748b),
          ),
        ),
        Text(
          value,
          style: AppFonts.jakarta(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                        color: const Color(0xFFe2e8f0),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Text(
                    l10n.checkoutShippingAddress,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0f172a),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        elevation: 0,
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppFonts.jakarta(color: const Color(0xFF64748b)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFe2e8f0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFe2e8f0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0F766E)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFdc2626)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.buyNowSelectAddress,
                  style: AppFonts.jakarta(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0f172a),
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
                  child: Text(
                    l10n.buyNowAddNewAddress,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._savedAddresses.map(
              (address) => InkWell(
                onTap: () {
                  Navigator.pop(context, address.id);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedAddressId == address.id
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFe2e8f0),
                      width: _selectedAddressId == address.id ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedAddressId == address.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _selectedAddressId == address.id
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF94a3b8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  address.fullName,
                                  style: AppFonts.jakarta(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0f172a),
                                  ),
                                ),
                                if (address.slot == 'primary') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0F766E,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l10n.buyNowPrimaryAddress,
                                      style: AppFonts.jakarta(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${address.addressLine1}, ${address.city}, ${address.state} - ${address.pincode}',
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: const Color(0xFF64748b),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.checkoutPhoneValue(address.phone),
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: const Color(0xFF64748b),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
    final shouldOpenLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.cartLoginRequiredTitle),
          content: Text(l10n.buyNowLoginRequiredMessage),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data['message']?.toString() ??
                  context.l10n.buyNowOrderFailed,
              style: AppFonts.jakarta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
          ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.buyNowOrderFailed,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
