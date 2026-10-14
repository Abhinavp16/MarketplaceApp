import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/services/shipping_address_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<ShippingAddress> _addresses = [];
  String? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final addresses = await ShippingAddressService.getAddresses();
    final selectedId = await ShippingAddressService.getSelectedAddressId();
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _selectedId = selectedId;
      _loading = false;
    });
  }

  ShippingAddress? _forSlot(String slot) {
    for (final address in _addresses) {
      if (address.slot == slot) return address;
    }
    return null;
  }

  Future<void> _setDefault(ShippingAddress address) async {
    await ShippingAddressService.setSelectedAddressId(address.id);
    if (!mounted) return;
    setState(() => _selectedId = address.id);
    showAppSnack(
      context,
      _isPrimary(address.slot)
          ? context.l10n.addressPrimarySetDefault
          : context.l10n.addressSecondarySetDefault,
      tone: SnackTone.success,
    );
  }

  bool _isPrimary(String slot) => slot == ShippingAddressService.slotPrimary;

  String _slotLabel(String slot) => _isPrimary(slot)
      ? context.l10n.addressSlotPrimary
      : context.l10n.addressSlotSecondary;

  Future<void> _openEditor(String slot) async {
    final existing = _forSlot(slot);
    final fk = GlobalKey<FormState>();
    final nameC = TextEditingController(text: existing?.fullName ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final addrC = TextEditingController(text: existing?.addressLine1 ?? '');
    final cityC = TextEditingController(text: existing?.city ?? '');
    final stateC = TextEditingController(text: existing?.state ?? '');
    final pinC = TextEditingController(text: existing?.pincode ?? '');

    final payload = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Form(
          key: fk,
          child: SingleChildScrollView(
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 8),
                  Text(
                    _isPrimary(slot)
                        ? ctx.l10n.addressPrimaryTitle
                        : ctx.l10n.addressSecondaryTitle,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(nameC, ctx.l10n.fieldFullName),
                  const SizedBox(height: 12),
                  _field(
                    phoneC,
                    ctx.l10n.fieldPhone,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(addrC, ctx.l10n.fieldAddressLine1),
                  const SizedBox(height: 12),
                  StateCityPincodeFields(
                    stateController: stateC,
                    cityController: cityC,
                    pincodeController: pinC,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: ctx.l10n.addressSaveButton,
                    onPressed: () {
                      if (!fk.currentState!.validate()) return;
                      Navigator.pop(ctx, {
                        'fullName': nameC.text.trim(),
                        'phone': phoneC.text.trim(),
                        'addressLine1': addrC.text.trim(),
                        'city': cityC.text.trim(),
                        'state': stateC.text.trim(),
                        'pincode': pinC.text.trim(),
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (payload == null) return;

    final address = ShippingAddress(
      id: existing?.id ?? ShippingAddress.generateId(),
      slot: slot,
      fullName: payload['fullName'] ?? '',
      phone: payload['phone'] ?? '',
      addressLine1: payload['addressLine1'] ?? '',
      city: payload['city'] ?? '',
      state: payload['state'] ?? '',
      pincode: payload['pincode'] ?? '',
    );

    try {
      await ShippingAddressService.upsertAddress(address);
      await ShippingAddressService.setSelectedAddressId(address.id);
      await _load();
      if (!mounted) return;
      showAppSnack(
        context,
        _isPrimary(slot)
            ? context.l10n.addressPrimarySaved
            : context.l10n.addressSecondarySaved,
        tone: SnackTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        context.l10n.addressSaveFailed,
        tone: SnackTone.error,
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? context.l10n.commonRequired : null,
      style: AppFonts.jakarta(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _addressCard(String slot) {
    final address = _forSlot(slot);
    final isDefault = address != null && address.id == _selectedId;
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      borderColor: isDefault ? AppColors.primary : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDefault ? AppColors.primarySoft : AppColors.gray100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: _isPrimary(slot)
                        ? HugeIcons.strokeRoundedHome01
                        : HugeIcons.strokeRoundedStore01,
                    size: 18,
                    color: isDefault
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _slotLabel(slot),
                  style: AppFonts.jakarta(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: 8),
                StatusChip(
                  label: l10n.addressDefaultBadge,
                  tone: ChipTone.brand,
                  dense: true,
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openEditor(slot),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: HugeIcon(
                  icon: address == null
                      ? HugeIcons.strokeRoundedPlusSign
                      : HugeIcons.strokeRoundedPencilEdit02,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(
                  address == null ? l10n.addressAdd : l10n.commonEdit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: address == null
                ? Text(
                    l10n.addressEmpty,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${address.fullName} • ${address.phone}',
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address.addressLine1}, ${address.city}, ${localizedStateName(context, address.state)} - ${address.pincode}',
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: isDefault
                            ? l10n.addressDefaultForDelivery
                            : l10n.addressSetAsDefault,
                        icon: isDefault
                            ? HugeIcons.strokeRoundedCheckmarkCircle02
                            : null,
                        variant: isDefault
                            ? AppButtonVariant.tonal
                            : AppButtonVariant.secondary,
                        size: AppButtonSize.medium,
                        expand: false,
                        onPressed: isDefault
                            ? null
                            : () => _setDefault(address),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: context.l10n.profileAddresses),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        child: _loading
            ? SkeletonShimmer(
                key: const ValueKey('loading'),
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Skeleton(height: 52, radius: AppRadius.lg),
                    SizedBox(height: 12),
                    Skeleton(height: 150, radius: AppRadius.lg),
                    SizedBox(height: 12),
                    Skeleton(height: 150, radius: AppRadius.lg),
                  ],
                ),
              )
            : ListView(
                key: const ValueKey('content'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          size: 20,
                          color: AppColors.primaryDeep,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.addressBanner,
                            style: AppFonts.jakarta(
                              color: AppColors.primaryDeep,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _addressCard(ShippingAddressService.slotPrimary),
                  const SizedBox(height: 12),
                  _addressCard(ShippingAddressService.slotSecondary),
                ],
              ),
      ),
    );
  }
}
