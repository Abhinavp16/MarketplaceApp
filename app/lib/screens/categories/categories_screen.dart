import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/guest_mode_provider.dart';

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../widgets/pending_price_change_notice.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

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
  static const Color primaryBlue = Color(0xFF134E4A);
  static const Color backgroundWhite = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFF1F5F9);

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
      });
      await _openRequestedDestination();
    } catch (e) {
      debugPrint('Error fetching catalog brands: $e');
      if (!mounted) return;
      setState(() {
        _brands = [];
        _isLoadingBrands = false;
        _isLoadingCategories = false;
      });
    }
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
        _products = allItems.map<Map<String, dynamic>>((item) {
          final name = item['name']?.toString() ?? '';
          return <String, dynamic>{
            'id': item['id']?.toString() ?? item['_id']?.toString() ?? '',
            'name': name,
            'nameHindi': item['nameHindi']?.toString() ?? '',
            'category': item['category']?.toString() ?? '',
            'price': catalogPriceForAudience(
              Map<String, dynamic>.from(item as Map),
              isCustomerPreview: ref.read(guestModeProvider),
            ),
            'mrp': item['mrp'] ?? 0,
            'image': ApiConfig.normalizeMediaUrl(
              item['primaryImage']?.toString() ?? '',
            ),
            'inStock': item['inStock'] != false,
            'shortDescription': item['shortDescription']?.toString() ?? '',
            'rating': item['averageRating'] ?? item['rating'] ?? 4.5,
            'reviewCount':
                item['ratingCount'] ??
                item['reviewCount'] ??
                item['reviews'] ??
                '',
            'pendingPriceChange': item['pendingPriceChange'],
          };
        }).toList()..sort(_compareProductsByPrice);

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
        _products = allItems.map<Map<String, dynamic>>((item) {
          final name = item['name']?.toString() ?? '';
          return <String, dynamic>{
            'id': item['id']?.toString() ?? item['_id']?.toString() ?? '',
            'name': name,
            'nameHindi': item['nameHindi']?.toString() ?? '',
            'category': item['category']?.toString() ?? '',
            'price': catalogPriceForAudience(
              Map<String, dynamic>.from(item as Map),
              isCustomerPreview: ref.read(guestModeProvider),
            ),
            'mrp': item['mrp'] ?? 0,
            'image': ApiConfig.normalizeMediaUrl(
              item['primaryImage']?.toString() ?? '',
            ),
            'inStock': item['inStock'] != false,
            'shortDescription': item['shortDescription']?.toString() ?? '',
            'rating': item['averageRating'] ?? item['rating'] ?? 4.5,
            'reviewCount':
                item['ratingCount'] ??
                item['reviewCount'] ??
                item['reviews'] ??
                '',
            'pendingPriceChange': item['pendingPriceChange'],
          };
        }).toList()..sort(_compareProductsByPrice);

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

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;

    // If price is 1 lakh or more, show in "L" format
    if (p >= 100000) {
      final lakhs = p / 100000;
      if (lakhs >= 10) {
        return '${lakhs.toStringAsFixed(0)}L';
      } else {
        return '${lakhs.toStringAsFixed(2)}L';
      }
    }

    // Show full number for amounts below 1 lakh (e.g., 6455 instead of 6.5K)
    return p.toStringAsFixed(0);
  }

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tractor')) return Icons.agriculture_rounded;
    if (lower.contains('harvest')) return Icons.grass_rounded;
    if (lower.contains('irrigat') || lower.contains('pump')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('seed') || lower.contains('plant')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('fertil') || lower.contains('chemic')) {
      return Icons.science_rounded;
    }
    if (lower.contains('tool') || lower.contains('equip')) {
      return Icons.build_rounded;
    }
    if (lower.contains('spray')) return Icons.shower_rounded;
    if (lower.contains('storage') || lower.contains('silo')) {
      return Icons.warehouse_rounded;
    }
    return Icons.category_rounded;
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

  @override
  Widget build(BuildContext context) {
    final content = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundWhite,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              // Main content
              Expanded(
                child: _isLoadingBrands
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      )
                    : _brands.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: primaryBlue,
                        child: ListView(
                          children: [
                            const SizedBox(height: 200),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 48,
                                    color: textMuted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.l10n.categoryNoBrands,
                                    style: AppFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          // The brand rail remains visible at every catalog stage.
                          _buildSidebar(),
                          // Vertical divider
                          Container(width: 1, color: borderLight),
                          // Right panel drills through category, subcategory, product.
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _handleRefresh,
                              color: primaryBlue,
                              child: _buildRightPanel(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.categoryTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.outfit(
                    fontSize: 28,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap:
                    widget.onSearchTap ??
                    () => context.go('/home', extra: {'tab': 1}),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: primaryBlue,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 6,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        borderLight.withValues(alpha: 0.0),
                        borderLight,
                        borderLight.withValues(alpha: 0.65),
                        borderLight.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 118,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        primaryBlue,
                        const Color(0xFF4F7DFF),
                        primaryBlue.withValues(alpha: 0.0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.18),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 88,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          final isSelected = _selectedBrandIndex == index;
          final imageUrl = brand['logo']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: GestureDetector(
              onTap: () => _selectBrand(index),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryBlue : surfaceWhite,
                  border: Border.all(
                    color: isSelected ? primaryBlue : borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Icon(
                                  Icons.storefront_rounded,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : textSecondary,
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.storefront_rounded,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : textSecondary,
                                ),
                              )
                            : Icon(
                                Icons.storefront_rounded,
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : textSecondary,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _brandDisplayName(brand),
                      style: AppFonts.outfit(
                        fontSize: 9,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected ? Colors.white : textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_isLoadingCategories) {
      return const Center(
        child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2),
      );
    }
    if (_categories.isEmpty) return _buildEmptyCategoryPanel();
    if (_stage == _CatalogStage.categories || _selectedCategoryIndex < 0) {
      return _buildCategoryGrid();
    }
    final cat = _categories[_selectedCategoryIndex];
    final subs = _subcategoriesOf(cat);
    if (_stage == _CatalogStage.subcategories) {
      return _buildSubcategoryGrid(cat, subs);
    }
    return _buildProductGrid();
  }

  Widget _buildEmptyCategoryPanel() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 180),
        Icon(
          Icons.category_outlined,
          size: 48,
          color: textMuted.withOpacity(0.4),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _selectedBrandIndex == -1
                ? context.l10n.categoryBrandNotFound
                : context.l10n.categoryNoCategoriesForBrand,
            textAlign: TextAlign.center,
            style: AppFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final brand =
        _selectedBrandIndex >= 0 && _selectedBrandIndex < _brands.length
        ? _brands[_selectedBrandIndex]
        : const <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _brandDisplayName(brand),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      context.l10n.categorySelectCategory,
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCountBadge(
                context.l10n.categoryCategoriesCount(_categories.length),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final catalogColumns = constraints.maxWidth >= 700 ? 3 : 2;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: catalogColumns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
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
                      ? context.l10n.categorySubcategoriesCount(
                          subcategoryCount,
                        )
                      : context.l10n.commonItemsCount(directCount);
                  return _buildCatalogCard(
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

  Widget _buildCountBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: primaryBlue,
        ),
      ),
    );
  }

  Widget _buildCatalogCard({
    required String name,
    required String imageUrl,
    required String countText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ApiConfig.normalizeMediaUrl(imageUrl),
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Icon(icon, color: primaryBlue, size: 24),
                        errorWidget: (_, __, ___) =>
                            Icon(icon, color: primaryBlue, size: 24),
                      )
                    : Icon(icon, color: primaryBlue, size: 26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              countText,
              style: AppFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.commonView,
                    style: AppFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ],
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
    final directProductCount = _numericValue(
      category['directProductCount'],
    ).toInt();
    final hasDirectProducts = directProductCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _onBackToCategories,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: textPrimary,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: borderLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayCategoryName(category),
                      style: AppFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      _selectedBrandIndex >= 0 &&
                              _selectedBrandIndex < _brands.length
                          ? _brandDisplayName(_brands[_selectedBrandIndex])
                          : context.l10n.categorySelectType,
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCountBadge(
                context.l10n.categoryTypesCount(subcategories.length),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final catalogColumns = constraints.maxWidth >= 700 ? 3 : 2;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: catalogColumns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
                itemCount: subcategories.length + (hasDirectProducts ? 1 : 0),
                itemBuilder: (context, index) {
                  if (hasDirectProducts && index == 0) {
                    return _buildCatalogCard(
                      name: context.l10n.categoryOtherProducts,
                      imageUrl: category['image']?.toString() ?? '',
                      countText: context.l10n.commonItemsCount(
                        directProductCount,
                      ),
                      icon: Icons.inventory_2_outlined,
                      onTap: () {
                        setState(() {
                          _selectedSubcategory = null;
                          _stage = _CatalogStage.products;
                          _showingDirectCategoryProducts = true;
                        });
                        _fetchProductsForCategory(category);
                      },
                    );
                  }

                  final subcategoryIndex = index - (hasDirectProducts ? 1 : 0);
                  final subcategory = subcategories[subcategoryIndex];
                  return _buildCatalogCard(
                    name: localizedName(context, subcategory),
                    imageUrl: subcategory['image']?.toString() ?? '',
                    countText: context.l10n.commonItemsCount(
                      _numericValue(subcategory['productCount']).toInt(),
                    ),
                    icon: Icons.category_rounded,
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

  Widget _buildBackHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _onBackToSubcategories,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: textPrimary,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: borderLight),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: AppFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              context.l10n.commonItemsCount(_products.length),
              style: AppFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoadingProducts) {
      return const Center(
        child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2),
      );
    }

    final bool inSubcategory = _selectedSubcategory != null;
    final String headerTitle = inSubcategory
        ? localizedName(context, _selectedSubcategory)
        : (_categories.isNotEmpty
              ? _getDisplayCategoryName(_categories[_selectedCategoryIndex])
              : '');
    final String headerSubtitle = inSubcategory && _categories.isNotEmpty
        ? _getDisplayCategoryName(_categories[_selectedCategoryIndex])
        : (_selectedBrandIndex >= 0 && _selectedBrandIndex < _brands.length
              ? _brandDisplayName(_brands[_selectedBrandIndex])
              : '');

    if (_productLoadFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackHeader(headerTitle, headerSubtitle),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.categoryLoadProductsError,
                    style: AppFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _retryProductLoad,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_products.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackHeader(headerTitle, headerSubtitle),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: textMuted.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    inSubcategory
                        ? context.l10n.categoryNoProductsInSubcategory
                        : context.l10n.categoryNoProductsInCategory,
                    style: AppFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _onBackToSubcategories,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      inSubcategory
                          ? context.l10n.categoryBackToTypes
                          : context.l10n.categoryBackToCategories,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;
        final gridColumns = isTablet
            ? (constraints.maxWidth >= 1000 ? 4 : 3)
            : 2;
        final gridSpacing = isTablet ? 14.0 : 10.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackHeader(headerTitle, headerSubtitle),
            // Products grid
            Expanded(
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 18 : 12,
                  4,
                  isTablet ? 18 : 12,
                  100,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: gridSpacing,
                  childAspectRatio: isTablet ? 0.72 : 0.48,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) =>
                    _buildProductCard(_products[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final hasMrp =
        product['mrp'] != null &&
        product['mrp'] != product['price'] &&
        (product['mrp'] as num) > 0;
    final rating = product['rating'];
    final discount = hasMrp
        ? (((product['mrp'] as num) - (product['price'] as num)) /
                  (product['mrp'] as num) *
                  100)
              .round()
        : 0;

    return GestureDetector(
      onTap: () => context.push('/product/${product['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(4),
          // border: Border.all(color: borderLight, width: 1), // Removed outer border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex:
                  22, // Reduced from 3 to 2.2 (Integer multiplied by 10 for safety)
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product['image'] != null &&
                            product['image'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: product['image'],
                              fit: BoxFit.contain,
                              placeholder: (_, __) => ProductImagePlaceholder(
                                category: product['category']?.toString() ?? '',
                                name: product['name']?.toString() ?? '',
                              ),
                              errorWidget: (_, __, ___) =>
                                  ProductImagePlaceholder(
                                    category:
                                        product['category']?.toString() ?? '',
                                    name: product['name']?.toString() ?? '',
                                  ),
                            ),
                          )
                        : ProductImagePlaceholder(
                            category: product['category']?.toString() ?? '',
                            name: product['name']?.toString() ?? '',
                          ),
                    if (discount > 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            context.l10n.commonPercentOff('$discount'),
                            style: AppFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    if (product['inStock'] == false)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.7),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              context.l10n.commonOutOfStock,
                              style: AppFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 20, // Re-scaled to match 2.2:2.0 as 22:20
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height:
                            44, // More compact but still fits 3 lines tightly
                        child: Text(
                          _getDisplayName(product),
                          style: AppFonts.outfit(
                            fontSize: 12.5,
                            fontWeight:
                                FontWeight.w600, // Make it a bit more readable
                            color: textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 1), // Reduced gap
                      // Star rating visualization (Showing always as requested)
                      Row(
                        children: [
                          Text(
                            rating is num
                                ? rating.toDouble().toStringAsFixed(1)
                                : (double.tryParse(
                                        rating?.toString() ?? '',
                                      )?.toStringAsFixed(1) ??
                                      '4.5'),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            children: List.generate(5, (index) {
                              final rv = (rating != null)
                                  ? ((rating is num)
                                        ? rating.toDouble()
                                        : double.tryParse(rating.toString()) ??
                                              0.0)
                                  : 0.0;
                              final starIndex = index + 1;
                              if (rv >= starIndex) {
                                return const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFFF59E0B),
                                );
                              } else if (rv >= starIndex - 0.5) {
                                return const Icon(
                                  Icons.star_half_rounded,
                                  size: 14,
                                  color: Color(0xFFF59E0B),
                                );
                              } else {
                                return const Icon(
                                  Icons.star_outline_rounded,
                                  size: 14,
                                  color: Color(0xFFCBD5E1),
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 2,
                      ), // Significantly reduced gap to move price up
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '₹${_formatPrice(product['price'])}',
                              style: AppFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasMrp) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '₹${_formatPrice(product['mrp'])}',
                                style: AppFonts.outfit(
                                  fontSize: 10,
                                  color: const Color(0xFFEF4444),
                                  decoration: TextDecoration.lineThrough,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      PendingPriceChangeNotice(
                        pendingPriceChange:
                            product['pendingPriceChange']
                                as Map<String, dynamic>?,
                        compact: true,
                        primaryColor: textPrimary,
                        accentColor: const Color(0xFFB45309),
                        backgroundColor: const Color(0xFFFFF7ED),
                      ),
                      const SizedBox(
                        height: 6,
                      ), // Replaces Spacer for predictable height
                      SizedBox(
                        width: double.infinity,
                        height: 26, // Reduced button height
                        child: ElevatedButton(
                          onPressed: () =>
                              context.push('/product/${product['id']}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            context.l10n.categoryViewProduct,
                            style: AppFonts.jakarta(
                              fontSize: 10,
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
          ],
        ),
      ),
    );
  }
}
