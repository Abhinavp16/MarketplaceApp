import 'package:flutter/material.dart';

import '../../core/services/shipping_address_service.dart';
import '../../widgets/state_city_pincode_fields.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPrimary(address.slot)
              ? context.l10n.addressPrimarySetDefault
              : context.l10n.addressSecondarySetDefault,
        ),
      ),
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
          12,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Form(
          key: fk,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isPrimary(slot)
                      ? ctx.l10n.addressPrimaryTitle
                      : ctx.l10n.addressSecondaryTitle,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _field(nameC, ctx.l10n.fieldFullName),
                const SizedBox(height: 10),
                _field(
                  phoneC,
                  ctx.l10n.fieldPhone,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _field(addrC, ctx.l10n.fieldAddressLine1),
                const SizedBox(height: 10),
                StateCityPincodeFields(
                  stateController: stateC,
                  cityController: cityC,
                  pincodeController: pinC,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                    child: Text(ctx.l10n.addressSaveButton),
                  ),
                ),
              ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPrimary(slot)
                ? context.l10n.addressPrimarySaved
                : context.l10n.addressSecondarySaved,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.addressSaveFailed)));
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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _addressCard(String slot) {
    final address = _forSlot(slot);
    final isDefault = address != null && address.id == _selectedId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _slotLabel(slot),
                      style: AppFonts.jakarta(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.l10n.addressDefaultBadge,
                          style: AppFonts.jakarta(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: () => _openEditor(slot),
                  child: Text(
                    address == null
                        ? context.l10n.addressAdd
                        : context.l10n.commonEdit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (address == null)
              Text(
                context.l10n.addressEmpty,
                style: AppFonts.jakarta(color: Colors.black54),
              )
            else ...[
              Text(
                '${address.fullName} • ${address.phone}',
                style: AppFonts.jakarta(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${address.addressLine1}, ${address.city}, ${localizedStateName(context, address.state)} - ${address.pincode}',
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: isDefault ? null : () => _setDefault(address),
                child: Text(
                  isDefault
                      ? context.l10n.addressDefaultForDelivery
                      : context.l10n.addressSetAsDefault,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileAddresses)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.addressBanner,
                          style: AppFonts.jakarta(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _addressCard(ShippingAddressService.slotPrimary),
                _addressCard(ShippingAddressService.slotSecondary),
              ],
            ),
    );
  }
}
