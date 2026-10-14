// Presentational pieces of the cart, shared by the Cart screen and the Home
// screen's Cart tab. Everything here is data in / callbacks out: no provider
// reads and no navigation. (The quantity sheet is a modal the line card opens
// itself; it only reports the validated quantity back.)
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/cart_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/packing.dart';
import '../../l10n/l10n.dart';
import '../../l10n/pack_text.dart';
import '../../widgets/app_image.dart';
import '../../widgets/delivery_note.dart';
import '../../widgets/ui/ui.dart';

// -----------------------------------------------------------------------------
// Helpers

String _rupees(AppLocalizations l10n, num value) =>
    l10n.commonRupees(NumberFormatter.formatPrice(value.round()));

String _count(num value) => NumberFormatter.formatPrice(value);

/// How much the MRPs of [items] exceed their selling prices (0 when none).
double cartMrpSavings(Iterable<CartItem> items) => items.fold(0.0, (sum, item) {
  final mrp = item.mrp;
  if (mrp == null || mrp <= item.price) return sum;
  return sum + (mrp - item.price) * item.quantity;
});

/// "2 Coils (1,000 m)", "50 m", "15 pieces" or "Qty: 3" for [quantity]
/// (default: the line's quantity) of [item].
String cartQuantityText(
  AppLocalizations l10n,
  CartItem item,
  bool isWholesaler, [
  int? quantity,
]) {
  final q = quantity ?? item.quantity;
  final pack = item.pack;
  if (item.soldInPackets(isWholesaler)) return packQuantityText(l10n, pack, q);
  if (item.isMeter) return contentsText(l10n, ContentUnit.meter, q);
  if (pack.isPack) return contentsText(l10n, pack.contentUnit!, q);
  return l10n.commonQtyValue(NumberFormatter.formatQuantity(q));
}

/// Largest quantity of [item] that stock allows, in whole packs for
/// wholesalers; null when stock is unknown / zero.
int? _maxAllowed(CartItem item, bool isWholesaler) {
  if (item.stock <= 0) return null;
  final step = item.quantityStep(isWholesaler);
  return step > 1 ? (item.stock ~/ step) * step : item.stock;
}

/// Message for when + can't go further because stock ran out.
String cartStockLimitText(
  AppLocalizations l10n,
  CartItem item,
  bool isWholesaler,
) {
  final max = _maxAllowed(item, isWholesaler) ?? 0;
  if ((item.soldInPackets(isWholesaler) || item.isMeter) && max > 0) {
    return l10n.cartItemOnlyStockAvailable(
      cartQuantityText(l10n, item, isWholesaler, max),
    );
  }
  return l10n.cartOnlyUnitsAvailable(item.stock);
}

/// Text for the stock problem shown under a cart line.
String cartIssueText(AppLocalizations l10n, CartItem item, bool isWholesaler) {
  final minimum = item.minimumQuantity(isWholesaler);
  if (item.stock == 0) return l10n.cartItemOutOfStock;
  if (item.quantity < minimum) {
    return l10n.cartItemMinWholesale(_count(minimum));
  }
  if (item.quantity > item.stock) {
    return l10n.cartItemOnlyAvailable(
      _count(item.stock),
      _count(item.quantity),
    );
  }
  return l10n.cartItemOnlyStockAvailable(_count(item.stock));
}

/// Puts a removed line back (Undo): same product, fields and quantity.
/// Returns the server's error when it refused the item.
Future<DioException?> restoreCartItem(CartNotifier notifier, CartItem item) {
  return notifier.addItem(
    productId: item.productId,
    name: item.name,
    nameHindi: item.nameHindi,
    brand: item.brand,
    category: item.category,
    minWholesaleQuantity: item.minWholesaleQuantity,
    minCustomerQuantity: item.minCustomerQuantity,
    priceUnit: item.priceUnit,
    packing: item.packing,
    image: item.image,
    price: item.price,
    mrp: item.mrp,
    quantity: item.quantity,
    stock: item.stock,
  );
}

(Color, Color) _noticeColors(ChipTone tone) => switch (tone) {
  ChipTone.error => (AppColors.errorSoft, AppColors.error),
  ChipTone.info => (AppColors.infoSoft, AppColors.secondary),
  ChipTone.success ||
  ChipTone.brand => (AppColors.primarySoft, AppColors.primaryDeep),
  ChipTone.accent => (AppColors.accentSoft, AppColors.accent),
  ChipTone.neutral => (AppColors.gray100, AppColors.textSecondary),
  ChipTone.warning => (AppColors.warningSoft, AppColors.warning),
};

/// Tinted one-line notice (icon + text) used inside cart cards and bars.
class CartNotice extends StatelessWidget {
  /// A tinted [message] strip in [tone]; [action] sits at the end.
  const CartNotice({
    super.key,
    required this.message,
    this.tone = ChipTone.warning,
    this.icon,
    this.action,
  });

  final String message;
  final ChipTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _noticeColors(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon:
                icon ??
                (tone == ChipTone.error
                    ? HugeIcons.strokeRoundedCancelCircle
                    : tone == ChipTone.info
                    ? HugeIcons.strokeRoundedInformationCircle
                    : HugeIcons.strokeRoundedAlert02),
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.35,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Line card

/// One cart line: image, name, brand/category, unit and pack maths, price and
/// MRP, the line total, a stepper that moves in packs for wholesalers, and a
/// stock-issue strip. Tapping the number (or the quantity text) opens a sheet
/// to type the quantity.
class CartLineCard extends StatelessWidget {
  /// Line for [item]; [onQuantityChanged] gets the new quantity in pieces or
  /// meters, [onRemove] fires for the trash button and for − below the
  /// minimum, and [onLimitReached] gets a ready-to-show "only N left" message.
  const CartLineCard({
    super.key,
    required this.item,
    required this.isWholesaler,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onLimitReached,
    this.enabled = true,
  });

  final CartItem item;
  final bool isWholesaler;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final ValueChanged<String>? onLimitReached;
  final bool enabled;

  Future<void> _editQuantity(BuildContext context) async {
    final quantity = await showCartQuantitySheet(
      context,
      item: item,
      isWholesaler: isWholesaler,
    );
    if (quantity != null && quantity != item.quantity) {
      onQuantityChanged(quantity);
    }
  }

  void _stepTo(int next) {
    if (next <= 0) {
      onRemove();
      return;
    }
    // Below the minimum (a stock issue), + jumps straight to the minimum.
    final minimum = item.minimumQuantity(isWholesaler);
    if (next > item.quantity && item.quantity < minimum) {
      onQuantityChanged(minimum);
      return;
    }
    onQuantityChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pack = item.pack;
    final minimum = item.minimumQuantity(isWholesaler);
    final outOfStock = item.stock == 0;
    final hasIssue = item.hasStockIssue;
    final name = pickLocalizedName(context, item.name, item.nameHindi);
    final meta = [
      item.brand?.trim() ?? '',
      item.category?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' · ');
    final perUnit = (pack.isPack && pack.contentUnit == ContentUnit.piece)
        ? l10n.uiPerPiece
        : (item.isMeter ? l10n.uiPerMeter : null);

    String? minimumText;
    if (isWholesaler && minimum > item.quantityStep(isWholesaler)) {
      minimumText = l10n.homeMinWholesaleQtyValue(
        pack.isPack
            ? packQuantityText(l10n, pack, minimum)
            : _count(item.minWholesaleQuantity),
      );
    } else if (!isWholesaler && item.minCustomerQuantity > 1) {
      minimumText = l10n.productMinOrderQuantity(
        cartQuantityText(l10n, item, false, item.minCustomerQuantity),
      );
    }

    final borderColor = !hasIssue
        ? AppColors.border
        : (outOfStock ? AppColors.error : AppColors.warning).withValues(
            alpha: 0.4,
          );

    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LineThumb(item: item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      PriceView(
                        price: item.price,
                        mrp: item.mrp,
                        unit: perUnit,
                        size: 15,
                        offLabel: (percent) =>
                            l10n.commonPercentOff('$percent'),
                      ),
                      if (pack.isPack) ...[
                        const SizedBox(height: 3),
                        Text(
                          packPriceText(l10n, pack, item.price),
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (minimumText != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          minimumText,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonRemove,
                  onPressed: enabled ? onRemove : null,
                  style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RollingNumber(
                        value: item.total,
                        format: (value) => _rupees(l10n, value),
                        style: AppText.price(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      _QuantityCaption(
                        text: cartQuantityText(l10n, item, isWholesaler),
                        onTap: enabled && !outOfStock
                            ? () => _editQuantity(context)
                            : null,
                        semanticLabel: l10n.cartQtyTapToEdit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!outOfStock)
                  _TypeableStepper(
                    stepper: QuantityStepper(
                      quantity: item.quantity,
                      step: item.quantityStep(isWholesaler),
                      minimum: minimum,
                      maximum: item.stock > 0 ? item.stock : null,
                      enabled: enabled,
                      addLabel: l10n.productAddShort,
                      decreaseLabel: l10n.uiDecreaseQuantity,
                      increaseLabel: l10n.uiIncreaseQuantity,
                      displayQuantity: (q) => NumberFormatter.formatQuantity(
                        q ~/ item.quantityStep(isWholesaler),
                      ),
                      onLimitReached: () => onLimitReached?.call(
                        cartStockLimitText(l10n, item, isWholesaler),
                      ),
                      onChanged: _stepTo,
                      pill: true,
                    ),
                    onTapNumber: enabled ? () => _editQuantity(context) : null,
                    semanticLabel: l10n.cartQtyTapToEdit,
                  ),
              ],
            ),
          ),
          if (hasIssue)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: CartNotice(
                message: cartIssueText(l10n, item, isWholesaler),
                tone: outOfStock ? ChipTone.error : ChipTone.warning,
                action: !outOfStock && item.stock > 0 && enabled
                    ? _IssueAction(
                        label: l10n.cartSetQuantity(_count(item.stock)),
                        onTap: () => onQuantityChanged(item.stock),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _LineThumb extends StatelessWidget {
  const _LineThumb({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AppImage(
          imageUrl: item.image ?? '',
          category: item.category ?? '',
          name: item.name,
          width: 64,
          height: 64,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Quantity text under the line total; tappable to type a quantity.
class _QuantityCaption extends StatelessWidget {
  const _QuantityCaption({
    required this.text,
    required this.onTap,
    required this.semanticLabel,
  });

  final String text;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.jakarta(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          const HugeIcon(
            icon: HugeIcons.strokeRoundedPencilEdit02,
            size: 13,
            color: AppColors.textTertiary,
          ),
        ],
      ],
    );
    if (onTap == null) return label;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: label,
        ),
      ),
    );
  }
}

/// The kit stepper with a tap target over its number.
class _TypeableStepper extends StatelessWidget {
  const _TypeableStepper({
    required this.stepper,
    required this.onTapNumber,
    required this.semanticLabel,
  });

  final QuantityStepper stepper;
  final VoidCallback? onTapNumber;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (onTapNumber == null) return stepper;
    // The non-compact stepper's − and + are 44 wide; the middle is the number.
    const side = 44.0;
    return Stack(
      children: [
        stepper,
        Positioned(
          left: side,
          right: side,
          top: 0,
          bottom: 0,
          child: Semantics(
            button: true,
            label: semanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTapNumber!();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _IssueAction extends StatelessWidget {
  const _IssueAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      shape: AppShapes.squircle(AppRadius.sm),
      color: AppColors.surfaceLight,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: AppShapes.squircle(
            AppRadius.sm,
            side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.warning,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Quantity sheet

/// Opens a small sheet to type the quantity of [item]. Wholesalers of pack
/// products type whole packs; the result is always a pack multiple, at least
/// the minimum and within stock. Resolves to the new quantity in pieces or
/// meters, or null when dismissed.
Future<int?> showCartQuantitySheet(
  BuildContext context, {
  required CartItem item,
  required bool isWholesaler,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CartQuantitySheet(item: item, isWholesaler: isWholesaler),
  );
}

class _CartQuantitySheet extends StatefulWidget {
  const _CartQuantitySheet({required this.item, required this.isWholesaler});

  final CartItem item;
  final bool isWholesaler;

  @override
  State<_CartQuantitySheet> createState() => _CartQuantitySheetState();
}

class _CartQuantitySheetState extends State<_CartQuantitySheet> {
  late final TextEditingController _controller;
  String? _error;

  CartItem get _item => widget.item;
  int get _step => _item.quantityStep(widget.isWholesaler);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${_item.displayQuantity(widget.isWholesaler)}',
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Typed amount converted to pieces / meters (packs × pack size).
  int? get _quantity {
    final typed = int.tryParse(_controller.text.trim());
    return typed == null ? null : typed * _step;
  }

  String? _validate(AppLocalizations l10n) {
    final quantity = _quantity;
    if (quantity == null || quantity <= 0) return l10n.cartQtyEnter;
    final minimum = _item.minimumQuantity(widget.isWholesaler);
    if (quantity < minimum) {
      return l10n.productMinOrderQuantity(
        cartQuantityText(l10n, _item, widget.isWholesaler, minimum),
      );
    }
    final max = _maxAllowed(_item, widget.isWholesaler);
    if (max != null && quantity > max) {
      return cartStockLimitText(l10n, _item, widget.isWholesaler);
    }
    return null;
  }

  void _submit() {
    final l10n = context.l10n;
    final error = _validate(l10n);
    if (error != null) {
      HapticFeedback.mediumImpact();
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_quantity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = _item;
    final pack = item.pack;
    final inPacks = item.soldInPackets(widget.isWholesaler);
    final label = inPacks
        ? l10n.cartQtyPackCount(packUnitLabel(l10n, pack.packUnit!))
        : l10n.commonQuantity;
    final suffix = inPacks
        ? null
        : item.isMeter
        ? l10n.productUnitMeter
        : (pack.isPack ? l10n.productUnitPiece : null);
    final quantity = _quantity;
    final preview = quantity != null && quantity > 0
        ? cartQuantityText(l10n, item, widget.isWholesaler, quantity)
        : null;
    final max = _maxAllowed(item, widget.isWholesaler);
    final minimum = item.minimumQuantity(widget.isWholesaler);
    final limits = [
      if (minimum > _step)
        l10n.productMinOrderQuantity(
          cartQuantityText(l10n, item, widget.isWholesaler, minimum),
        ),
      if (max != null)
        l10n.cartInStockCount(
          cartQuantityText(l10n, item, widget.isWholesaler, max),
        ),
    ].join('  ·  ');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
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
                const SizedBox(height: 8),
                Text(
                  l10n.cartQtySheetTitle,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pickLocalizedName(context, item.name, item.nameHindi),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (pack.isPack) ...[
                  const SizedBox(height: 2),
                  Text(
                    packPriceText(l10n, pack, item.price),
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                  style: AppText.price(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    suffixText: suffix,
                    errorText: _error,
                    helperText: _error == null ? preview : null,
                    helperStyle: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
                if (limits.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    limits,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(label: l10n.cartQtyUpdate, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bill

/// Bill card: the total with a green "You save" line, and a collapsed
/// "View breakup" with item total, delivery and coupon rows.
class CartBillCard extends StatefulWidget {
  /// [itemTotal] − [discount] = [total], an estimate: DemoMart adds
  /// delivery when it confirms the order, which the card says (with the
  /// delivery note under the total). [savings] (MRP savings plus any coupon)
  /// shows in green beside the total when above 0.
  const CartBillCard({
    super.key,
    required this.itemTotal,
    required this.total,
    this.discount = 0,
    this.couponCode,
    this.savings = 0,
    this.itemCount,
    this.totalLabel,
    this.initiallyExpanded = false,
  });

  final double itemTotal;
  final double total;
  final double discount;

  /// Applied coupon; its row reads "Coupon (CODE)" when set.
  final String? couponCode;
  final double savings;

  /// Shown after "Item total" when given.
  final int? itemCount;

  /// Replaces "Estimated total".
  final String? totalLabel;
  final bool initiallyExpanded;

  @override
  State<CartBillCard> createState() => _CartBillCardState();
}

class _CartBillCardState extends State<CartBillCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration = AppMotion.of(context, AppMotion.base);
    final itemLabel = widget.itemCount == null
        ? l10n.cartItemTotal
        : '${l10n.cartItemTotal} (${l10n.commonItemsCount(widget.itemCount!)})';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cartBillTitle,
                  style: AppFonts.jakarta(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Pressable(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                semanticLabel: _expanded
                    ? l10n.cartHideBreakup
                    : l10n.cartViewBreakup,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded
                              ? l10n.cartHideBreakup
                              : l10n.cartViewBreakup,
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: duration,
                          curve: AppMotion.standard,
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowDown01,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.totalLabel ?? l10n.dealEstimatedTotal,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.savings > 0) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedDiscountTag01,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.cartYouSave(
                                  NumberFormatter.formatPrice(
                                    widget.savings.round(),
                                  ),
                                ),
                                style: AppFonts.jakarta(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                RollingNumber(
                  value: widget.total,
                  format: (value) => _rupees(l10n, value),
                  style: AppText.price(fontSize: 20),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8, right: 8),
            child: DeliveryNote(),
          ),
          AnimatedSize(
            duration: duration,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10, right: 8),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        SummaryRow(
                          label: itemLabel,
                          value: _rupees(l10n, widget.itemTotal),
                        ),
                        SummaryRow(
                          label: l10n.cartDeliveryFee,
                          value: l10n.dealDeliveryOnConfirmation,
                        ),
                        if (widget.discount > 0)
                          SummaryRow(
                            label: widget.couponCode?.isNotEmpty == true
                                ? l10n.homeCouponWithCode(widget.couponCode!)
                                : l10n.cartDiscount,
                            value: l10n.cartMinusRupees(
                              NumberFormatter.formatPrice(
                                widget.discount.round(),
                              ),
                            ),
                            valueColor: AppColors.primary,
                          ),
                        const SizedBox(height: 4),
                        const Divider(height: 1),
                        const SizedBox(height: 4),
                        SummaryRow(
                          label: l10n.dealEstimatedTotal,
                          value: _rupees(l10n, widget.total),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Coupon

/// Coupon code input with an Apply button, for carts that show coupons.
class CartCouponField extends StatelessWidget {
  /// Code field ([controller] optional) + Apply; [locked] shows the applied
  /// state with [onChangeCode]; [error] / [successText] show under it.
  const CartCouponField({
    super.key,
    required this.onApply,
    this.controller,
    this.onChanged,
    this.applying = false,
    this.locked = false,
    this.onChangeCode,
    this.error,
    this.successText,
    this.labelText,
    this.hintText,
  });

  final VoidCallback? onApply;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool applying;
  final bool locked;
  final VoidCallback? onChangeCode;
  final String? error;
  final String? successText;
  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !locked && !applying,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                  ],
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: labelText,
                    hintText: hintText ?? l10n.cartCouponHint,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCoupon01,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: locked ? l10n.homeCouponAppliedButton : l10n.commonApply,
                onPressed: locked ? null : onApply,
                loading: applying,
                expand: false,
                size: AppButtonSize.medium,
                variant: AppButtonVariant.tonal,
              ),
            ],
          ),
          if (locked && onChangeCode != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onChangeCode,
                child: Text(l10n.homeChangeCode),
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: 8),
            CartNotice(message: error!, tone: ChipTone.error),
          ] else if (successText != null) ...[
            const SizedBox(height: 8),
            CartNotice(
              message: successText!,
              tone: ChipTone.success,
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Address

/// Delivery address summary with an Add / Change action.
class CartAddressCard extends StatelessWidget {
  /// Summary of [name], [phone] and [address]; with no [address] it shows an
  /// "add delivery address" prompt. The whole card calls [onTap].
  const CartAddressCard({
    super.key,
    required this.onTap,
    this.name,
    this.phone,
    this.address,
    this.title,
    this.emptyLabel,
  });

  final VoidCallback? onTap;
  final String? name;
  final String? phone;
  final String? address;

  /// Eyebrow above the address (default "Delivery Address").
  final String? title;

  /// Prompt when there is no address (default "Add Delivery Address").
  final String? emptyLabel;

  bool get _hasAddress => (address ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final who = [
      name?.trim() ?? '',
      phone?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join('  ·  ');
    final action = _hasAddress
        ? l10n.buyNowChangeAddress
        : l10n.buyNowAddAddress;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surfaceLight,
      semanticLabel: '${title ?? l10n.buyNowDeliveryAddress}, $action',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: _hasAddress
                      ? HugeIcons.strokeRoundedLocation01
                      : HugeIcons.strokeRoundedLocationAdd01,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? l10n.buyNowDeliveryAddress,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (!_hasAddress)
                    Text(
                      emptyLabel ?? l10n.buyNowAddDeliveryAddress,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    )
                  else ...[
                    if (who.isNotEmpty)
                      Text(
                        who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      address!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              action,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Checkout bar

/// Sticky bottom bar of the cart: total on the left, the primary action on the
/// right, and an optional notice line above.
class CartCheckoutBar extends StatelessWidget {
  /// Shows [total] (with [totalLabel] and [caption]) and a [label] button
  /// calling [onPressed]; [loading] swaps the label for a spinner; [notice]
  /// (tinted by [noticeTone]) explains why the button may be off.
  const CartCheckoutBar({
    super.key,
    required this.total,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.trailingIcon,
    this.totalLabel,
    this.caption,
    this.notice,
    this.noticeTone = ChipTone.warning,
  });

  final double total;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final IconData? trailingIcon;
  final String? totalLabel;
  final String? caption;
  final String? notice;
  final ChipTone noticeTone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.bar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.base),
                curve: AppMotion.standard,
                child: notice == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CartNotice(message: notice!, tone: noticeTone),
                      ),
              ),
              Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 88),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalLabel ?? l10n.commonTotal,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        RollingNumber(
                          value: total,
                          format: (value) => _rupees(l10n, value),
                          style: AppText.price(fontSize: 19),
                        ),
                        if (caption != null)
                          Text(
                            caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton(
                      label: label,
                      onPressed: onPressed,
                      loading: loading,
                      icon: icon,
                      trailingIcon: trailingIcon,
                      pill: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Loading

/// Placeholder list shaped like cart lines, for the cart's first load.
class CartLinesSkeleton extends StatelessWidget {
  /// [count] placeholder cards, 12 apart.
  const CartLinesSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            const AppCard(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 72, height: 72, radius: AppRadius.md),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 14),
                        SizedBox(height: 8),
                        Skeleton(width: 120, height: 12),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Skeleton(width: 70, height: 16),
                            Spacer(),
                            Skeleton(
                              width: 110,
                              height: 40,
                              radius: AppRadius.md,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
