import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/cart_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/utils/packing.dart';
import '../../l10n/l10n.dart';
import 'app_feedback.dart';
import 'quantity_stepper.dart';

/// "Add" on a catalog product card that turns into − n + once the product is
/// in the cart.
///
/// The first tap adds the product exactly like the lists' quick "Add": the
/// wholesale minimum (whole packs) for wholesalers, the customer minimum for
/// everyone else, with the product's unit and packing. Later taps change the
/// cart line through [CartNotifier.updateQuantity] (one pack per tap for
/// wholesalers buying pack products); going below the minimum removes it.
///
/// [product] is the card's product map; it needs `minWholesaleQuantity`,
/// `minCustomerQuantity`, `priceUnit` and `packing` (and `packSize` when the
/// server sends it).
class ProductCartStepper extends ConsumerWidget {
  const ProductCartStepper({
    super.key,
    required this.productId,
    required this.product,
    required this.name,
    required this.price,
    this.mrp,
    this.nameHindi,
    this.brand,
    this.category,
    this.image,
    this.inStock = true,
    this.compact = true,
  });

  final String productId;
  final Map<String, dynamic> product;

  /// English product name (the cart stores it; the UI localises it).
  final String name;
  final num price;

  /// Only when the product is discounted; stored with the cart line.
  final num? mrp;
  final String? nameHindi;
  final String? brand;
  final String? category;
  final String? image;
  final bool inStock;
  final bool compact;

  CartItem? _cartLine(CartState cart) {
    final key = '$productId:default';
    for (final item in cart.items) {
      if (item.cartItemKey == key) return item;
    }
    for (final item in cart.items) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  void _add(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (ref.read(guestModeProvider)) {
      showAppSnack(context, l10n.productAddToCartDisabledPreview);
      return;
    }
    final configuredMinimum = product['minWholesaleQuantity'];
    final minimumWholesaleQuantity = configuredMinimum is num
        ? configuredMinimum.toInt()
        : int.tryParse(configuredMinimum?.toString() ?? '') ?? 1;
    // Pieces; whole packets for packet products.
    final wholesaleQuantity = wholesaleMinimumOf(product);
    final quantity = ref.read(effectiveIsWholesalerProvider)
        ? wholesaleQuantity
        : customerMinimumOf(product);
    ref
        .read(cartProvider.notifier)
        .addItem(
          productId: productId,
          name: name,
          nameHindi: nameHindi,
          brand: brand,
          category: category,
          minWholesaleQuantity: minimumWholesaleQuantity,
          minCustomerQuantity: customerMinimumOf(product),
          priceUnit: product['priceUnit']?.toString(),
          packing: product['packing']?.toString(),
          price: price.toDouble(),
          mrp: mrp?.toDouble(),
          image: image,
          quantity: quantity,
        );
    showAppSnack(
      context,
      l10n.productAddedToCart,
      tone: SnackTone.success,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    CartItem line,
    int next,
  ) async {
    if (ref.read(guestModeProvider)) {
      showAppSnack(context, context.l10n.productAddToCartDisabledPreview);
      return;
    }
    final error = await ref
        .read(cartProvider.notifier)
        .updateQuantity(productId, next < 1 ? 0 : next);
    if (error != null && context.mounted) {
      // The provider's message is English.
      showAppSnack(
        context,
        context.l10n.cartOnlyUnitsAvailable(line.stock),
        tone: SnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isWholesaler = ref.watch(effectiveIsWholesalerProvider);
    final isPreview = ref.watch(guestModeProvider);
    final line = isPreview ? null : _cartLine(ref.watch(cartProvider));
    final quantity = line?.quantity ?? 0;

    final pack = packInfoOf(product);
    final step =
        line?.quantityStep(isWholesaler) ??
        (isWholesaler && pack.isPack ? pack.size : 1);
    final minimum =
        line?.minimumQuantity(isWholesaler) ??
        (isWholesaler
            ? wholesaleMinimumOf(product)
            : customerMinimumOf(product));
    final inPacks = step > 1;

    return QuantityStepper(
      quantity: quantity,
      step: step < 1 ? 1 : step,
      minimum: minimum < 1 ? 1 : minimum,
      addLabel: l10n.productAddShort,
      compact: compact,
      expand: true,
      enabled: inStock || line != null,
      decreaseLabel: l10n.uiDecreaseQuantity,
      increaseLabel: l10n.uiIncreaseQuantity,
      displayQuantity: inPacks ? (q) => '${q ~/ step}' : null,
      onChanged: (next) {
        if (line == null) {
          _add(context, ref);
        } else {
          _change(context, ref, line, next);
        }
      },
    );
  }
}
