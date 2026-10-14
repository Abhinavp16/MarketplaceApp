import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/providers/guest_mode_provider.dart';

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/packing.dart';
import '../../widgets/pending_price_change_notice.dart';
import '../../widgets/ui/catalog_price_text.dart';
import '../../widgets/ui/product_cart_stepper.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/coming_soon.dart';

enum _CatalogStage { categories, subcategories, products }

class CategoriesController {
  _CategoriesScreenState? _state;

  bool handleBack() => _state?._handleBack() ?? false;

  void _attach(_CategoriesScreenState state) => _state = state;

  void _detach(_CategoriesScreenState state) {
    if (identical(_state, state)) _state = null;
  }
}

class CategoriesScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSearchTap;
  final CategoriesController? controller;
  final int navigationRequest;
  final String? initialCategoryId;
  final String? initialCategoryName;
  final String? brandName;
  final String? brandId;

  const CategoriesScreen({
    super.key,
    this.onSearchTap,
    this.controller,
    this.navigationRequest = 0,
    this.initialCategoryId,
    this.initialCategoryName,
    this.brandName,
    this.brandId,
  });

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
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

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingBrands = true;
  bool _isLoadingCategories = true;
  bool _isLoadingProducts = false;
  bool _productLoadFailed = false;
  bool _brandsLoadFailed = false;
  bool _categoriesLoadFailed = false;
  // Which sub-category chip was last scrolled into view.
  String? _ensuredChipToken;
  int _selectedBrandIndex = -1;
  int _selectedCategoryIndex = -1;
  _CatalogStage _stage = _CatalogStage.categories;
  bool _showingDirectCategoryProducts = false;
  final Map<String, List<Map<String, dynamic>>> _categoryCache = {};
  int _destinationRequestGeneration = 0;
  int _categoryRequestGeneration = 0;
  int _productRequestGeneration = 0;

  // New navigation state: null = show subcategory cards (if any),
  // non-null = show products inside that subcategory.
  Map<String, dynamic>? _selectedSubcategory;

  // Subcategories support (legacy expanded map kept for compat, no longer used in sidebar)
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _fetchBrands();
  }

  @override
  void didUpdateWidget(covariant CategoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (widget.brandId != oldWidget.brandId ||
        widget.brandName != oldWidget.brandName ||
        widget.navigationRequest != oldWidget.navigationRequest ||
        widget.initialCategoryId != oldWidget.initialCategoryId ||
        widget.initialCategoryName != oldWidget.initialCategoryName) {
      _openRequestedDestination();
      return;
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  String _brandDisplayName(Map<String, dynamic> brand) {
    final name = brand['name']?.toString().trim() ?? '';
    return name.toUpperCase() == 'GENERAL PRODUCTS'
        ? context.l10n.categoryGeneralProducts
        : name;
  }

  Future<void> _fetchBrands() async {
    try {
      final response = await _dio.get(
        '/companies',
        queryParameters: {'active': true, 'limit': 500},
      );
      final List<dynamic> items = response.data['data'] ?? [];
      final brands = items
          .whereType<Map>()
          .map<Map<String, dynamic>>((item) {
            final logo = item['logo'];
            return {
              'id': item['_id']?.toString() ?? item['id']?.toString() ?? '',
              'companyIds': [
                item['_id']?.toString() ?? item['id']?.toString() ?? '',
              ],
              'name': item['name']?.toString() ?? '',
              'slug': item['slug']?.toString() ?? '',
              'order': _numericValue(item['order']).toInt(),
              'aliases': [
                item['_id']?.toString() ?? item['id']?.toString() ?? '',
                item['slug']?.toString() ?? '',
                item['name']?.toString().toLowerCase() ?? '',
              ],
              'logo': logo is Map
                  ? ApiConfig.normalizeMediaUrl(logo['url']?.toString() ?? '')
                  : ApiConfig.normalizeMediaUrl(logo?.toString() ?? ''),
            };
          })
          .where((brand) => (brand['id'] as String).isNotEmpty)
          .toList();

      final generalBrands = brands.where((brand) {
        final name = brand['name'].toString().trim().toUpperCase();
        return name == 'GENERAL' || name == 'GENERAL PRODUCTS';
      }).toList();
      if (generalBrands.isNotEmpty) {
        brands.removeWhere((brand) {
          final name = brand['name'].toString().trim().toUpperCase();
          return name == 'GENERAL' || name == 'GENERAL PRODUCTS';
        });
        final primary = generalBrands.firstWhere(
          (brand) =>
              brand['name'].toString().trim().toUpperCase() ==
              'GENERAL PRODUCTS',
          orElse: () => generalBrands.first,
        );
        brands.add({
          ...primary,
          'name': 'General Products',
          'slug': 'general-products',
          'companyIds': generalBrands
              .map((brand) => brand['id'].toString())
              .toList(),
          'aliases': generalBrands
              .expand(
                (brand) => (brand['aliases'] as List? ?? const []).map(
                  (alias) => alias.toString(),
                ),
              )
              .toSet()
              .toList(),
        });
      }

      brands.sort((a, b) {
        final aName = a['name'].toString().trim().toUpperCase();
        final bName = b['name'].toString().trim().toUpperCase();
        if (aName == 'GENERAL PRODUCTS' && bName != 'GENERAL PRODUCTS') {
          return 1;
        }
        if (bName == 'GENERAL PRODUCTS' && aName != 'GENERAL PRODUCTS') {
          return -1;
        }
        final order = _numericValue(
          a['order'],
        ).compareTo(_numericValue(b['order']));
        if (order != 0) return order;
        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        _brands = brands;
        _isLoadingBrands = false;
        _brandsLoadFailed = false;
      });
      await _openRequestedDestination();
    } catch (e) {
      debugPrint('Error fetching catalog brands: $e');
      if (!mounted) return;
      setState(() {
        _brands = [];
        _isLoadingBrands = false;
        _isLoadingCategories = false;
        _brandsLoadFailed = true;
      });
    }
  }

  void _retryBrands() {
    setState(() {
      _isLoadingBrands = true;
      _isLoadingCategories = true;
      _brandsLoadFailed = false;
    });
    _fetchBrands();
  }

  void _retryCategories() {
    if (_selectedBrandIndex < 0 || _selectedBrandIndex >= _brands.length) {
      _retryBrands();
      return;
    }
    _selectBrand(_selectedBrandIndex, force: true);
  }

  int _requestedBrandIndex() {
    final requestedId = widget.brandId?.trim() ?? '';
    final normalizedRequestedId = requestedId.toLowerCase();
    final requestedName = widget.brandName?.trim().toLowerCase() ?? '';
    if (requestedId.isNotEmpty) {
      final index = _brands.indexWhere(
        (brand) =>
            brand['id'] == requestedId ||
            brand['slug'] == requestedId ||
            (brand['companyIds'] as List? ?? const []).contains(requestedId) ||
            (brand['aliases'] as List? ?? const []).any(
              (alias) =>
                  alias.toString().toLowerCase() == normalizedRequestedId,
            ),
      );
      if (index != -1) return index;
      return -1;
    }
    if (requestedName.isNotEmpty) {
      final index = _brands.indexWhere(
        (brand) =>
            brand['name'].toString().toLowerCase() == requestedName ||
            (brand['aliases'] as List? ?? const []).any(
              (alias) => alias.toString().toLowerCase() == requestedName,
            ),
      );
      if (index != -1) return index;
      return -1;
    }
    return _brands.isEmpty ? -1 : 0;
  }

  Future<void> _openRequestedDestination() async {
    if (_brands.isEmpty) return;
    final destinationGeneration = ++_destinationRequestGeneration;
    var brandIndex = _requestedBrandIndex();
    final requestedCategory = widget.initialCategoryName?.trim() ?? '';
    final requestedCategoryId = widget.initialCategoryId?.trim() ?? '';

    if ((widget.brandId?.trim().isEmpty ?? true) &&
        requestedCategory.isNotEmpty) {
      try {
        final response = await _dio.get(
          '/categories',
          queryParameters: {
            'active': true,
            'parent': 'root',
            'search': requestedCategory,
            'limit': 100,
          },
        );
        final List<dynamic> matches = response.data['data'] ?? [];
        final exact = matches.whereType<Map>().cast<Map>().firstWhere(
          (item) =>
              item['name']?.toString().toLowerCase() ==
              requestedCategory.toLowerCase(),
          orElse: () => <dynamic, dynamic>{},
        );
        final company = exact['company'];
        final companyId = company is Map
            ? company['_id']?.toString() ?? company['id']?.toString() ?? ''
            : company?.toString() ?? '';
        final resolvedIndex = _brands.indexWhere(
          (brand) => brand['id'] == companyId,
        );
        if (resolvedIndex != -1) brandIndex = resolvedIndex;
      } catch (_) {
        // Fall back to the requested or first brand.
      }
    }

    if (!mounted || destinationGeneration != _destinationRequestGeneration) {
      return;
    }
    if (brandIndex == -1) {
      setState(() {
        _selectedBrandIndex = -1;
        _categories = [];
        _isLoadingCategories = false;
        _categoriesLoadFailed = false;
      });
      return;
    }
    await _selectBrand(
      brandIndex,
      force: true,
      initialCategoryId: requestedCategoryId,
      initialCategoryName: requestedCategory,
    );
  }

  Future<void> _selectBrand(
    int index, {
    bool force = false,
    String initialCategoryId = '',
    String initialCategoryName = '',
  }) async {
    if (index < 0 || index >= _brands.length) return;
    if (!force && index == _selectedBrandIndex) return;
    if (!mounted) return;

    final companyIds = (_brands[index]['companyIds'] as List? ?? const [])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toList();
    if (companyIds.isEmpty) companyIds.add(_brands[index]['id'].toString());
    final cacheKey = companyIds.join(',');
    final generation = ++_categoryRequestGeneration;
    _productRequestGeneration++;
    setState(() {
      _selectedBrandIndex = index;
      _selectedCategoryIndex = -1;
      _selectedSubcategory = null;
      _stage = _CatalogStage.categories;
      _showingDirectCategoryProducts = false;
      _products = [];
      _isLoadingProducts = false;
      _productLoadFailed = false;
      _isLoadingCategories = true;
      _categoriesLoadFailed = false;
    });

    final cached = _categoryCache[cacheKey];
    if (cached != null) {
      _applyBrandCategories(cached, initialCategoryId, initialCategoryName);
      return;
    }

    try {
      final responses = await Future.wait(
        companyIds.map(
          (companyId) => _dio.get(
            '/categories/with-subcategories',
            queryParameters: {'active': true, 'company': companyId},
          ),
        ),
      );
      if (!mounted || generation != _categoryRequestGeneration) return;
      final items = <dynamic>[];
      for (final response in responses) {
        items.addAll(response.data['data'] as List? ?? const []);
      }
      final categories = _parseCategories(items);
      _categoryCache[cacheKey] = categories;
      _applyBrandCategories(categories, initialCategoryId, initialCategoryName);
    } catch (e) {
      debugPrint('Error fetching brand categories: $e');
      if (!mounted || generation != _categoryRequestGeneration) return;
      setState(() {
        _categories = [];
        _isLoadingCategories = false;
        _categoriesLoadFailed = true;
      });
    }
  }

  List<Map<String, dynamic>> _parseCategories(List<dynamic> items) {
    final categories = items
        .whereType<Map>()
        .map<Map<String, dynamic>>((item) {
          final subcategories = (item['subcategories'] as List? ?? const [])
              .whereType<Map>()
              .map<Map<String, dynamic>>((subitem) {
                final image = subitem['image'];
                return {
                  'id':
                      subitem['id']?.toString() ??
                      subitem['_id']?.toString() ??
                      '',
                  'name': subitem['name']?.toString() ?? '',
                  'nameHindi': subitem['nameHindi']?.toString() ?? '',
                  'slug': subitem['slug']?.toString() ?? '',
                  'productCount': subitem['productCount'] ?? 0,
                  'image': image is Map
                      ? image['url']?.toString() ?? ''
                      : image?.toString() ?? '',
                };
              })
              .toList();
          final image = item['image'];
          final directCount = _numericValue(item['productCount']).toInt();
          final totalCount = subcategories.fold<int>(
            directCount,
            (total, subcategory) =>
                total + _numericValue(subcategory['productCount']).toInt(),
          );
          return {
            'id': item['id']?.toString() ?? item['_id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'nameHindi': item['nameHindi']?.toString() ?? '',
            'slug': item['slug']?.toString() ?? '',
            'image': image is Map
                ? image['url']?.toString() ?? ''
                : image?.toString() ?? '',
            'productCount': totalCount,
            'directProductCount': directCount,
            'order': item['order'] ?? 0,
            'subcategories': subcategories,
          };
        })
        .where((category) {
          return category['name'].toString().isNotEmpty &&
              _numericValue(category['productCount']) > 0;
        })
        .toList();

    categories.sort((a, b) {
      final order = _numericValue(
        a['order'],
      ).compareTo(_numericValue(b['order']));
      if (order != 0) return order;
      return a['name'].toString().compareTo(b['name'].toString());
    });
    return categories;
  }

  void _applyBrandCategories(
    List<Map<String, dynamic>> categories,
    String initialCategoryId,
    String initialCategoryName,
  ) {
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selectedCategoryIndex = -1;
      _selectedSubcategory = null;
      _stage = _CatalogStage.categories;
      _showingDirectCategoryProducts = false;
      _products = [];
      _isLoadingCategories = false;
      _categoriesLoadFailed = false;
      _expandedCategories.clear();
    });

    if (initialCategoryId.isEmpty && initialCategoryName.isEmpty) return;
    final index = initialCategoryId.isNotEmpty
        ? categories.indexWhere(
            (category) => category['id'].toString() == initialCategoryId,
          )
        : categories.indexWhere(
            (category) =>
                category['name'].toString().toLowerCase() ==
                initialCategoryName.toLowerCase(),
          );
    if (index != -1) _onCategorySelected(index);
  }

  // ---- Brand (left) -> Category -> Subcategory -> Products (right) ----

  List<Map<String, dynamic>> _subcategoriesOf(Map<String, dynamic> category) {
    final raw = category['subcategories'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  void _onCategorySelected(int index) {
    if (index < 0 || index >= _categories.length) return;
    final cat = _categories[index];
    final subs = _subcategoriesOf(cat);
    _productRequestGeneration++;
    setState(() {
      _selectedCategoryIndex = index;
      _selectedSubcategory = null;
      if (subs.isEmpty) {
        _stage = _CatalogStage.products;
        _showingDirectCategoryProducts = true;
        _isLoadingProducts = true;
        _productLoadFailed = false;
      } else {
        _stage = _CatalogStage.subcategories;
        _showingDirectCategoryProducts = false;
        _isLoadingProducts = false;
        _products = [];
      }
    });
    if (subs.isEmpty) {
      _fetchProductsForCategory(cat);
    }
  }

  void _onSubcategorySelected(Map<String, dynamic> subcategory) {
    if (_selectedCategoryIndex < 0 ||
        _selectedCategoryIndex >= _categories.length) {
      return;
    }
    final cat = _categories[_selectedCategoryIndex];
    setState(() {
      _selectedSubcategory = Map<String, dynamic>.from(subcategory);
      _stage = _CatalogStage.products;
      _showingDirectCategoryProducts = false;
      _isLoadingProducts = true;
      _productLoadFailed = false;
    });
    _fetchProductsForCategoryAndSubcategory(cat, subcategory);
  }

  /// "Other products": the category's own products, outside any sub-category.
  void _onDirectProductsSelected(Map<String, dynamic> category) {
    setState(() {
      _selectedSubcategory = null;
      _stage = _CatalogStage.products;
      _showingDirectCategoryProducts = true;
    });
    _fetchProductsForCategory(category);
  }

  void _onBackToSubcategories() {
    final hasSubcategories =
        _selectedCategoryIndex >= 0 &&
        _selectedCategoryIndex < _categories.length &&
        _subcategoriesOf(_categories[_selectedCategoryIndex]).isNotEmpty;
    _productRequestGeneration++;
    setState(() {
      _selectedSubcategory = null;
      _products = [];
      _isLoadingProducts = false;
      _productLoadFailed = false;
      if (hasSubcategories) {
        _stage = _CatalogStage.subcategories;
      } else {
        _selectedCategoryIndex = -1;
        _stage = _CatalogStage.categories;
      }
      _showingDirectCategoryProducts = false;
    });
  }

  void _onBackToCategories() {
    _productRequestGeneration++;
    setState(() {
      _selectedCategoryIndex = -1;
      _selectedSubcategory = null;
      _products = [];
      _isLoadingProducts = false;
      _productLoadFailed = false;
      _stage = _CatalogStage.categories;
      _showingDirectCategoryProducts = false;
    });
  }

  Future<void> _fetchProductsForCategoryAndSubcategory(
    Map<String, dynamic> category,
    Map<String, dynamic> subcategory,
  ) async {
    final requestGeneration = ++_productRequestGeneration;
    setState(() {
      _isLoadingProducts = true;
      _productLoadFailed = false;
      _products = [];
    });
    try {
      final subcategorySlug = subcategory['slug']?.toString().trim() ?? '';
      final subcategoryName = subcategory['name']?.toString().trim() ?? '';

      debugPrint(
        '🔵 [SUBCATEGORY] Fetching products for subcategory: $subcategoryName (slug: $subcategorySlug)',
      );

      if (subcategorySlug.isEmpty) {
        debugPrint('🔴 [SUBCATEGORY] Subcategory slug is empty!');
        setState(() => _isLoadingProducts = false);
        return;
      }

      // Fetch products by subcategory slug with pagination
      final allItems = <Map<String, dynamic>>[];
      var page = 1;
      var hasMore = true;

      while (hasMore) {
        try {
          final response = await _dio.get(
            '/products',
            queryParameters: {
              'page': page,
              'categoryId': subcategory['id']?.toString() ?? '',
              'subcategory': subcategorySlug, // Use subcategory parameter
            },
          );

          debugPrint(
            '🟢 [SUBCATEGORY] Page $page response: ${response.statusCode}',
          );

          if (response.statusCode != 200) {
            throw StateError('Product request failed: ${response.statusCode}');
          }

          final List<dynamic> pageItems = response.data['data'] ?? [];
          if (pageItems.isEmpty) {
            hasMore = false;
            break;
          }

          allItems.addAll(
            pageItems.whereType<Map>().map(Map<String, dynamic>.from),
          );

          final pagination = response.data['pagination'];
          hasMore = pagination is Map && pagination['hasNext'] == true;
          page += 1;
        } catch (e) {
          debugPrint('🔴 [SUBCATEGORY] Error fetching page $page: $e');
          rethrow;
        }
      }

      debugPrint(
        '🟢 [SUBCATEGORY] Fetched ${allItems.length} products for subcategory: $subcategorySlug',
      );

      if (!mounted || requestGeneration != _productRequestGeneration) return;
      setState(() {
        _products = allItems.map<Map<String, dynamic>>(_mapProduct).toList()
          ..sort(_compareProductsByPrice);

        _isLoadingProducts = false;
      });
    } catch (e, stackTrace) {
      debugPrint('🔴 [SUBCATEGORY] ERROR: $e');
      debugPrint('🔴 [SUBCATEGORY] Stack trace: $stackTrace');
      if (mounted && requestGeneration == _productRequestGeneration) {
        setState(() {
          _isLoadingProducts = false;
          _productLoadFailed = true;
          _products = [];
        });
      }
    }
  }

  Future<void> _fetchProductsForCategory(Map<String, dynamic> category) async {
    final requestGeneration = ++_productRequestGeneration;
    setState(() {
      _isLoadingProducts = true;
      _productLoadFailed = false;
      _products = [];
    });
    try {
      final categorySlug = category['slug']?.toString().trim() ?? '';

      debugPrint(
        '🔵 [CATEGORIES-PRODUCTS] Fetching products for category slug: $categorySlug',
      );

      if (categorySlug.isEmpty) {
        debugPrint('🔴 [CATEGORIES-PRODUCTS] Category slug is empty!');
        setState(() => _isLoadingProducts = false);
        return;
      }

      // Fetch products by category slug with pagination
      final allItems = <Map<String, dynamic>>[];
      var page = 1;
      var hasMore = true;

      while (hasMore) {
        try {
          final response = await _dio.get(
            '/products',
            queryParameters: {
              'page': page,
              'categoryId': category['id']?.toString() ?? '',
              'category': categorySlug,
            },
          );

          debugPrint(
            '🟢 [CATEGORIES-PRODUCTS] Page $page response: ${response.statusCode}',
          );

          if (response.statusCode != 200) {
            throw StateError('Product request failed: ${response.statusCode}');
          }

          final List<dynamic> pageItems = response.data['data'] ?? [];
          if (pageItems.isEmpty) {
            hasMore = false;
            break;
          }

          allItems.addAll(
            pageItems.whereType<Map>().map(Map<String, dynamic>.from),
          );

          final pagination = response.data['pagination'];
          hasMore = pagination is Map && pagination['hasNext'] == true;
          page += 1;
        } catch (e) {
          debugPrint('🔴 [CATEGORIES-PRODUCTS] Error fetching page $page: $e');
          rethrow;
        }
      }

      debugPrint(
        '🟢 [CATEGORIES-PRODUCTS] Fetched ${allItems.length} products for category: $categorySlug',
      );

      if (!mounted || requestGeneration != _productRequestGeneration) return;
      setState(() {
        _products = allItems.map<Map<String, dynamic>>(_mapProduct).toList()
          ..sort(_compareProductsByPrice);

        _isLoadingProducts = false;
      });
    } catch (e, stackTrace) {
      debugPrint('🔴 [CATEGORIES-PRODUCTS] ERROR: $e');
      debugPrint('🔴 [CATEGORIES-PRODUCTS] Stack trace: $stackTrace');
      if (mounted && requestGeneration == _productRequestGeneration) {
        setState(() {
          _isLoadingProducts = false;
          _productLoadFailed = true;
          _products = [];
        });
      }
    }
  }

  /// Card data for one product from the list API. Pack fields and minimums
  /// are kept so the card's Add follows the same rules as the other lists.
  Map<String, dynamic> _mapProduct(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    return <String, dynamic>{
      'id': item['id']?.toString() ?? item['_id']?.toString() ?? '',
      'name': name,
      'nameHindi': item['nameHindi']?.toString() ?? '',
      'category': item['category']?.toString() ?? '',
      'brand': item['brand']?.toString() ?? '',
      'price': catalogPriceForAudience(
        Map<String, dynamic>.from(item),
        isCustomerPreview: ref.read(guestModeProvider),
      ),
      'mrp': item['mrp'] ?? 0,
      'image': ApiConfig.normalizeMediaUrl(
        item['primaryImage']?.toString() ?? '',
      ),
      'inStock': item['inStock'] != false,
      'comingSoon': item['comingSoon'] == true,
      'priceHidden': item['priceHidden'] == true,
      'expectedDate': item['expectedDate'],
      'shortDescription': item['shortDescription']?.toString() ?? '',
      // Real ratings only: no stars when the product has none.
      'rating': item['averageRating'] ?? item['rating'],
      'reviewCount':
          item['ratingCount'] ?? item['reviewCount'] ?? item['reviews'] ?? '',
      'minWholesaleQuantity': item['minWholesaleQuantity'],
      'minCustomerQuantity': item['minCustomerQuantity'],
      'priceUnit': item['priceUnit'],
      'packing': item['packing'],
      'pendingPriceChange': item['pendingPriceChange'],
    };
  }

  void _retryProductLoad() {
    if (_selectedCategoryIndex < 0 ||
        _selectedCategoryIndex >= _categories.length) {
      return;
    }
    final category = _categories[_selectedCategoryIndex];
    final subcategory = _selectedSubcategory;
    if (subcategory != null) {
      _fetchProductsForCategoryAndSubcategory(category, subcategory);
    } else {
      _fetchProductsForCategory(category);
    }
  }

  int _compareProductsByPrice(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final priceComparison = _numericValue(
      first['price'],
    ).compareTo(_numericValue(second['price']));
    if (priceComparison != 0) return priceComparison;

    return (first['name']?.toString() ?? '').toLowerCase().compareTo(
      (second['name']?.toString() ?? '').toLowerCase(),
    );
  }

  num _numericValue(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tractor')) return HugeIcons.strokeRoundedTractor;
    if (lower.contains('harvest')) return HugeIcons.strokeRoundedPlant02;
    if (lower.contains('irrigat') || lower.contains('pump')) {
      return HugeIcons.strokeRoundedDroplet;
    }
    if (lower.contains('seed') || lower.contains('plant')) {
      return HugeIcons.strokeRoundedPlant01;
    }
    if (lower.contains('fertil') || lower.contains('chemic')) {
      return HugeIcons.strokeRoundedTestTube01;
    }
    if (lower.contains('tool') || lower.contains('equip')) {
      return HugeIcons.strokeRoundedWrench01;
    }
    if (lower.contains('spray')) return HugeIcons.strokeRoundedDroplet;
    if (lower.contains('storage') || lower.contains('silo')) {
      return HugeIcons.strokeRoundedWarehouse;
    }
    return HugeIcons.strokeRoundedGridView;
  }

  Future<void> _handleRefresh() async {
    if (_selectedBrandIndex < 0 || _selectedBrandIndex >= _brands.length) {
      await _fetchBrands();
      return;
    }

    final brandIndex = _selectedBrandIndex;
    final brandId = _brands[brandIndex]['id'].toString();
    final cacheKey = (_brands[brandIndex]['companyIds'] as List? ?? [brandId])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .join(',');
    final categoryId =
        _selectedCategoryIndex >= 0 &&
            _selectedCategoryIndex < _categories.length
        ? _categories[_selectedCategoryIndex]['id']?.toString() ?? ''
        : '';
    final subcategoryId = _selectedSubcategory?['id']?.toString() ?? '';
    final previousStage = _stage;
    final wasShowingDirectProducts = _showingDirectCategoryProducts;

    _categoryCache.remove(cacheKey);
    await _selectBrand(brandIndex, force: true);
    if (!mounted ||
        categoryId.isEmpty ||
        _selectedBrandIndex < 0 ||
        _selectedBrandIndex >= _brands.length ||
        _brands[_selectedBrandIndex]['id'].toString() != brandId) {
      return;
    }

    final categoryIndex = _categories.indexWhere(
      (category) => category['id'] == categoryId,
    );
    if (categoryIndex == -1) return;
    if (previousStage == _CatalogStage.categories) return;

    if (previousStage == _CatalogStage.products && wasShowingDirectProducts) {
      setState(() {
        _selectedCategoryIndex = categoryIndex;
        _selectedSubcategory = null;
        _stage = _CatalogStage.products;
        _showingDirectCategoryProducts = true;
      });
      _fetchProductsForCategory(_categories[categoryIndex]);
      return;
    }

    _onCategorySelected(categoryIndex);
    if (previousStage != _CatalogStage.products || subcategoryId.isEmpty) {
      return;
    }
    final subcategories = _subcategoriesOf(_categories[categoryIndex]);
    final subcategoryIndex = subcategories.indexWhere(
      (subcategory) => subcategory['id'] == subcategoryId,
    );
    if (subcategoryIndex != -1) {
      _onSubcategorySelected(subcategories[subcategoryIndex]);
    }
  }

  String _getDisplayName(Map<String, dynamic> product) {
    return localizedName(context, product);
  }

  String _getDisplayCategoryName(Map<String, dynamic> category) {
    final displayName = category['displayName']?.toString() ?? '';
    final nameEnglish = category['name']?.toString() ?? '';
    final nameHindi = category['nameHindi']?.toString().trim() ?? '';

    if (context.isHindi && nameHindi.isNotEmpty) {
      return latinDigits(nameHindi);
    }
    if (displayName.isNotEmpty) return displayName;
    return _formatCategoryTitle(nameEnglish);
  }

  String _formatCategoryTitle(String value) {
    if (_isServiceCableCategory(value)) return 'Service Cable';

    final normalized = value
        .trim()
        .replaceAllMapped(
          RegExp(r'\b([Vv])-(\d+)\b'),
          (match) => '${match[1]}__DASH__${match[2]}',
        )
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll('__DASH__', '-');
    final acronyms = {'gi', 'pvc', 'hdpe', 'ss', 'ci', 'v'};

    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          if (acronyms.contains(lower)) return lower.toUpperCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  bool _isServiceCableCategory(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[-_]+'),
      ' ',
    );
    return normalized.contains('service cable');
  }

  bool _handleBack() {
    if (_stage == _CatalogStage.products) {
      _onBackToSubcategories();
      return true;
    }
    if (_stage == _CatalogStage.subcategories) {
      _onBackToCategories();
      return true;
    }
    return false;
  }

  // ---- Layout ----

  /// Opened as /brand/:id rather than as the Categories tab.
  bool get _isRoute => widget.controller == null;

  /// Space under scrolling content: the tab bar floats over the tab version.
  // Inside the Home tabs the floating nav covers the bottom; the tab's
  // MediaQuery bottom padding includes it.
  double get _bottomInset =>
      (_isRoute ? 24 : 100) + MediaQuery.paddingOf(context).bottom;

  double get _textScale =>
      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6);

  Map<String, dynamic>? get _selectedBrand =>
      _selectedBrandIndex >= 0 && _selectedBrandIndex < _brands.length
      ? _brands[_selectedBrandIndex]
      : null;

  void _openSearch() {
    final onSearchTap = widget.onSearchTap;
    if (onSearchTap != null) {
      onSearchTap();
      return;
    }
    context.go('/home', extra: {'tab': 1});
  }

  /// Header back on brand pages: up one level like the system back, then
  /// leave the page.
  void _onHeaderBack() {
    if (_handleBack()) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Widget _switcher(Object key, Widget child, {Offset begin = Offset.zero}) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.base),
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Object bodyKey;
    final Widget body;
    if (_isLoadingBrands) {
      bodyKey = 'loading';
      body = _buildLoadingLayout();
    } else if (_brandsLoadFailed) {
      bodyKey = 'brands-error';
      body = _buildBrandsError();
    } else if (_brands.isEmpty) {
      bodyKey = 'no-brands';
      body = _buildNoBrands();
    } else {
      bodyKey = 'catalog';
      body = _buildCatalogLayout();
    }

    final content = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      // White behind the header and the brand rail; the main panel is the
      // grey area with a rounded top-left corner.
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        // The panels run to the bottom edge (behind the Home tabs' floating
        // nav); their lists keep their last items clear via [_bottomInset].
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _isRoute ? _buildBrandHeader() : _buildTabHeader(),
              Expanded(child: _switcher(bodyKey, body)),
            ],
          ),
        ),
      ),
    );
    if (widget.controller != null) return content;
    return PopScope(
      canPop: _stage == _CatalogStage.categories,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: content,
    );
  }

  Widget _buildTabHeader() {
    final l10n = context.l10n;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.categoryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.jakarta(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            HeaderIconButton(
              icon: HugeIcons.strokeRoundedSearch01,
              tooltip: l10n.commonSearch,
              onPressed: _openSearch,
            ),
          ],
        ),
      ),
    );
  }

  /// Brand pages: back, the brand's logo and name, search.
  Widget _buildBrandHeader() {
    final l10n = context.l10n;
    final brand = _selectedBrand;
    final requested = widget.brandName?.trim() ?? '';
    final title = brand != null
        ? _brandDisplayName(brand)
        : (requested.isNotEmpty && requested != widget.brandId
              ? requested
              : l10n.categoryTitle);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(
          children: [
            AppBackButton(onPressed: _onHeaderBack),
            const SizedBox(width: 10),
            _BrandLogo(url: brand?['logo']?.toString() ?? '', size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.jakarta(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            HeaderIconButton(
              icon: HugeIcons.strokeRoundedSearch01,
              tooltip: l10n.commonSearch,
              onPressed: _openSearch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRailSkeleton(),
        Expanded(child: _mainPanel(_buildCategorySkeleton())),
      ],
    );
  }

  Widget _buildBrandsError() {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: _scrollableState(
        EmptyState(
          icon: HugeIcons.strokeRoundedWifiError01,
          title: l10n.catBrandsLoadError,
          message: l10n.catLoadErrorHint,
          actionLabel: l10n.commonRetry,
          onAction: _retryBrands,
          tone: ChipTone.neutral,
        ),
      ),
    );
  }

  Widget _buildNoBrands() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: _scrollableState(
        EmptyState(
          icon: HugeIcons.strokeRoundedStore01,
          title: context.l10n.categoryNoBrands,
          tone: ChipTone.neutral,
        ),
      ),
    );
  }

  /// An empty or error state that can still be pulled to refresh.
  Widget _scrollableState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: _bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - _bottomInset).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildCatalogLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The brand rail stays visible at every catalog stage.
        _buildBrandRail(),
        // The right panel drills through category, sub-category, products.
        Expanded(
          child: _mainPanel(
            RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppColors.primary,
              child: _buildRightPanel(),
            ),
          ),
        ),
      ],
    );
  }

  /// The grey area right of the brand rail, rounded where it meets the
  /// header and the rail.
  Widget _mainPanel(Widget child) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.xl),
      ),
      child: ColoredBox(color: AppColors.backgroundLight, child: child),
    );
  }

  // ---- Brand rail ----

  static const _railDecoration = BoxDecoration(color: AppColors.surfaceLight);

  Widget _buildBrandRail() {
    return Container(
      width: 88,
      decoration: _railDecoration,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: 8, bottom: _bottomInset),
        itemCount: _brands.length,
        itemBuilder: (context, index) => _buildBrandRailItem(index),
      ),
    );
  }

  Widget _buildBrandRailItem(int index) {
    final brand = _brands[index];
    final selected = _selectedBrandIndex == index;
    final name = _brandDisplayName(brand);
    final duration = AppMotion.of(context, AppMotion.base);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
          child: Semantics(
            selected: selected,
            child: Pressable(
              onTap: () => _selectBrand(index),
              haptic: true,
              semanticLabel: name,
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: selected ? AppColors.primarySoft : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BrandLogo(
                      url: brand['logo']?.toString() ?? '',
                      size: 48,
                      highlighted: selected,
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: AppMotion.standard,
                      style: AppFonts.jakarta(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.primaryDeep
                            : AppColors.textSecondary,
                        height: 1.25,
                      ),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Selected brand: a short bar on the rail's left edge.
        Positioned(
          left: 0,
          top: 20,
          bottom: 20,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.standard,
            width: selected ? 3 : 0,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRailSkeleton() {
    return Container(
      width: 88,
      decoration: _railDecoration,
      child: SkeletonShimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          children: [
            for (var i = 0; i < 8; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  children: [
                    Skeleton(width: 48, height: 48, radius: AppRadius.md),
                    SizedBox(height: 8),
                    Skeleton(width: 50, height: 10),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Right panel ----

  Widget _buildRightPanel() {
    if (_stage != _CatalogStage.products) _ensuredChipToken = null;
    final Object key;
    final Widget child;
    if (_isLoadingCategories) {
      key = 'loading';
      child = _buildCategorySkeleton();
    } else if (_categoriesLoadFailed) {
      key = 'error';
      child = _buildCategoryLoadError();
    } else if (_categories.isEmpty) {
      key = 'empty';
      child = _buildEmptyCategoryPanel();
    } else if (_stage == _CatalogStage.categories ||
        _selectedCategoryIndex < 0) {
      key = 'categories';
      child = _buildCategoryGrid();
    } else if (_stage == _CatalogStage.subcategories) {
      final cat = _categories[_selectedCategoryIndex];
      key = 'subcategories-$_selectedCategoryIndex';
      child = _buildSubcategoryGrid(cat, _subcategoriesOf(cat));
    } else {
      key = 'products-$_selectedCategoryIndex';
      child = _buildProductStage();
    }
    return _switcher(
      '$_selectedBrandIndex|$key',
      child,
      begin: const Offset(0.04, 0),
    );
  }

  Widget _buildPanelHeader({
    required String title,
    String? subtitle,
    String? count,
    VoidCallback? onBack,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 8 : 16, 12, 12, 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            AppBackButton(onPressed: onBack),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            StatusChip(label: count, tone: ChipTone.neutral, dense: true),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCategoryPanel() {
    return _scrollableState(
      EmptyState(
        icon: HugeIcons.strokeRoundedGridView,
        title: _selectedBrandIndex == -1
            ? context.l10n.categoryBrandNotFound
            : context.l10n.categoryNoCategoriesForBrand,
        tone: ChipTone.neutral,
        compact: true,
      ),
    );
  }

  Widget _buildCategoryLoadError() {
    final l10n = context.l10n;
    return _scrollableState(
      EmptyState(
        icon: HugeIcons.strokeRoundedWifiError01,
        title: l10n.catCategoriesLoadError,
        message: l10n.catLoadErrorHint,
        actionLabel: l10n.commonRetry,
        onAction: _retryCategories,
        tone: ChipTone.neutral,
        compact: true,
      ),
    );
  }

  int _tileColumns(double width) => width >= 700 ? 3 : 2;

  double _tileExtent(double maxWidth, int columns) {
    final width = (maxWidth - 24 - 10 * (columns - 1)) / columns;
    final imageHeight = (width - 16) * 0.72;
    return imageHeight + 28 + (34 + 2 + 16) * _textScale;
  }

  SliverGridDelegate _tileGrid(double maxWidth) {
    final columns = _tileColumns(maxWidth);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      mainAxisExtent: _tileExtent(maxWidth, columns),
    );
  }

  Widget _buildCategorySkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: SkeletonShimmer(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 120, height: 16),
                          SizedBox(height: 6),
                          Skeleton(width: 84, height: 11),
                        ],
                      ),
                    ),
                    Skeleton(width: 64, height: 22, radius: AppRadius.pill),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                gridDelegate: _tileGrid(constraints.maxWidth),
                itemCount: 8,
                itemBuilder: (_, _) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const SkeletonShimmer(
                    child: Column(
                      children: [
                        Expanded(
                          child: Skeleton(
                            height: double.infinity,
                            radius: AppRadius.md,
                          ),
                        ),
                        SizedBox(height: 10),
                        Skeleton(width: 80, height: 12),
                        SizedBox(height: 6),
                        Skeleton(width: 48, height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryGrid() {
    final l10n = context.l10n;
    final brand = _selectedBrand ?? const <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanelHeader(
          // Brand pages already name the brand in the page header.
          title: _isRoute
              ? l10n.categorySelectCategory
              : _brandDisplayName(brand),
          subtitle: _isRoute ? null : l10n.categorySelectCategory,
          count: l10n.categoryCategoriesCount(_categories.length),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(12, 4, 12, _bottomInset),
                gridDelegate: _tileGrid(constraints.maxWidth),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final subcategoryCount = _subcategoriesOf(category).length;
                  // Categories without subcategories open products directly,
                  // so show their product count instead of "0 subcategories".
                  final directCount = _numericValue(
                    category['directProductCount'],
                  ).toInt();
                  final countText = subcategoryCount > 0
                      ? l10n.categorySubcategoriesCount(subcategoryCount)
                      : l10n.commonItemsCount(directCount);
                  return _buildCatalogTile(
                    name: _getDisplayCategoryName(category),
                    imageUrl: category['image']?.toString() ?? '',
                    countText: countText,
                    icon: _categoryIcon(category['name']?.toString() ?? ''),
                    onTap: () => _onCategorySelected(index),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tileIcon(IconData icon, {double size = 28}) {
    return Center(
      child: HugeIcon(icon: icon, size: size, color: AppColors.primary),
    );
  }

  Widget _buildCatalogTile({
    required String name,
    required String imageUrl,
    required String countText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: '$name, $countText',
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surfaceLight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                clipBehavior: Clip.antiAlias,
                // The photo fills the tile edge to edge; the grey only shows
                // behind the icon while it loads or when there's no photo.
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ApiConfig.normalizeMediaUrl(imageUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        // Plain grey while the photo loads, no icon.
                        placeholder: (_, _) => const SizedBox.shrink(),
                        errorWidget: (_, _, _) => _tileIcon(icon),
                      )
                    : _tileIcon(icon),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              countText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryGrid(
    Map<String, dynamic> category,
    List<Map<String, dynamic>> subcategories,
  ) {
    final l10n = context.l10n;
    final directProductCount = _numericValue(
      category['directProductCount'],
    ).toInt();
    final hasDirectProducts = directProductCount > 0;
    final brand = _selectedBrand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanelHeader(
          onBack: _onBackToCategories,
          title: _getDisplayCategoryName(category),
          subtitle: brand != null
              ? _brandDisplayName(brand)
              : l10n.categorySelectType,
          count: l10n.categoryTypesCount(subcategories.length),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(12, 4, 12, _bottomInset),
                gridDelegate: _tileGrid(constraints.maxWidth),
                itemCount: subcategories.length + (hasDirectProducts ? 1 : 0),
                itemBuilder: (context, index) {
                  if (hasDirectProducts && index == 0) {
                    return _buildCatalogTile(
                      name: l10n.categoryOtherProducts,
                      imageUrl: category['image']?.toString() ?? '',
                      countText: l10n.commonItemsCount(directProductCount),
                      icon: HugeIcons.strokeRoundedPackage,
                      onTap: () => _onDirectProductsSelected(category),
                    );
                  }

                  final subcategoryIndex = index - (hasDirectProducts ? 1 : 0);
                  final subcategory = subcategories[subcategoryIndex];
                  return _buildCatalogTile(
                    name: localizedName(context, subcategory),
                    imageUrl: subcategory['image']?.toString() ?? '',
                    countText: l10n.commonItemsCount(
                      _numericValue(subcategory['productCount']).toInt(),
                    ),
                    icon: HugeIcons.strokeRoundedGridView,
                    onTap: () => _onSubcategorySelected(subcategory),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Products ----

  /// Products of a sub-category (or the category's own products), with the
  /// category's sub-categories as a chip row on top so shoppers can move
  /// between them without going back.
  Widget _buildProductStage() {
    final l10n = context.l10n;
    final category = _categories[_selectedCategoryIndex];
    final subcategories = _subcategoriesOf(category);
    final directCount = _numericValue(category['directProductCount']).toInt();
    final inSubcategory = _selectedSubcategory != null;
    final selectedChipId = inSubcategory
        ? 'sub:${_selectedSubcategory!['id']}'
        : 'direct';
    final brand = _selectedBrand;
    final loaded = !_isLoadingProducts && !_productLoadFailed;
    final bodyState = _isLoadingProducts
        ? 'loading'
        : (_productLoadFailed ? 'failed' : 'ready');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPanelHeader(
          onBack: _onBackToSubcategories,
          title: _getDisplayCategoryName(category),
          subtitle: brand != null ? _brandDisplayName(brand) : null,
          count: loaded ? l10n.commonItemsCount(_products.length) : null,
        ),
        if (subcategories.isNotEmpty)
          _buildSubcategoryChips(
            category,
            subcategories,
            directCount > 0,
            selectedChipId,
          ),
        Expanded(
          child: _switcher(
            '$selectedChipId|$bodyState',
            _buildProductBody(inSubcategory),
            begin: const Offset(0, 0.02),
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategoryChips(
    Map<String, dynamic> category,
    List<Map<String, dynamic>> subcategories,
    bool hasDirectProducts,
    String selectedChipId,
  ) {
    final l10n = context.l10n;
    final chips = <Widget>[
      if (hasDirectProducts)
        _buildSubcategoryChip(
          id: 'direct',
          label: l10n.categoryOtherProducts,
          imageUrl: category['image']?.toString() ?? '',
          icon: HugeIcons.strokeRoundedPackage,
          selectedChipId: selectedChipId,
          onTap: () => _onDirectProductsSelected(category),
        ),
      for (final subcategory in subcategories)
        _buildSubcategoryChip(
          id: 'sub:${subcategory['id']}',
          label: localizedName(context, subcategory),
          imageUrl: subcategory['image']?.toString() ?? '',
          icon: HugeIcons.strokeRoundedGridView,
          selectedChipId: selectedChipId,
          onTap: () => _onSubcategorySelected(subcategory),
        ),
    ];
    return SizedBox(
      height: 58,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryChip({
    required String id,
    required String label,
    required String imageUrl,
    required IconData icon,
    required String selectedChipId,
    required VoidCallback onTap,
  }) {
    final selected = id == selectedChipId;
    final token = '$_selectedCategoryIndex|$id';
    final duration = AppMotion.of(context, AppMotion.base);
    return Builder(
      builder: (chipContext) {
        if (selected && _ensuredChipToken != token) {
          // Bring the chosen sub-category into view when the row opens.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!chipContext.mounted || _ensuredChipToken == token) return;
            _ensuredChipToken = token;
            Scrollable.ensureVisible(
              chipContext,
              alignment: 0.5,
              duration: duration,
              curve: AppMotion.standard,
            );
          });
        }
        return Semantics(
          selected: selected,
          child: Pressable(
            onTap: () {
              if (!selected) onTap();
            },
            haptic: true,
            semanticLabel: label,
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected ? AppColors.primarySoft : AppColors.surfaceLight,
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.standard,
              height: 44,
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.surfaceLight
                          : AppColors.gray50,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(3),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ApiConfig.normalizeMediaUrl(imageUrl),
                            fit: BoxFit.contain,
                            placeholder: (_, _) => const SizedBox.shrink(),
                            errorWidget: (_, _, _) =>
                                _tileIcon(icon, size: 18),
                          )
                        : _tileIcon(icon, size: 18),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.primaryDeep
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductBody(bool inSubcategory) {
    final l10n = context.l10n;
    if (_isLoadingProducts) return _buildProductSkeleton();
    if (_productLoadFailed) {
      return _scrollableState(
        EmptyState(
          icon: HugeIcons.strokeRoundedWifiError01,
          title: l10n.categoryLoadProductsError,
          actionLabel: l10n.commonRetry,
          onAction: _retryProductLoad,
          tone: ChipTone.neutral,
          compact: true,
        ),
      );
    }
    if (_products.isEmpty) {
      return _scrollableState(
        EmptyState(
          icon: HugeIcons.strokeRoundedPackageSearch,
          title: inSubcategory
              ? l10n.categoryNoProductsInSubcategory
              : l10n.categoryNoProductsInCategory,
          actionLabel: inSubcategory
              ? l10n.categoryBackToTypes
              : l10n.categoryBackToCategories,
          onAction: _onBackToSubcategories,
          tone: ChipTone.neutral,
          compact: true,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _productGrid(constraints.maxWidth);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            grid.padding,
            4,
            grid.padding,
            _bottomInset,
          ),
          gridDelegate: grid.delegate,
          itemCount: _products.length,
          itemBuilder: (context, index) => _buildProductCard(_products[index]),
        );
      },
    );
  }

  Widget _buildProductSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _productGrid(constraints.maxWidth);
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(grid.padding, 4, grid.padding, 12),
          gridDelegate: grid.delegate,
          itemCount: grid.columns * 3,
          itemBuilder: (_, _) => const SkeletonProductCard(),
        );
      },
    );
  }

  /// Grid for product cards. The card's height is the square image plus its
  /// text block, so rows line up and nothing overflows.
  ({int columns, double padding, SliverGridDelegate delegate}) _productGrid(
    double maxWidth,
  ) {
    final isTablet = maxWidth >= 700;
    final columns = isTablet ? (maxWidth >= 1000 ? 4 : 3) : 2;
    final spacing = isTablet ? 14.0 : 10.0;
    final padding = isTablet ? 18.0 : 12.0;
    final cardWidth =
        (maxWidth - padding * 2 - spacing * (columns - 1)) / columns;
    final hasPackNote = _products.any((p) => packInfoOf(p).isPack);
    final hasPending = _products.any((p) => p['pendingPriceChange'] is Map);
    // Name (2 lines), rating, price (up to 2 lines), pack note, price notice.
    final text =
        2 +
        34 +
        20 +
        38 +
        (hasPackNote ? 16 : 0) +
        (hasPending ? 46 : 0) +
        12;
    // Image, card padding, stepper.
    final extent = (cardWidth - 12) + 12 + 10 + 42 + text * _textScale;
    return (
      columns: columns,
      padding: padding,
      delegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: extent,
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final l10n = context.l10n;
    final id = product['id']?.toString() ?? '';
    final price = _numericValue(product['price']);
    final mrp = _numericValue(product['mrp']);
    final hasDiscount = mrp > 0 && price < mrp;
    final rawRating = product['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '');
    final reviewCount = int.tryParse('${product['reviewCount'] ?? ''}');
    final pending = product['pendingPriceChange'];
    final inStock = product['inStock'] != false;
    final image = product['image']?.toString() ?? '';
    final packParts = catalogPackParts(l10n, product, price);

    return ProductCard(
      name: _getDisplayName(product),
      price: price,
      mrp: hasDiscount ? mrp : null,
      unit: catalogUnitSuffix(l10n, product),
      packNote: packParts?.label,
      packPrice: packParts?.price,
      imageUrl: image,
      category: product['category']?.toString() ?? '',
      // Stars only for products that have a rating.
      rating: (rating ?? 0) > 0 ? rating : null,
      reviewCount: reviewCount,
      inStock: inStock,
      soldOutLabel: l10n.commonOutOfStock,
      offLabel: (percent) => l10n.commonPercentOff('$percent'),
      comingSoon: isComingSoonProduct(product),
      comingSoonPrice: isPriceHidden(product) ? l10n.comingSoonPrice : null,
      extra: pending is Map<String, dynamic>
          ? PendingPriceChangeNotice(
              pendingPriceChange: pending,
              compact: true,
            )
          : null,
      onTap: () => context.push('/product/$id'),
      action: ProductCartStepper(
        productId: id,
        product: product,
        name: product['name']?.toString() ?? '',
        nameHindi: product['nameHindi']?.toString(),
        brand: product['brand']?.toString(),
        category: product['category']?.toString(),
        price: price,
        mrp: hasDiscount ? mrp : null,
        image: image,
        inStock: inStock,
      ),
    );
  }
}

/// A brand's logo on a white tile, or a shop icon when it has none.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo({
    required this.url,
    required this.size,
    this.highlighted = false,
  });

  final String url;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedStore01,
        size: size * 0.42,
        color: highlighted ? AppColors.primary : AppColors.textTertiary,
      ),
    );
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.base),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.08),
      child: url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}
