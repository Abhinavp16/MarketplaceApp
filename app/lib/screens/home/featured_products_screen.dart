import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/number_formatter.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class FeaturedProductsScreen extends ConsumerStatefulWidget {
  final bool isHotDeals;
  final String? brandName;

  const FeaturedProductsScreen({
    super.key,
    this.isHotDeals = false,
    this.brandName,
  });

  @override
  ConsumerState<FeaturedProductsScreen> createState() =>
      _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState
    extends ConsumerState<FeaturedProductsScreen> {
  static const Color primaryBlue = Color(0xFF134E4A);
  static const Color backgroundWhite = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);

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
            if (widget.brandName != null) 'brand': widget.brandName,
            if (widget.brandName == null && widget.isHotDeals) 'hot': true,
            if (widget.brandName == null && !widget.isHotDeals)
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
          'minWholesaleQuantity': item['minWholesaleQuantity'],
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

  String _formatPrice(num? price) {
    return NumberFormatter.formatLakhs(price ?? 0);
  }

  num _numberValue(dynamic value) {
    return value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showMessage(String message, {Color backgroundColor = primaryBlue}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppFonts.outfit(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDealer = ref.watch(effectiveIsWholesalerProvider);
    final title = widget.brandName != null
        ? widget.brandName!
        : widget.isHotDeals
        ? (isDealer
              ? l10n.featuredHotDealsDealer
              : l10n.featuredHotDealsCustomer)
        : (isDealer
              ? l10n.featuredPopularDealer
              : l10n.featuredPopularCustomer);

    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: AppFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.featuredLoadError),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchProducts,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : _products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isHotDeals
                        ? Icons.local_fire_department_outlined
                        : Icons.star_outline,
                    size: 64,
                    color: textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.featuredEmpty,
                    style: AppFonts.outfit(color: textMuted, fontSize: 16),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 700;
                final gridColumns = isTablet
                    ? (constraints.maxWidth >= 1000 ? 4 : 3)
                    : 2;
                final cardHeight = isTablet ? 270.0 : 275.0;

                return GridView.builder(
                  padding: EdgeInsets.all(isTablet ? 20 : 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns,
                    crossAxisSpacing: isTablet ? 14 : 10,
                    mainAxisSpacing: isTablet ? 14 : 10,
                    mainAxisExtent: cardHeight,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _buildProductCard(product, l10n);
                  },
                );
              },
            ),
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
    final rating = product['rating'];
    final reviewCount =
        product['reviewCount'] ?? product['review'] ?? product['reviews'] ?? '';
    final inStock = product['inStock'] != false;
    final isWishlisted = ref.watch(wishlistProvider).contains(productId);
    final displayName = localizedName(context, product);

    String? badgeLabel;
    Color? badgeColor;
    if (widget.isHotDeals) {
      badgeLabel = l10n.productBadgeHot;
      badgeColor = const Color(0xFFEF4444);
    } else if (discount > 0) {
      badgeLabel = l10n.productBadgeSale;
      badgeColor = const Color(0xFF16A34A);
    } else if (product['isNew'] == true) {
      badgeLabel = l10n.productBadgeNew;
      badgeColor = primaryBlue;
    }

    return InkWell(
      onTap: () =>
          context.push('/product/$productId', extra: {'heroTag': heroTag}),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE1E8F2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF334155).withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFFFAFCFF)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Hero(
                        tag: heroTag,
                        child:
                            product['image'] != null &&
                                product['image'].toString().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: product['image'].toString(),
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) =>
                                      ProductImagePlaceholder(
                                        category:
                                            product['category']?.toString() ??
                                            '',
                                        name: product['name']?.toString() ?? '',
                                      ),
                                  errorWidget: (_, __, ___) =>
                                      ProductImagePlaceholder(
                                        category:
                                            product['category']?.toString() ??
                                            '',
                                        name: product['name']?.toString() ?? '',
                                      ),
                                ),
                              )
                            : ProductImagePlaceholder(
                                category: product['category']?.toString() ?? '',
                                name: product['name']?.toString() ?? '',
                              ),
                      ),
                    ),
                    if (!inStock)
                      Container(
                        color: Colors.white.withOpacity(0.65),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            l10n.commonOutOfStock,
                            style: AppFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (badgeLabel != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badgeLabel,
                            style: AppFonts.outfit(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white.withOpacity(0.94),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            if (ref.read(guestModeProvider)) {
                              _showMessage(
                                l10n.productWishlistDisabledPreview,
                                backgroundColor: textSecondary,
                              );
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
                                    mrp: hasDiscount
                                        ? originalPrice.toDouble()
                                        : null,
                                    category: product['category']?.toString(),
                                    nameHindi: product['nameHindi']?.toString(),
                                    blurHash: product['blurHash']?.toString(),
                                  ),
                                );
                          },
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              isWishlisted
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: isWishlisted
                                  ? const Color(0xFFEF4444)
                                  : textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.isEmpty ? l10n.productBrandFallback : brand,
                    style: AppFonts.jakarta(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 32,
                    child: Text(
                      displayName,
                      style: AppFonts.jakarta(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating?.toString() ?? '0',
                        style: AppFonts.jakarta(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                      if (reviewCount.toString().isNotEmpty) ...[
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '($reviewCount)',
                            style: AppFonts.jakarta(
                              fontSize: 8,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${_formatPrice(price)}',
                                style: AppFonts.jakarta(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            if (hasDiscount)
                              Text(
                                '₹${_formatPrice(originalPrice)}',
                                style: AppFonts.jakarta(
                                  fontSize: 7.5,
                                  color: textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: inStock
                            ? () {
                                if (ref.read(guestModeProvider)) {
                                  _showMessage(
                                    l10n.productAddToCartDisabledPreview,
                                    backgroundColor: textSecondary,
                                  );
                                  return;
                                }
                                final configuredMinimum =
                                    product['minWholesaleQuantity'];
                                final minimumWholesaleQuantity =
                                    configuredMinimum is num
                                    ? configuredMinimum.toInt()
                                    : int.tryParse(
                                            configuredMinimum?.toString() ?? '',
                                          ) ??
                                          1;
                                final quantity =
                                    ref.read(effectiveIsWholesalerProvider)
                                    ? math.max(minimumWholesaleQuantity, 1)
                                    : 1;
                                ref
                                    .read(cartProvider.notifier)
                                    .addItem(
                                      productId: productId,
                                      name: product['name']?.toString() ?? '',
                                      nameHindi: product['nameHindi']
                                          ?.toString(),
                                      brand: product['brand']?.toString(),
                                      category: product['category']?.toString(),
                                      minWholesaleQuantity:
                                          minimumWholesaleQuantity,
                                      price: price.toDouble(),
                                      mrp: hasDiscount
                                          ? originalPrice.toDouble()
                                          : null,
                                      image: product['image']?.toString(),
                                      quantity: quantity,
                                    );
                                _showMessage(l10n.productAddedToCart);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: inStock
                                ? primaryBlue
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                                size: 11,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                l10n.productAddShort,
                                style: AppFonts.jakarta(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
