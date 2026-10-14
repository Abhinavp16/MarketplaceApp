import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/config/api_config.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/ui/product_cart_stepper.dart';
import '../../widgets/ui/catalog_price_text.dart';
import '../../widgets/ui/ui.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/coming_soon.dart';

class FeaturedProductsScreen extends ConsumerStatefulWidget {
  final bool isHotDeals;
  final String? brandName;
  // Products marked Coming Soon by the admin.
  final bool comingSoon;

  const FeaturedProductsScreen({
    super.key,
    this.isHotDeals = false,
    this.brandName,
    this.comingSoon = false,
  });

  @override
  ConsumerState<FeaturedProductsScreen> createState() =>
      _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState
    extends ConsumerState<FeaturedProductsScreen> {
  late final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              if (ref.read(guestModeProvider)) {
                options.headers.remove('Authorization');
                return handler.next(options);
              }
              final token = await StorageService.getAccessToken();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              return handler.next(options);
            },
          ),
        );

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final items = <dynamic>[];
      var page = 1;
      var hasNext = true;
      while (hasNext) {
        final response = await _dio.get(
          '/products',
          queryParameters: {
            if (widget.comingSoon)
              'comingSoon': true
            else if (widget.brandName != null)
              'brand': widget.brandName
            else if (widget.isHotDeals)
              'hot': true
            else
              'featured': true,
            'page': page,
            'limit': 50,
          },
        );
        if (response.statusCode != 200) break;
        final data = response.data;
        items.addAll(List<dynamic>.from(data['data'] ?? const []));
        hasNext = data['pagination']?['hasNext'] == true;
        page++;
      }

      final products = items.map<Map<String, dynamic>>((item) {
        final name = item['name']?.toString() ?? '';
        final cat = (item['category'] ?? item['categoryName'] ?? '').toString();

        // Try every possible image field the backend might use (robust version from home screen)
        String apiImage =
            (item['primaryImage'] ??
                    item['image'] ??
                    item['imageUrl'] ??
                    item['photo'] ??
                    item['thumbnail'] ??
                    item['img'] ??
                    '')
                .toString()
                .trim();

        apiImage = ApiConfig.normalizeMediaUrl(apiImage);

        return <String, dynamic>{
          'id': item['id']?.toString() ?? item['_id']?.toString() ?? '',
          'name': name,
          'nameHindi': item['nameHindi']?.toString() ?? '',
          'category': cat,
          'brand': item['brand']?.toString() ?? '',
          'price': catalogPriceForAudience(
            Map<String, dynamic>.from(item as Map),
            isCustomerPreview: ref.read(guestModeProvider),
          ),
          'originalPrice': item['mrp'] ?? item['originalPrice'] ?? 0,
          'image': apiImage,
          'blurHash': item['primaryBlurHash'] ?? item['blurHash'] ?? '',
          'rating': item['rating'] ?? 4.5,
          'review': item['review'],
          'reviews': item['reviews'],
          'reviewCount':
              item['reviewCount'] ?? item['review'] ?? item['reviews'] ?? '',
          'inStock': item['inStock'] != false,
          'comingSoon': item['comingSoon'] == true,
          'priceHidden': item['priceHidden'] == true,
          'expectedDate': item['expectedDate'],
          'minWholesaleQuantity': item['minWholesaleQuantity'],
          'priceUnit': item['priceUnit'],
          'packing': item['packing'],
          'minCustomerQuantity': item['minCustomerQuantity'],
          'isHot': item['isHot'] == true,
          'isNew': item['isNew'] == true,
          'pendingPriceChange': item['pendingPriceChange'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  num _numberValue(dynamic value) {
    return value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showMessage(String message, {SnackTone tone = SnackTone.neutral}) {
    showAppSnack(
      context,
      message,
      tone: tone,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDealer = ref.watch(effectiveIsWholesalerProvider);
    final title = widget.comingSoon
        ? l10n.homeComingSoonSection
        : widget.brandName != null
        ? widget.brandName!
        : widget.isHotDeals
        ? (isDealer
              ? l10n.featuredHotDealsDealer
              : l10n.featuredHotDealsCustomer)
        : (isDealer
              ? l10n.featuredPopularDealer
              : l10n.featuredPopularCustomer);

    final Object key;
    final Widget body;
    if (_isLoading) {
      key = 'loading';
      body = _buildGrid(itemCount: 6, skeleton: true);
    } else if (_error != null) {
      key = 'error';
      body = EmptyState(
        icon: HugeIcons.strokeRoundedWifiError01,
        title: l10n.featuredLoadError,
        actionLabel: l10n.commonRetry,
        onAction: _fetchProducts,
        tone: ChipTone.neutral,
      );
    } else if (_products.isEmpty) {
      key = 'empty';
      body = EmptyState(
        icon: widget.comingSoon
            ? HugeIcons.strokeRoundedClock01
            : widget.isHotDeals
            ? HugeIcons.strokeRoundedFire
            : HugeIcons.strokeRoundedStar,
        title: l10n.featuredEmpty,
        tone: ChipTone.neutral,
      );
    } else {
      key = 'grid';
      body = _buildGrid(itemCount: _products.length);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: title),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.exit,
        child: KeyedSubtree(key: ValueKey(key), child: body),
      ),
    );
  }

  Widget _buildGrid({required int itemCount, bool skeleton = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;
        final gridColumns = isTablet
            ? (constraints.maxWidth >= 1000 ? 4 : 3)
            : 2;
        final padding = isTablet ? 20.0 : 16.0;
        final spacing = isTablet ? 14.0 : 12.0;
        final cardWidth =
            (constraints.maxWidth - padding * 2 - spacing * (gridColumns - 1)) /
            gridColumns;
        final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14)
            .clamp(1.0, 1.6);
        // Square image, then brand, name (2 lines), rating and price, plus
        // the card padding and the Add stepper.
        final cardHeight =
            (cardWidth - 12) +
            12 +
            10 +
            42 +
            (16 + 34 + 20 + 38 + 12) * textScale;

        return GridView.builder(
          physics: skeleton
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
          padding: EdgeInsets.fromLTRB(
            padding,
            8,
            padding,
            padding + MediaQuery.paddingOf(context).bottom,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => skeleton
              ? const SkeletonProductCard()
              : _buildProductCard(_products[index], context.l10n),
        );
      },
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    AppLocalizations l10n,
  ) {
    final productId = product['id']?.toString() ?? '';
    final heroTag = 'product-image-$productId';
    final price = _numberValue(product['price']);
    final originalPrice = _numberValue(product['originalPrice']);
    final hasDiscount = originalPrice > 0 && price < originalPrice;
    final discount = hasDiscount
        ? (((originalPrice - price) / originalPrice) * 100).round()
        : 0;
    final brand = (product['brand'] ?? product['category'] ?? '').toString();
    final rawRating = product['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '');
    final reviewCount = int.tryParse('${product['reviewCount'] ?? ''}');
    final inStock = product['inStock'] != false;
    final comingSoon = isComingSoonProduct(product);
    final isWishlisted = ref.watch(wishlistProvider).contains(productId);
    final displayName = localizedName(context, product);
    final packParts = catalogPackParts(l10n, product, price);

    // No HOT tag on the Hot Deals page: the page title already says it.
    String? badgeLabel;
    var badgeTone = ChipTone.brand;
    if (discount > 0) {
      // No badge: the card tags the photo with the discount ("16% OFF").
    } else if (product['isNew'] == true) {
      badgeLabel = l10n.productBadgeNew;
      badgeTone = ChipTone.info;
    }

    return ProductCard(
      name: displayName,
      price: price,
      unit: catalogUnitSuffix(l10n, product),
      packNote: packParts?.label,
      packPrice: packParts?.price,
      mrp: hasDiscount ? originalPrice : null,
      offLabel: (percent) => l10n.commonPercentOff('$percent'),
      comingSoon: comingSoon,
      comingSoonPrice: isPriceHidden(product) ? l10n.comingSoonPrice : null,
      imageUrl: product['image']?.toString() ?? '',
      category: product['category']?.toString() ?? '',
      brand: brand.isEmpty ? l10n.productBrandFallback : brand,
      rating: rating,
      reviewCount: reviewCount,
      badge: badgeLabel,
      badgeTone: badgeTone,
      inStock: inStock,
      soldOutLabel: l10n.commonOutOfStock,
      heroTag: heroTag,
      wishlisted: isWishlisted,
      wishlistLabel: isWishlisted
          ? l10n.uiRemoveFromWishlist
          : l10n.uiAddToWishlist,
      onWishlist: () {
        if (ref.read(guestModeProvider)) {
          _showMessage(l10n.productWishlistDisabledPreview);
          return;
        }
        ref
            .read(wishlistProvider.notifier)
            .toggle(
              WishlistItem(
                productId: productId,
                name: product['name']?.toString() ?? '',
                image: product['image']?.toString(),
                price: price.toDouble(),
                mrp: hasDiscount ? originalPrice.toDouble() : null,
                category: product['category']?.toString(),
                nameHindi: product['nameHindi']?.toString(),
                blurHash: product['blurHash']?.toString(),
              ),
            );
      },
      onTap: () =>
          context.push(
            '/product/$productId',
            extra: {
              'heroTag': heroTag,
              'heroImage': product['image']?.toString(),
              'heroBlurHash': product['blurHash']?.toString(),
            },
          ),
      action: ProductCartStepper(
        productId: productId,
        product: product,
        name: product['name']?.toString() ?? '',
        nameHindi: product['nameHindi']?.toString(),
        brand: product['brand']?.toString(),
        category: product['category']?.toString(),
        price: price,
        mrp: hasDiscount ? originalPrice : null,
        image: product['image']?.toString(),
        inStock: inStock,
      ),
    );
  }
}
