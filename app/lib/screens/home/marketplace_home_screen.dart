import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/providers/locale_provider.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../core/config/api_config.dart';
import '../../core/config/feature_flags.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../core/services/redeemed_coupon_service.dart';
import '../../core/services/shipping_address_service.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../core/services/storage_service.dart';
import '../categories/categories_screen.dart';
import '../profile/legal_policy_screen.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../widgets/app_image.dart';
import '../../widgets/notification_countdown_label.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/order_count_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/deal_desk_presentation.dart';
import '../../core/utils/product_search.dart';
import '../../core/utils/recent_searches.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_fonts.dart';

enum _SearchScope { product, brand, category }

class MarketplaceHomeScreen extends ConsumerStatefulWidget {
  final int? initialTab;
  final String? initialSearchQuery;
  const MarketplaceHomeScreen({
    super.key,
    this.initialTab,
    this.initialSearchQuery,
  });

  @override
  ConsumerState<MarketplaceHomeScreen> createState() =>
      _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends ConsumerState<MarketplaceHomeScreen> {
  static const String _internalGeneralProductsBrand = 'GENERAL PRODUCTS';
  static const Duration _guestInitialFreeUseDuration = Duration(minutes: 3);
  static const Duration _guestPromptRepeatDuration = Duration(hours: 24);
  late int _selectedNavIndex;
  bool _isCheckingOut = false;
  int _currentCarouselIndex = 0;
  final PageController _carouselController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // Use ApiConfig.baseUrl - update the IP in lib/core/config/api_config.dart
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
  // Blue Theme Colors - Apple-like design
  static const Color primaryBlue = Color(0xFF134E4A);
  static const Color primaryBlueDark = Color(0xFF115E59);
  static const Color backgroundWhite = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFF1F5F9);

  // State for dynamic data
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _featuredProducts = [];
  List<Map<String, dynamic>> _hotProducts = [];
  bool _isLoadingBrands = true;
  bool _isLoadingProducts = true;

  // Search state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingMoreSearch = false;
  bool _searchHasNext = false;
  int _searchPage = 0;
  int _searchRequestGeneration = 0;
  CancelToken? _searchCancelToken;
  String? _searchError;
  String _searchQuery = '';
  _SearchScope _searchScope = _SearchScope.product;
  Timer? _searchDebounce;
  List<String> _recentSearches = [];

  // Filter state
  String? _selectedFilterCategoryId;
  String? _selectedFilterBrandId;
  List<Map<String, dynamic>> _categoryData = [];
  List<Map<String, dynamic>> _searchCategoryData = [];
  bool _isLoadingCategories = true;
  final CategoriesController _categoriesController = CategoriesController();
  int _categoryNavigationRequest = 0;
  String? _requestedCategoryId;
  String? _requestedCategoryName;
  String? _requestedCategoryBrandId;

  // Hero banners from API (top carousel)
  List<Map<String, dynamic>> _heroBanners = [];
  bool _isLoadingHeroBanners = true;
  Timer? _heroAutoRotateTimer;

  // Promo banners from API (second carousel)
  List<Map<String, dynamic>> _promoBanners = [];
  bool _isLoadingPromoBanners = true;
  int _currentPromoBannerIndex = 0;
  final PageController _promoBannerController = PageController();
  Timer? _promoAutoRotateTimer;

  // Notification state
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoadingNotifications = false;
  StateSetter? _dialogSetter;
  DateTime? _lastNotificationPopupFetchAt;

  // Offers state
  List<Map<String, dynamic>> _offers = [];
  bool _isLoadingOffers = true;

  // Reviews state
  List<Map<String, dynamic>> _dynamicReviews = [];
  bool _isLoadingReviews = true;

  // Dealer home sections (wholesalers only)
  List<Map<String, dynamic>> _homeOrders = [];
  bool _isLoadingHomeOrders = false;
  List<Map<String, dynamic>> _scheduledChanges = [];
  bool _isLoadingScheduledChanges = false;
  String? _repeatingOrderId;
  Timer? _guestAuthPromptTimer;
  bool _isGuestAuthDialogVisible = false;

  @override
  void initState() {
    super.initState();
    final isCustomerPreview = ref.read(guestModeProvider);
    _selectedNavIndex = widget.initialTab ?? 0;
    _loadRecentSearches();
    _fetchBrands();
    _fetchProducts();
    _fetchCategories();
    _fetchPromoBanners();
    _fetchOffers();
    _fetchReviews();
    if (!isCustomerPreview) {
      _loadSavedShippingAddresses();
      _initNotifications();
      _fetchNotificationCount();
    }

    // Fetch cart from server so it persists across app restarts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialSearchRouteState();
      if (!ref.read(guestModeProvider)) {
        ref.read(cartProvider.notifier).fetchCart();
      }
      _startAutoRotate();
      _initGuestAuthPromptFlow();
      _fetchNegotiations();
      _fetchHomeOrders();
      _fetchScheduledChanges();
    });
  }

  @override
  void didUpdateWidget(covariant MarketplaceHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialSearchQuery != widget.initialSearchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyInitialSearchRouteState();
        }
      });
    }
  }

  void _applyInitialSearchRouteState() {
    final requestedQuery = widget.initialSearchQuery?.trim() ?? '';
    final targetTab = requestedQuery.isNotEmpty ? 1 : (widget.initialTab ?? 0);

    if (_selectedNavIndex != targetTab) {
      setState(() => _selectedNavIndex = targetTab);
    }

    if (targetTab != 1) {
      return;
    }

    if (requestedQuery.isNotEmpty && _searchController.text != requestedQuery) {
      _searchScope = _SearchScope.product;
      _searchController
        ..text = requestedQuery
        ..selection = TextSelection.collapsed(offset: requestedQuery.length);
      _searchProducts(requestedQuery);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _initGuestAuthPromptFlow() async {
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) return;

    final trialStartAt = await StorageService.getOrCreateGuestTrialStartedAt();
    if (!mounted) return;

    final lastPromptAt = await StorageService.getGuestAuthPromptLastShownAt();
    if (!mounted) return;

    if (lastPromptAt != null) {
      final repeatDelay =
          _guestPromptRepeatDuration - DateTime.now().difference(lastPromptAt);
      if (repeatDelay.isNegative || repeatDelay == Duration.zero) {
        _showGuestAuthPrompt();
      } else {
        _guestAuthPromptTimer?.cancel();
        _guestAuthPromptTimer = Timer(repeatDelay, _showGuestAuthPrompt);
      }
      return;
    }

    final elapsed = DateTime.now().difference(trialStartAt);
    final initialDelay = _guestInitialFreeUseDuration - elapsed;
    if (initialDelay.isNegative || initialDelay == Duration.zero) {
      _showGuestAuthPrompt();
      return;
    }

    _guestAuthPromptTimer?.cancel();
    _guestAuthPromptTimer = Timer(initialDelay, _showGuestAuthPrompt);
  }

  void _scheduleNextGuestPrompt() {
    _guestAuthPromptTimer?.cancel();
    _guestAuthPromptTimer = Timer(_guestPromptRepeatDuration, () {
      _showGuestAuthPrompt();
    });
  }

  bool _isAuthRouteActive() {
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    const authPaths = <String>{'/login', '/signup'};
    return authPaths.any(
      (path) => currentPath == path || currentPath.startsWith('$path/'),
    );
  }

  Future<void> _showGuestAuthPrompt() async {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated || _isGuestAuthDialogVisible) return;

    // Don't show popup on auth routes
    if (_isAuthRouteActive()) {
      _scheduleNextGuestPrompt();
      return;
    }

    _isGuestAuthDialogVisible = true;
    await StorageService.setGuestAuthPromptLastShownAt(DateTime.now());
    if (!mounted) {
      _isGuestAuthDialogVisible = false;
      return;
    }
    final shouldOpenLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.homeGuestPromptTitle),
          content: Text(context.l10n.homeGuestPromptMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonSkip),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.homeLoginOrSignUp),
            ),
          ],
        );
      },
    );
    _isGuestAuthDialogVisible = false;

    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) return;

    if (shouldOpenLogin == true) {
      context.push('/login');
    }
    _scheduleNextGuestPrompt();
  }

  Future<void> _initNotifications() async {
    try {
      await ref.read(notificationServiceProvider).initialize();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await _dio.get('/reviews');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        setState(() {
          _dynamicReviews = data
              .map((item) => item as Map<String, dynamic>)
              .toList();
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _fetchBrands() async {
    try {
      debugPrint('🔵 [BRANDS] Starting fetch from: ${_dio.options.baseUrl}');
      final response = await _dio.get(
        '/companies',
        queryParameters: {'active': true, 'limit': 500},
      );
      if (!mounted) return;
      debugPrint('🟢 [BRANDS] Response status: ${response.statusCode}');
      debugPrint('🟢 [BRANDS] Response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['data'] ?? data ?? [];
        debugPrint('🟢 [BRANDS] Found ${items.length} brands');

        setState(() {
          final fetched = items
              .map<Map<String, dynamic>>(
                (item) => <String, dynamic>{
                  'id': item['_id']?.toString() ?? item['id']?.toString() ?? '',
                  'name': item['name']?.toString() ?? '',
                  'logo': item['logo'] is Map
                      ? item['logo']['url']?.toString() ?? ''
                      : item['logo']?.toString() ?? '',
                  'slug': item['slug']?.toString() ?? '',
                  'order': item['order'] ?? 0,
                },
              )
              .where(
                (brand) =>
                    brand['name']?.toString().trim().toUpperCase() !=
                    _internalGeneralProductsBrand,
              )
              .toList();

          // Sort brands by their configured order
          fetched.sort((a, b) {
            final nameA = a['name']?.toString().toUpperCase() ?? '';
            final nameB = b['name']?.toString().toUpperCase() ?? '';
            final orderA = int.tryParse(a['order']?.toString() ?? '') ?? 0;
            final orderB = int.tryParse(b['order']?.toString() ?? '') ?? 0;
            if (orderA != orderB) return orderA.compareTo(orderB);
            return nameA.compareTo(nameB);
          });

          debugPrint('🟢 [BRANDS] Final brand count: ${fetched.length}');
          // Use empty list if API returns nothing (shimmer/empty state will show)
          _brands = fetched.isEmpty ? [] : fetched;
          _isLoadingBrands = false;
        });
      } else {
        debugPrint(
          '🔴 [BRANDS] ERROR: Unexpected status code: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [BRANDS] ERROR: $e');
      debugPrint('🔴 [BRANDS] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _brands = [];
        _isLoadingBrands = false;
      });
    }
  }

  /// Returns empty string when no valid URL found — the [ProductImagePlaceholder]
  /// widget will render a beautiful category-specific illustration instead.
  static String _fallbackImageFor(String name, String category) {
    return ''; // ProductImagePlaceholder handles the display
  }

  List<Map<String, dynamic>> _mapProductItems(List<dynamic> items) {
    final productsById = <String, Map<String, dynamic>>{};
    for (final rawItem in items.whereType<Map>()) {
      final item = Map<String, dynamic>.from(rawItem);
      final name = item['name']?.toString() ?? '';
      final category = (item['category'] ?? item['categoryName'] ?? '')
          .toString();
      String image =
          (item['primaryImage'] ??
                  item['image'] ??
                  item['imageUrl'] ??
                  item['photo'] ??
                  item['thumbnail'] ??
                  item['img'] ??
                  '')
              .toString()
              .trim();
      image = ApiConfig.normalizeMediaUrl(image);
      final hasValidImage =
          image.startsWith('http://') || image.startsWith('https://');
      final id = item['id']?.toString() ?? item['_id']?.toString() ?? '';
      if (id.isEmpty) continue;

      productsById[id] = <String, dynamic>{
        'id': id,
        'name': name,
        'nameHindi': item['nameHindi']?.toString() ?? '',
        'category': category,
        'brand': item['brand']?.toString() ?? '',
        'price': catalogPriceForAudience(
          item,
          isCustomerPreview: ref.read(guestModeProvider),
        ),
        'originalPrice': item['mrp'] ?? item['originalPrice'] ?? 0,
        'image': hasValidImage ? image : _fallbackImageFor(name, category),
        'blurHash': item['primaryBlurHash'] ?? item['blurHash'] ?? '',
        'isFeatured': item['isFeatured'] == true,
        'isHot': item['isHot'] == true,
        'isNew': item['isNew'] == true,
        'inStock': item['inStock'] != false,
        'discount': 0,
        'rating': item['rating'] ?? 4.5,
        'reviewCount': item['reviewCount'] ?? item['reviews'] ?? '',
        'purchaseCountMin': item['purchaseCountMin'] ?? 0,
        'purchaseCountMax': item['purchaseCountMax'] ?? 0,
        'minWholesaleQuantity': item['minWholesaleQuantity'],
        'pendingPriceChange': item['pendingPriceChange'],
      };
    }
    return productsById.values.toList();
  }

  Future<void> _fetchProducts() async {
    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔵 [PRODUCTS] Starting fetch');
      debugPrint('🔵 [PRODUCTS] Base URL: ${_dio.options.baseUrl}');
      debugPrint('═══════════════════════════════════════════');

      debugPrint('🔵 [PRODUCTS] Fetching: ${_dio.options.baseUrl}/products');
      final responses = await Future.wait([
        _dio.get('/products'),
        _dio.get('/products', queryParameters: {'featured': true, 'limit': 6}),
        _dio.get('/products', queryParameters: {'hot': true, 'limit': 6}),
      ]);
      if (!mounted) return;
      final response = responses[0];

      debugPrint('═══════════════════════════════════════════');
      debugPrint('🟢 [PRODUCTS] API Call Successful!');
      debugPrint('🟢 [PRODUCTS] Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint(
          '🟢 [PRODUCTS] Response Keys: ${data is Map ? (data as Map).keys.toList() : 'N/A'}',
        );

        final List<dynamic> items = data['data'] ?? data ?? [];
        final List<dynamic> featuredItems =
            responses[1].data['data'] ?? const [];
        final List<dynamic> hotItems = responses[2].data['data'] ?? const [];

        debugPrint('═══════════════════════════════════════════');
        debugPrint('🟢 [PRODUCTS] TOTAL ITEMS FOUND: ${items.length}');
        debugPrint('═══════════════════════════════════════════');

        if (items.isNotEmpty) {
          debugPrint(
            '🟢 [PRODUCTS] First item keys: ${items.first is Map ? (items.first as Map).keys.toList() : 'N/A'}',
          );
        }

        setState(() {
          final fetched = _mapProductItems(items);
          debugPrint('═══════════════════════════════════════════');
          debugPrint(
            '🟢 [PRODUCTS] FINAL STATE UPDATE: ${fetched.length} products',
          );
          debugPrint('═══════════════════════════════════════════');
          _products = fetched.isEmpty ? [] : fetched;
          _featuredProducts = _mapProductItems(featuredItems);
          _hotProducts = _mapProductItems(hotItems);
          _isLoadingProducts = false;
        });
        // Backfill scheduled-change cards from loaded products when the
        // dedicated endpoint is unavailable (backend not deployed yet).
        if (_isWholesaler && _scheduledChanges.isEmpty && mounted) {
          setState(_deriveScheduledFromProducts);
        }
      } else {
        debugPrint(
          '🔴 [PRODUCTS] ERROR: Unexpected status code: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔴🔴🔴 [PRODUCTS] EXCEPTION CAUGHT 🔴🔴🔴');
      debugPrint('🔴 [PRODUCTS] Error: $e');
      debugPrint('🔴 [PRODUCTS] Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════════');
      if (!mounted) return;
      setState(() {
        _products = [];
        _featuredProducts = [];
        _hotProducts = [];
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      debugPrint(
        '🔵 [CATEGORIES] Fetching from /categories/with-subcategories endpoint',
      );
      // Use the same endpoint as categories screen for consistency
      final response = await _dio.get(
        '/categories/with-subcategories',
        queryParameters: {'active': true},
      );
      if (!mounted) return;
      debugPrint('🟢 [CATEGORIES] Response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> items = response.data['data'] ?? [];
        debugPrint('🟢 [CATEGORIES] Found ${items.length} root categories');
        final mappedCategories =
            items
                .map<Map<String, dynamic>>((item) {
                  final name = item['name']?.toString() ?? '';
                  final imageUrl = item['image'] is Map
                      ? item['image']['url']?.toString() ?? ''
                      : item['image']?.toString() ?? '';
                  return {
                    'id':
                        item['id']?.toString() ?? item['_id']?.toString() ?? '',
                    'name': name,
                    'displayName': name,
                    'queryName': name,
                    'nameHindi': item['nameHindi']?.toString() ?? '',
                    'image': imageUrl,
                    'blurHash': null,
                    'slug': item['slug']?.toString() ?? '',
                    'brandId': item['company'] is Map
                        ? item['company']['id']?.toString() ??
                              item['company']['_id']?.toString() ??
                              ''
                        : '',
                    'brandName': item['company'] is Map
                        ? item['company']['name']?.toString() ?? ''
                        : '',
                    'count': _effectiveCategoryCount(item),
                    'order': item['order'] ?? 999,
                  };
                })
                .where((item) => (item['name'] as String).isNotEmpty)
                .toList()
              ..sort((a, b) {
                final orderA =
                    int.tryParse(a['order']?.toString() ?? '999') ?? 999;
                final orderB =
                    int.tryParse(b['order']?.toString() ?? '999') ?? 999;
                return orderA.compareTo(orderB);
              });

        setState(() {
          _searchCategoryData = mappedCategories;
          _categoryData = mappedCategories.where(_categoryHasProducts).toList();
          debugPrint(
            '🟢 [CATEGORIES] Final category count: ${_categoryData.length}',
          );
          debugPrint(
            '🟢 [CATEGORIES] Category order: ${_categoryData.map((c) => '${c['name']}(${c['order']})').join(', ')}',
          );
          _isLoadingCategories = false;
        });
      } else {
        debugPrint('🔴 [CATEGORIES] ERROR: Unexpected status or data');
        setState(() => _isLoadingCategories = false);
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [CATEGORIES] ERROR: $e');
      debugPrint('🔴 [CATEGORIES] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
    }
  }

  bool _categoryHasProducts(Map<String, dynamic> category) {
    final rawCount = category['count'];
    if (rawCount == null) return true;
    if (rawCount is num) return rawCount > 0;
    return int.tryParse(rawCount.toString()) != null
        ? int.parse(rawCount.toString()) > 0
        : true;
  }

  /// Root categories hold products in subcategories, so the effective count
  /// includes subcategory productCounts (matches Categories tab behaviour).
  int _effectiveCategoryCount(Map item) {
    int total = int.tryParse(item['productCount']?.toString() ?? '') ?? 0;
    final subs = item['subcategories'];
    if (subs is List) {
      for (final sub in subs) {
        if (sub is Map) {
          total += int.tryParse(sub['productCount']?.toString() ?? '') ?? 0;
        }
      }
    }
    return total;
  }

  String _normalizedCategoryKey(String value) => value.trim().toLowerCase();

  Set<String> _categoryLookupKeys(String value) {
    final spaced = value.trim().replaceAll(RegExp(r'[-_]+'), ' ');
    final normalized = _normalizedCategoryKey(
      spaced,
    ).replaceAll(RegExp(r'\s+'), ' ');
    final withoutDashWord = normalized
        .replaceAll(RegExp(r'\bdash\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final withDashWord = normalized.replaceAllMapped(
      RegExp(r'\bv\s+(\d+)\b'),
      (match) => 'v dash ${match[1]}',
    );

    return {
      _normalizedCategoryKey(value),
      normalized,
      withoutDashWord,
      withDashWord,
    }..removeWhere((key) => key.isEmpty);
  }

  Map<String, dynamic> _categoryMetadataFor(
    Map<String, Map<String, dynamic>> metadataByKey,
    String value,
  ) {
    for (final key in _categoryLookupKeys(value)) {
      final metadata = metadataByKey[key];
      if (metadata != null) return metadata;
    }
    return {};
  }

  Map<String, Map<String, dynamic>> _buildCategoryMetadataMap(
    List<dynamic> items,
  ) {
    final metadataByKey = <String, Map<String, dynamic>>{};

    for (final item in items) {
      final entries = _categoryMetadataEntries(item);
      for (final entry in entries.entries) {
        final current = metadataByKey[entry.key];
        if (current == null ||
            _categoryMetadataPriority(entry.value) >
                _categoryMetadataPriority(current)) {
          metadataByKey[entry.key] = entry.value;
        }
      }
    }

    return metadataByKey;
  }

  int _categoryMetadataPriority(Map<String, dynamic> metadata) {
    final productCount =
        int.tryParse(metadata['productCount']?.toString() ?? '') ?? 0;
    final activeBonus = metadata['isActive'] == true ? 10 : 0;
    final websiteBonus = metadata['showOnWebsite'] == true ? 5 : 0;
    return (productCount * 100) + activeBonus + websiteBonus;
  }

  Map<String, Map<String, dynamic>> _categoryMetadataEntries(dynamic item) {
    if (item is! Map) return {};

    final slug = item['slug']?.toString() ?? '';
    final payload = {
      'name': item['name']?.toString() ?? '',
      'slug': slug,
      'nameHindi': item['nameHindi']?.toString() ?? '',
      'image': _extractCategoryImageUrl(item),
      'blurHash': item['image'] is Map
          ? item['image']['blurHash']?.toString()
          : null,
      'isActive': item['isActive'] == true,
      'showOnWebsite': item['showOnWebsite'] == true,
      'productCount': item['productCount'] ?? 0,
    };

    final keys = <String>{
      ..._categoryLookupKeys(item['name']?.toString() ?? ''),
      ..._categoryLookupKeys(slug),
    }..removeWhere((key) => key.isEmpty);

    return {for (final key in keys) key: payload};
  }

  String _extractCategoryImageUrl(dynamic item) {
    if (item is! Map) return '';
    final image = item['image'];
    final rawUrl = image is Map ? image['url']?.toString() ?? '' : image;
    return _resolveCategoryImageUrl(rawUrl?.toString() ?? '');
  }

  String _resolveCategoryImageUrl(String imageUrl) {
    return ApiConfig.normalizeMediaUrl(imageUrl);
  }

  String _resolveBannerImageUrl(String imageUrl) {
    return ApiConfig.normalizeMediaUrl(imageUrl);
  }

  Future<void> _fetchPromoBanners() async {
    try {
      final response = await _dio.get('/settings/banners');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? {};
        final List<dynamic> heroItems = data['heroBanners'] ?? [];
        final List<dynamic> promoItems = data['promoBanners'] ?? [];

        setState(() {
          if (heroItems.isNotEmpty) {
            _heroBanners = heroItems
                .map<Map<String, dynamic>>(
                  (item) => <String, dynamic>{
                    'title': item['title']?.toString() ?? '',
                    'subtitle': item['subtitle']?.toString() ?? '',
                    'tag': item['tag']?.toString() ?? '',
                    'imageUrl': _resolveBannerImageUrl(
                      item['imageUrl']?.toString() ?? '',
                    ),
                    'mediaType': item['mediaType']?.toString() ?? 'image',
                    'videoUrl': _resolveBannerImageUrl(
                      item['videoUrl']?.toString() ?? '',
                    ),
                    'linkUrl': item['linkUrl']?.toString() ?? '',
                    'buttonText': item['buttonText']?.toString() ?? '',
                    'buttonIcon': item['buttonIcon']?.toString() ?? '',
                  },
                )
                .toList();
          }
          if (promoItems.isNotEmpty) {
            _promoBanners = promoItems
                .map<Map<String, dynamic>>(
                  (item) => <String, dynamic>{
                    'title': item['title']?.toString() ?? '',
                    'subtitle': item['subtitle']?.toString() ?? '',
                    'tag': item['tag']?.toString() ?? '',
                    'imageUrl': _resolveBannerImageUrl(
                      item['imageUrl']?.toString() ?? '',
                    ),
                    'linkUrl': item['linkUrl']?.toString() ?? '',
                    'buttonText': item['buttonText']?.toString() ?? '',
                    'buttonIcon': item['buttonIcon']?.toString() ?? '',
                  },
                )
                .toList();
          }
        });
        _startAutoRotate();
      }
    } catch (e) {
      debugPrint('Error fetching banners: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHeroBanners = false;
          _isLoadingPromoBanners = false;
        });
      }
    }
  }

  Future<void> _fetchOffers() async {
    try {
      final auth = ref.read(authProvider);
      String targetGroup;

      if (ref.read(guestModeProvider)) {
        targetGroup = 'buyer';
      } else if (auth.isAuthenticated) {
        // User is logged in - use their role
        targetGroup = auth.user?.role ?? 'buyer';
      } else {
        // Guest user - show customer/buyer offers
        targetGroup = 'buyer';
      }

      final response = await _dio.get(
        '/offers',
        queryParameters: {'targetGroup': targetGroup},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['data'] ?? [];
        setState(() {
          _offers = items.map<Map<String, dynamic>>((item) {
            final discountType = item['discountType']?.toString() ?? '';
            final discountValue = item['discountValue'];
            return {
              'title': item['title'] ?? '',
              'discount': discountType == 'percentage'
                  ? '$discountValue%'
                  : '₹$discountValue',
              'type': discountType,
              'value': discountValue,
              'code': item['code']?.toString(),
            };
          }).toList();
          _isLoadingOffers = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching offers: $e');
      if (!mounted) return;
      setState(() => _isLoadingOffers = false);
      // For guest users, try fetching buyer offers as fallback
      final auth = ref.read(authProvider);
      if (ref.read(guestModeProvider) || !auth.isAuthenticated) {
        try {
          final response = await _dio.get(
            '/offers',
            queryParameters: {'targetGroup': 'buyer'},
          );
          if (!mounted) return;
          if (response.statusCode == 200) {
            final List<dynamic> items = response.data['data'] ?? [];
            if (items.isNotEmpty && mounted) {
              setState(() {
                _offers = items.map<Map<String, dynamic>>((item) {
                  final discountType = item['discountType']?.toString() ?? '';
                  final discountValue = item['discountValue'];
                  return {
                    'title': item['title'] ?? '',
                    'discount': discountType == 'percentage'
                        ? '$discountValue%'
                        : '₹$discountValue',
                    'type': discountType,
                    'value': discountValue,
                    'code': item['code']?.toString(),
                  };
                }).toList();
              });
            }
          }
        } catch (e2) {
          debugPrint('Error fetching buyer offers fallback: $e2');
        }
      }
    }
  }

  void _goToNextHeroSlide() {
    if (_carouselController.hasClients && _heroBanners.length > 1) {
      final next = (_currentCarouselIndex + 1) % _heroBanners.length;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startAutoRotate() {
    _heroAutoRotateTimer?.cancel();
    _promoAutoRotateTimer?.cancel();
    if (_heroBanners.length > 1) {
      _heroAutoRotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _goToNextHeroSlide();
      });
    }
    if (_promoBanners.length > 1) {
      _promoAutoRotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_promoBannerController.hasClients) {
          final next = (_currentPromoBannerIndex + 1) % _promoBanners.length;
          _promoBannerController.animateToPage(
            next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _handleRefresh() async {
    debugPrint('Pull to refresh triggered...');
    final isCustomerPreview = ref.read(guestModeProvider);
    await Future.wait([
      _fetchBrands(),
      _fetchProducts(),
      _fetchCategories(),
      _fetchPromoBanners(),
      _fetchOffers(),
      if (!isCustomerPreview) _fetchNotificationCount(),
      _fetchNegotiations(),
      _fetchHomeOrders(),
      _fetchScheduledChanges(),
      if (!isCustomerPreview)
        ref.read(authProvider.notifier).fetchCurrentUser(),
    ]);
  }

  ProductSearchCriteria get _activeSearchCriteria => ProductSearchCriteria(
    query: _searchQuery,
    categoryId: _selectedFilterCategoryId,
    brandId: _selectedFilterBrandId,
  );

  bool get _hasActiveProductSearch => _activeSearchCriteria.isActive;

  void _invalidateSearchRequests() {
    _searchRequestGeneration++;
    _searchCancelToken?.cancel('Search criteria changed');
    _searchCancelToken = null;
  }

  Map<String, dynamic> _mapSearchProduct(dynamic raw) {
    final item = Map<String, dynamic>.from(raw as Map);
    return <String, dynamic>{
      'id': item['id']?.toString() ?? item['_id']?.toString() ?? '',
      'name': item['name']?.toString() ?? '',
      'nameHindi': item['nameHindi']?.toString() ?? '',
      'brand': item['brand']?.toString() ?? '',
      'category': item['category']?.toString() ?? '',
      'price': catalogPriceForAudience(
        item,
        isCustomerPreview: ref.read(guestModeProvider),
      ),
      'originalPrice': item['mrp'] ?? 0,
      'image': ApiConfig.normalizeMediaUrl(
        item['primaryImage']?.toString() ?? '',
      ),
      'blurHash':
          item['primaryBlurHash']?.toString() ??
          item['blurHash']?.toString() ??
          '',
      'inStock': item['inStock'] == true,
      'shortDescription': item['shortDescription']?.toString() ?? '',
      'rating': item['rating'],
      'purchaseCountMin': item['purchaseCountMin'] ?? 0,
      'purchaseCountMax': item['purchaseCountMax'] ?? 0,
      'minWholesaleQuantity': item['minWholesaleQuantity'],
      'pendingPriceChange': item['pendingPriceChange'],
    };
  }

  Future<void> _searchProducts(
    String query, {
    int page = 1,
    bool append = false,
  }) async {
    final criteria = ProductSearchCriteria(
      query: query,
      categoryId: _selectedFilterCategoryId,
      brandId: _selectedFilterBrandId,
    );
    if (!criteria.isActive) {
      _invalidateSearchRequests();
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _isLoadingMoreSearch = false;
        _searchHasNext = false;
        _searchPage = 0;
        _searchError = null;
        _searchQuery = '';
      });
      return;
    }

    if (append && (_isLoadingMoreSearch || !_searchHasNext)) return;

    late final int generation;
    if (append) {
      generation = _searchRequestGeneration;
      setState(() => _isLoadingMoreSearch = true);
    } else {
      generation = ++_searchRequestGeneration;
      _searchCancelToken?.cancel('New search started');
      setState(() {
        _isSearching = true;
        _isLoadingMoreSearch = false;
        _searchResults = [];
        _searchQuery = query;
        _searchError = null;
      });
    }

    final cancelToken = CancelToken();
    _searchCancelToken = cancelToken;
    try {
      final response = await _dio.get(
        '/products/search',
        queryParameters: criteria.toQueryParameters(page: page, limit: 20),
        cancelToken: cancelToken,
      );
      if (!mounted || generation != _searchRequestGeneration) return;
      final resultPage = ProductSearchPage.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      final mapped = resultPage.items.map(_mapSearchProduct).toList();
      setState(() {
        _searchResults = append
            ? mergeSearchItems(_searchResults, mapped)
            : mapped;
        _searchPage = resultPage.page;
        _searchHasNext = resultPage.hasNext;
        _isSearching = false;
        _isLoadingMoreSearch = false;
        _searchError = null;
      });
      // Remember searches that found something once the user pauses typing.
      if (!append && mapped.isNotEmpty && query.trim().length >= 3) {
        _rememberSearch(query);
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) ||
          !mounted ||
          generation != _searchRequestGeneration) {
        return;
      }
      setState(() {
        _isSearching = false;
        _isLoadingMoreSearch = false;
        _searchError = context.l10n.homeSearchLoadFailed;
      });
      if (append) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeSearchLoadMoreFailed)),
        );
      }
    } catch (error) {
      debugPrint('Search error: $error');
      if (!mounted || generation != _searchRequestGeneration) return;
      setState(() {
        _isSearching = false;
        _isLoadingMoreSearch = false;
        _searchError = context.l10n.homeSearchLoadFailed;
      });
      if (append) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeSearchLoadMoreFailed)),
        );
      }
    }
  }

  void _loadMoreSearchResults() {
    if (!_hasActiveProductSearch || !_searchHasNext || _isLoadingMoreSearch) {
      return;
    }
    _searchProducts(_searchQuery, page: _searchPage + 1, append: true);
  }

  void _selectSearchScope(
    _SearchScope selectedScope, {
    bool openSearch = false,
  }) {
    _searchDebounce?.cancel();
    _invalidateSearchRequests();
    setState(() {
      _searchScope = selectedScope;
      _selectedFilterCategoryId = null;
      _selectedFilterBrandId = null;
      _searchResults = [];
      _isSearching = false;
      _isLoadingMoreSearch = false;
      _searchHasNext = false;
      _searchError = null;
      if (openSearch) _selectedNavIndex = 1;
    });
    if (selectedScope == _SearchScope.product) {
      _searchProducts(_searchController.text);
    }
    if (openSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  Widget _buildSearchScopeMenu({
    required Widget child,
    bool openSearch = false,
  }) {
    final l10n = context.l10n;
    final options = <(_SearchScope, String, IconData)>[
      (
        _SearchScope.product,
        l10n.homeSearchScopeProduct,
        Icons.inventory_2_outlined,
      ),
      (
        _SearchScope.brand,
        l10n.homeSearchScopeBrand,
        Icons.storefront_outlined,
      ),
      (
        _SearchScope.category,
        l10n.homeSearchScopeCategory,
        Icons.category_outlined,
      ),
    ];

    return PopupMenuButton<_SearchScope>(
      tooltip: l10n.homeSearchFilterTooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(-132, 6),
      constraints: const BoxConstraints.tightFor(width: 184),
      color: surfaceWhite,
      elevation: 12,
      shadowColor: const Color(0xFF0F172A).withOpacity(0.16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (scope) => _selectSearchScope(scope, openSearch: openSearch),
      itemBuilder: (context) => options.map((option) {
        final selected = option.$1 == _searchScope;
        return PopupMenuItem<_SearchScope>(
          value: option.$1,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                option.$3,
                size: 19,
                color: selected ? primaryBlue : textSecondary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  option.$2,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? primaryBlue : textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: primaryBlue, size: 18),
            ],
          ),
        );
      }).toList(),
      child: child,
    );
  }

  Future<void> _fetchNotificationCount() async {
    if (ref.read(guestModeProvider)) return;
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/notifications/my',
        queryParameters: {'limit': 1},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _unreadCount = response.data['unreadCount'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  Future<void> _fetchNotifications([
    void Function(void Function())? dialogSetter,
  ]) async {
    if (ref.read(guestModeProvider)) return;
    final update = dialogSetter ?? setState;
    update(() => _isLoadingNotifications = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/notifications/my',
        queryParameters: {'limit': 10},
      );
      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['data'] ?? [];
        final mapped = items
            .map<Map<String, dynamic>>(
              (item) => <String, dynamic>{
                'id': item['_id']?.toString() ?? '',
                'title': item['title']?.toString() ?? '',
                'body': item['body']?.toString() ?? '',
                'type': item['type']?.toString() ?? 'general',
                'isRead': item['isRead'] == true,
                'createdAt': item['createdAt']?.toString() ?? '',
                'data': item['data'] ?? {},
              },
            )
            .toList();
        _notifications = mapped;
        _unreadCount = response.data['unreadCount'] ?? 0;
        _isLoadingNotifications = false;
        update(() {});
        // Also update parent so badge refreshes
        if (dialogSetter != null && mounted) setState(() {});
      } else {
        _isLoadingNotifications = false;
        update(() {});
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      _isLoadingNotifications = false;
      update(() {});
    }
  }

  Future<void> _markNotificationsRead([
    void Function(void Function())? dialogSetter,
  ]) async {
    if (ref.read(guestModeProvider)) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/notifications/mark-read', data: {});
      _unreadCount = 0;
      for (var n in _notifications) {
        n['isRead'] = true;
      }
      if (dialogSetter != null) dialogSetter(() {});
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error marking notifications read: $e');
    }
  }

  void _showNotificationPopup() {
    if (ref.read(guestModeProvider)) {
      _showGuestModePopup(context.l10n.homePreviewNotificationsHidden);
      return;
    }
    _isLoadingNotifications = true;
    _dialogSetter = null;
    final l10n = context.l10n;
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Trigger fetch only once per dialog open, deferred to avoid setState-during-build
          if (_dialogSetter == null) {
            _dialogSetter = setDialogState;
            final now = DateTime.now();
            final shouldFetch =
                _lastNotificationPopupFetchAt == null ||
                now.difference(_lastNotificationPopupFetchAt!) >
                    const Duration(seconds: 8);
            if (shouldFetch) {
              _lastNotificationPopupFetchAt = now;
              Future.microtask(() => _fetchNotifications(setDialogState));
            } else {
              _isLoadingNotifications = false;
            }
          }
          return GestureDetector(
            onTap: () => Navigator.pop(ctx),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {}, // absorb taps on the popup itself
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.88,
                        constraints: const BoxConstraints(maxHeight: 420),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.06),
                              blurRadius: 40,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        l10n.homeNotificationsTitle,
                                        style: AppFonts.jakarta(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                      ),
                                      if (_unreadCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryBlue,
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                          child: Text(
                                            '$_unreadCount',
                                            style: AppFonts.jakarta(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (_unreadCount > 0)
                                        GestureDetector(
                                          onTap: () => _markNotificationsRead(
                                            setDialogState,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              l10n.homeNotificationsMarkAllRead,
                                              style: AppFonts.jakarta(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: borderLight),
                            // Content
                            _isLoadingNotifications
                                ? const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: primaryBlue,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _notifications.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: primaryBlue.withOpacity(
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.notifications_none_rounded,
                                            size: 28,
                                            color: primaryBlue.withOpacity(0.5),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          l10n.homeNotificationsEmptyTitle,
                                          style: AppFonts.jakarta(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.homeNotificationsEmptySubtitle,
                                          style: AppFonts.jakarta(
                                            fontSize: 13,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Flexible(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      itemCount: _notifications.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            color: borderLight,
                                            indent: 60,
                                          ),
                                      itemBuilder: (_, i) {
                                        final notification = _notifications[i];
                                        final rawData = notification['data'];
                                        final data = rawData is Map
                                            ? {
                                                ...rawData.map(
                                                  (key, value) => MapEntry(
                                                    key.toString(),
                                                    value,
                                                  ),
                                                ),
                                                'type':
                                                    notification['type']
                                                        ?.toString() ??
                                                    'general',
                                              }
                                            : {
                                                'type':
                                                    notification['type']
                                                        ?.toString() ??
                                                    'general',
                                              };

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.of(ctx).pop();
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (!mounted) return;
                                                  NotificationNavigationService
                                                      .instance
                                                      .openFromContext(
                                                        context,
                                                        data,
                                                        isAuthenticated: ref
                                                            .read(authProvider)
                                                            .isAuthenticated,
                                                      );
                                                });
                                          },
                                          child: _buildNotificationItem(
                                            notification,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                            // Footer
                            if (_notifications.isNotEmpty) ...[
                              const Divider(height: 1, color: borderLight),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  context.push('/notifications');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    l10n.homeNotificationsViewAll,
                                    style: AppFonts.jakarta(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => _dialogSetter = null);
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final type = notification['type']?.toString() ?? 'general';
    final createdAt = notification['createdAt']?.toString() ?? '';
    final data = notification['data'] is Map
        ? {
            ...(notification['data'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
            'type': type,
          }
        : {'type': type};

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (type) {
      case 'payment_verified':
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF16A34A);
        iconBg = const Color(0xFFF0FDF4);
        break;
      case 'payment_rejected':
        icon = Icons.cancel_rounded;
        iconColor = const Color(0xFFEF4444);
        iconBg = const Color(0xFFFEF2F2);
        break;
      case 'order_update':
        icon = Icons.local_shipping_rounded;
        iconColor = const Color(0xFF0F766E);
        iconBg = const Color(0xFFF0FDFA);
        break;
      case 'negotiation_update':
        icon = Icons.handshake_rounded;
        iconColor = const Color(0xFFF59E0B);
        iconBg = const Color(0xFFFFFBEB);
        break;
      case 'price_change_campaign_started':
      case 'price_change_campaign_12h':
      case 'price_change_campaign_6h':
      case 'price_change_campaign_20m':
      case 'price_change_campaign_3h':
      case 'price_change_campaign_1h':
      case 'price_change_campaign_5m':
      case 'price_change_campaign_applied':
        icon = Icons.schedule_rounded;
        iconColor = const Color(0xFFEA580C);
        iconBg = const Color(0xFFFFF7ED);
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppColors.primary;
        iconBg = const Color(0xFFE6F7F5);
    }

    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeAgo = context.l10n.homeTimeJustNow;
        } else if (diff.inMinutes < 60) {
          timeAgo = context.l10n.homeTimeMinutesAgo('${diff.inMinutes}');
        } else if (diff.inHours < 24) {
          timeAgo = context.l10n.homeTimeHoursAgo('${diff.inHours}');
        } else {
          timeAgo = context.l10n.homeTimeDaysAgo('${diff.inDays}');
        }
      } catch (_) {}
    }

    return Container(
      color: isRead ? Colors.transparent : primaryBlue.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notification['body'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                NotificationCountdownLabel(
                  data: data,
                  color: const Color(0xFFEA580C),
                  fontSize: 11,
                ),
                if (timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: AppFonts.jakarta(fontSize: 11, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _heroAutoRotateTimer?.cancel();
    _promoAutoRotateTimer?.cancel();
    _guestAuthPromptTimer?.cancel();
    _carouselController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _searchRequestGeneration++;
    _searchCancelToken?.cancel('Search screen disposed');
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addr1Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _couponCtrl.dispose();
    _promoBannerController.dispose();
    super.dispose();
  }

  bool get _isWholesaler {
    return ref.read(effectiveIsWholesalerProvider);
  }

  /// Product name in the current language (Hindi name when available).
  String _getDisplayName(Map<String, dynamic> product) =>
      localizedName(context, product);

  /// Offer rule line, built at display time so it follows the language.
  String _offerRuleText(Map<String, dynamic> offer) {
    final l10n = context.l10n;
    final type = offer['type']?.toString() ?? '';
    final value = offer['value'];
    if (!offer.containsKey('type')) return l10n.homeOfferRuleFallback;
    return type == 'percentage'
        ? l10n.homeOfferRulePercent('$value')
        : l10n.homeOfferRuleFlat('$value');
  }

  List<Widget> get _bodyPages {
    if (_isWholesaler) {
      // Planned wholesaler nav: Home, Search, Categories, Deal Desk, Profile.
      // Cart removed for wholesalers (orders via Send Requirement + Deal Desk).
      // Search tab kept for now; full removal + Orders/Dealer Club tabs in Phase 5.
      return [
        _buildHomeContent(),
        _buildSearchContent(),
        CategoriesScreen(
          onSearchTap: () => setState(() => _selectedNavIndex = 1),
          controller: _categoriesController,
          navigationRequest: _categoryNavigationRequest,
          initialCategoryId: _requestedCategoryId,
          initialCategoryName: _requestedCategoryName,
          brandId: _requestedCategoryBrandId,
        ),
        _buildNegotiationsContent(),
        _buildProfileContent(),
      ];
    }
    return [
      _buildHomeContent(),
      _buildSearchContent(),
      CategoriesScreen(
        onSearchTap: () => setState(() => _selectedNavIndex = 1),
        controller: _categoriesController,
        navigationRequest: _categoryNavigationRequest,
        initialCategoryId: _requestedCategoryId,
        initialCategoryName: _requestedCategoryName,
        brandId: _requestedCategoryBrandId,
      ),
      _buildCartContent(),
      _buildProfileContent(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth to rebuild when role changes
    ref.watch(authProvider);
    ref.watch(effectiveIsWholesalerProvider);
    final isCustomerPreview = ref.watch(guestModeProvider);

    // Listen for role changes (e.g., from buyer to wholesaler after approval)
    // to refresh the offers and other role-dependent data without manual refresh.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final oldRole = previous?.user?.role;
      final newRole = next.user?.role;

      if (oldRole != null && oldRole != newRole) {
        debugPrint(
          '[Auth] Role changed from $oldRole to $newRole, auto-refreshing data...',
        );
        // Use Future.microtask to avoid calling setState during build cycle
        Future.microtask(() => _handleRefresh());
      }
    });

    final pages = _bodyPages;
    // Clamp nav index to valid range
    if (_selectedNavIndex >= pages.length) {
      _selectedNavIndex = 0;
    }
    return PopScope(
      canPop: isCustomerPreview,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_selectedNavIndex == 2 && _categoriesController.handleBack()) {
          return;
        }

        // If not on Home tab, go back to Home tab
        if (_selectedNavIndex > 0) {
          setState(() {
            _selectedNavIndex = 0;
          });
          return;
        }

        // If already on Home tab, allow the app to exit
        SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: backgroundWhite,
          body: SafeArea(
            child: IndexedStack(index: _selectedNavIndex, children: pages),
          ),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: primaryBlue,
            backgroundColor: Colors.white,
            edgeOffset: 20,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHomeSearchBar(),
                  const SizedBox(height: 8),
                  _buildCarousel(),
                  const SizedBox(height: 12),
                  if (_isWholesaler) ...[
                    _buildScheduledChanges(),
                    const SizedBox(height: 12),
                  ],
                  if (!kHideOfferCouponUi && !_isWholesaler)
                    _buildOfferSection(),
                  if (!_isWholesaler) const SizedBox(height: 8),
                  _buildBrandsSection(),
                  const SizedBox(height: 8),
                  _buildCategorySection(),
                  const SizedBox(height: 8),
                  if (_isWholesaler) ...[
                    _buildContinueDeals(),
                    const SizedBox(height: 8),
                    _buildTrackHomeOrders(),
                    _buildRepeatHomeOrders(),
                    const SizedBox(height: 8),
                  ],
                  _buildProductsSection(
                    _isWholesaler
                        ? context.l10n.homePopularProductsDealer
                        : context.l10n.homePopularProductsCustomer,
                    true,
                  ),
                  const SizedBox(height: 8),
                  _buildProductsSection(
                    _isWholesaler
                        ? context.l10n.homeHotDealsDealer
                        : context.l10n.homeHotDealsCustomer,
                    false,
                  ),
                  const SizedBox(height: 8),
                  _buildTrustStrip(),
                  const SizedBox(height: 32),
                  if (_promoBanners.isNotEmpty && !_isWholesaler) ...[
                    _buildPromoBannerCarousel(),
                    const SizedBox(height: 32),
                  ],
                  if (!_isWholesaler) ...[
                    _buildWhyBuySection(),
                    const SizedBox(height: 32),
                    _buildReviewSection(),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustStrip() {
    final l10n = context.l10n;
    return _TrustBadgeMarquee(
      isActive: _selectedNavIndex == 0,
      items: [
        {
          'icon': Icons.local_shipping_rounded,
          'text': l10n.homeTrustPanIndiaDelivery,
        },
        {
          'icon': Icons.verified_user_rounded,
          'text': l10n.homeTrustCertifiedProducts,
        },
        {
          'icon': Icons.support_agent_rounded,
          'text': l10n.homeTrustExpertSupport,
        },
        {'icon': Icons.local_offer_rounded, 'text': l10n.homeTrustBulkSale},
      ],
    );
  }

  Widget _buildHomeSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _selectedNavIndex = 1);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _searchFocusNode.requestFocus();
                  });
                },
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.homeSearchHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
            _buildSearchScopeMenu(
              openSearch: true,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _searchScope == _SearchScope.product
                      ? textSecondary
                      : primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.homeExclusiveOffers,
                style: AppFonts.jakarta(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              Text(
                context.l10n.homeViewDeals,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Show shimmer while loading
        if (_isLoadingOffers)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Row(
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 160,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          )
        // Show empty state if no offers
        else if (_offers.isEmpty)
          const SizedBox.shrink()
        // Show offers
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _offers.map((offer) {
                final index = _offers.indexOf(offer);
                final colors = [
                  const Color(0xFF3B82F6),
                  const Color(0xFF10B981),
                  const Color(0xFFF59E0B),
                  const Color(0xFF14B8A6),
                ];
                final icons = [
                  Icons.water_drop_rounded,
                  Icons.grass_rounded,
                  Icons.settings_rounded,
                  Icons.tag_rounded,
                ];

                return _buildModernOfferCard(
                  offer['title'] ?? '',
                  offer['discount'] ?? '',
                  colors[index % colors.length],
                  icons[index % icons.length],
                  couponCode: offer['code']?.toString(),
                  rule: _offerRuleText(offer),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildModernOfferCard(
    String title,
    String discount,
    Color color,
    IconData icon, {
    String? couponCode,
    String? rule,
  }) {
    final l10n = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;
    final double cardW = isTablet ? 250 : 218;
    final double cardH = isTablet ? 132 : 122;
    final double barcodeW = isTablet ? 44 : 38;
    const double seamW = 7;
    final code = (couponCode?.trim().isNotEmpty ?? false)
        ? couponCode!.trim()
        : title.replaceAll(' ', '').toUpperCase();
    final discountText = discount.trim().isNotEmpty ? discount.trim() : title;
    final showOff = !discountText.toLowerCase().contains('free');

    // Derive a slightly lighter shade for gradient
    final Color colorLight = Color.lerp(Colors.white, color, 0.18) ?? color;
    final Color colorDark = Color.lerp(Colors.black, color, 0.78) ?? color;

    return Container(
      width: cardW,
      height: cardH,
      margin: const EdgeInsets.only(right: 22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Drop shadow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: barcodeW + seamW,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: isTablet ? 22 : 19,
                      height: isTablet ? 96 : 86,
                      child: const CustomPaint(painter: _BarcodePainter()),
                    ),
                  ),
                  const Positioned(
                    right: 1,
                    top: 12,
                    bottom: 12,
                    child: SizedBox(
                      width: 5,
                      child: CustomPaint(painter: _VerticalDashedLinePainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: barcodeW + seamW,
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 18 : 15,
                  isTablet ? 13 : 11,
                  isTablet ? 18 : 14,
                  isTablet ? 12 : 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorLight, color, colorDark],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -28,
                      right: -30,
                      child: Container(
                        width: isTablet ? 78 : 68,
                        height: isTablet ? 78 : 68,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.32),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: isTablet ? 21 : 18,
                      right: isTablet ? 10 : 7,
                      child: Opacity(
                        opacity: 0.09,
                        child: Icon(
                          icon,
                          size: isTablet ? 52 : 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: isTablet ? 9.2 : 8.4,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  discountText.toUpperCase(),
                                  style: AppFonts.jakarta(
                                    color: Colors.white,
                                    fontSize: showOff
                                        ? (isTablet ? 37 : 32)
                                        : (isTablet ? 32 : 28),
                                    fontWeight: FontWeight.w900,
                                    height: 0.9,
                                    letterSpacing: -1.3,
                                  ),
                                ),
                              ),
                            ),
                            if (showOff) ...[
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  l10n.homeOfferOff,
                                  style: AppFonts.jakarta(
                                    color: Colors.white,
                                    fontSize: isTablet ? 15 : 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          rule ?? l10n.homeOfferApplyDuringCheckout,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: isTablet ? 9 : 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.homeOfferCode(code),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.jakarta(
                                  color: Colors.white,
                                  fontSize: isTablet ? 9.8 : 8.7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              color: Colors.white.withOpacity(0.92),
                              size: isTablet ? 12 : 10,
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _redeemOffer(
                            code: code,
                            title: title,
                            rule: rule ?? l10n.homeOfferRuleFallback,
                          ),
                          child: Container(
                            height: isTablet ? 30 : 27,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.homeApplyCoupon,
                              style: AppFonts.jakarta(
                                color: colorDark,
                                fontSize: isTablet ? 9.5 : 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: barcodeW + seamW - 10,
            top: cardH / 2 - 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: backgroundWhite,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: cardH / 2 - 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: backgroundWhite,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnershipStrip() {
    // Show the first few brands returned by the API.
    final displayBrands = _brands
        .map((brand) => brand['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .take(5)
        .toList();
    final brandByName = {
      for (final brand in _brands)
        (brand['name']?.toString().trim().toLowerCase() ?? ''): brand,
    };
    final items = displayBrands.map((name) {
      final brand = brandByName[name.toLowerCase()];
      return <String, dynamic>{
        'label': name,
        'imageUrl': brand?['logo']?.toString() ?? '',
      };
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                context.l10n.homePartnershipsTitle,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: _PartnershipMarquee(
                items: items,
                isActive: _selectedNavIndex == 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _redeemOffer({
    required String code,
    required String title,
    required String rule,
  }) async {
    if (ref.read(guestModeProvider)) {
      await _showGuestModePopup(context.l10n.homePreviewOffersReadOnly);
      return;
    }
    final user = ref.read(authProvider).user;
    final userKey = user?.id.isNotEmpty == true
        ? user!.id
        : (user?.phone ?? user?.email ?? 'guest');
    await RedeemedCouponService.redeemCoupon(
      userKey: userKey,
      code: code,
      title: title,
      rule: rule,
    );
    if (!mounted) return;

    // Copy code to clipboard
    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.homeCouponCopied(code),
                style: AppFonts.jakarta(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _fmtCatName(String name) {
    if (name.isEmpty) return '';
    // Replace hyphens with spaces and capitalize words
    final parts = name.replaceAll('-', ' ').split(' ');
    return parts
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _getDisplayCategoryName(Map<String, dynamic> category) {
    final displayName = category['displayName']?.toString() ?? '';
    final nameEnglish = category['name']?.toString() ?? '';
    final nameHindi = category['nameHindi']?.toString().trim() ?? '';

    if (context.isHindi && nameHindi.isNotEmpty) {
      return latinDigits(nameHindi);
    }
    if (displayName.isNotEmpty) return displayName;
    return _fmtCatName(nameEnglish);
  }

  String _getDisplayCategoryNameByKey(String categoryName) {
    final category = _categoryData.firstWhere(
      (item) =>
          (item['queryName']?.toString() ?? item['name']?.toString() ?? '') ==
          categoryName,
      orElse: () => {'name': categoryName},
    );
    return _getDisplayCategoryName(category);
  }

  // Skeleton loader for categories
  Widget _buildCategorySkeleton() {
    return SizedBox(
      height: 145,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 8),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 12,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 12,
                  width: 60,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;
    final categoryCardWidth = isTablet ? 132.0 : 108.0;
    final categoryListHeight = isTablet ? 188.0 : 164.0;
    final categoryCardGap = isTablet ? 14.0 : 12.0;

    // Use dynamic data if available, otherwise show empty state
    final categories = _categoryData.isNotEmpty ? _categoryData : [];

    // Show empty state if no categories
    if (categories.isEmpty && !_isLoadingCategories) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryBlue.withOpacity(0.25),
            primaryBlue.withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.homeCategoriesTitle,
                      style: AppFonts.jakarta(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _categoryNavigationRequest++;
                    _requestedCategoryId = null;
                    _requestedCategoryName = null;
                    _requestedCategoryBrandId = null;
                    _selectedNavIndex = 2;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderLight),
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.commonSeeAll,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Show skeleton while loading
          if (_isLoadingCategories)
            _buildCategorySkeleton()
          else
            SizedBox(
              height: categoryListHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: categories.map((cat) {
                    return GestureDetector(
                      onTap: () {
                        final name = cat['name']?.toString() ?? '';
                        setState(() {
                          _categoryNavigationRequest++;
                          _requestedCategoryId = cat['id']?.toString() ?? '';
                          _requestedCategoryName = name;
                          _requestedCategoryBrandId =
                              cat['brandId']?.toString() ?? '';
                          _selectedNavIndex = 2;
                        });
                      },
                      child: Container(
                        width: categoryCardWidth,
                        margin: EdgeInsets.only(right: categoryCardGap),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child:
                                    (cat['image']?.toString() ?? '').isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: AppImage(
                                          imageUrl: cat['image']!.toString(),
                                          blurHash: cat['blurHash']?.toString(),
                                          category:
                                              cat['name']?.toString() ?? '',
                                          name: cat['name']?.toString() ?? '',
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(
                                          Icons.category_outlined,
                                          color: textMuted,
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey[700],
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(20),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Text(
                                _getDisplayCategoryName(cat),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.jakarta(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleSearchTextChanged(String value) {
    _searchDebounce?.cancel();
    _invalidateSearchRequests();
    setState(() {
      _searchQuery = value;
      _searchError = null;
      _isSearching = false;
      _isLoadingMoreSearch = false;
      _searchHasNext = false;
      if (_searchScope != _SearchScope.product || value.trim().isEmpty) {
        _searchResults = [];
      }
    });

    if (_searchScope != _SearchScope.product) return;
    if (value.trim().isEmpty) {
      if (_selectedFilterCategoryId != null || _selectedFilterBrandId != null) {
        _searchProducts('');
      }
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchProducts(value),
    );
  }

  Future<void> _loadRecentSearches() async {
    final saved = await RecentSearchStore.load();
    if (!mounted || saved.isEmpty) return;
    setState(() => _recentSearches = List<String>.from(saved));
  }

  void _rememberSearch(String query) {
    final next = addRecentSearch(_recentSearches, query);
    setState(() => _recentSearches = next);
    RecentSearchStore.save(next);
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;

    _searchDebounce?.cancel();
    _rememberSearch(query);
    setState(() => _searchQuery = query);

    if (_searchScope == _SearchScope.product) {
      _searchProducts(query);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _invalidateSearchRequests();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
      _isLoadingMoreSearch = false;
      _searchHasNext = false;
      _searchError = null;
    });
    if (_searchScope == _SearchScope.product &&
        (_selectedFilterCategoryId != null || _selectedFilterBrandId != null)) {
      _searchProducts('');
    }
  }

  List<Map<String, dynamic>> get _filteredSearchBrands {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _brands;
    return _brands.where((brand) {
      final name = brand['name']?.toString().toLowerCase() ?? '';
      final slug = brand['slug']?.toString().toLowerCase() ?? '';
      return name.contains(query) || slug.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSearchCategories {
    final query = normalizeSearchQuery(_searchQuery).toLowerCase();
    if (query.isEmpty) return _searchCategoryData;
    return _searchCategoryData.where((category) {
      // Match English and Hindi names whatever the app language is.
      final searchableText = latinDigits([
        category['name'],
        category['nameHindi'],
        category['queryName'],
        category['brandName'],
      ].whereType<Object>().join(' ')).toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  Widget _buildScopedEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: textMuted),
          const SizedBox(height: 14),
          Text(
            message,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.homeTryDifferentSearch,
            style: AppFonts.jakarta(fontSize: 13, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSearchResults() {
    if (_isLoadingBrands) {
      return const Center(child: CircularProgressIndicator(color: primaryBlue));
    }
    final brands = _filteredSearchBrands;
    if (brands.isEmpty) {
      return _buildScopedEmptyState(context.l10n.homeNoBrandsFound);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: brands.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final brand = brands[index];
        final id = brand['id']?.toString() ?? '';
        final name = brand['name']?.toString() ?? '';
        final logo = ApiConfig.normalizeMediaUrl(
          brand['logo']?.toString() ?? '',
        );
        return Material(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: id.isEmpty
                ? null
                : () => context.push(
                    '/brand/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(name)}',
                  ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: borderLight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: logo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: logo,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.storefront_outlined,
                                color: primaryBlue,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.storefront_outlined,
                            color: primaryBlue,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: AppFonts.jakarta(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySearchResults() {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator(color: primaryBlue));
    }
    final categories = _filteredSearchCategories;
    if (categories.isEmpty) {
      return _buildScopedEmptyState(context.l10n.homeNoCategoriesFound);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = categories[index];
        final name = category['name']?.toString() ?? '';
        final displayName = _getDisplayCategoryName(category);
        final brandName = category['brandName']?.toString() ?? '';
        return Material(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => setState(() {
              _categoryNavigationRequest++;
              _requestedCategoryId = category['id']?.toString() ?? '';
              _requestedCategoryName = name;
              _requestedCategoryBrandId = category['brandId']?.toString() ?? '';
              _selectedNavIndex = 2;
              _searchFocusNode.unfocus();
            }),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: borderLight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppFonts.jakarta(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        if (brandName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            brandName,
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchContent() {
    final l10n = context.l10n;
    final catalogCategories = _categoryData
        .where(_categoryHasProducts)
        .take(8)
        .toList();
    final suggestionProducts = _featuredProducts.isNotEmpty
        ? _featuredProducts
        : _products;
    final suggestionTitle = _featuredProducts.isNotEmpty
        ? l10n.homeFeaturedProducts
        : l10n.homeCatalogProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.homeExploreTitle,
                style: AppFonts.jakarta(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch02,
                  color: primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _handleSearchTextChanged,
                    onSubmitted: _submitSearch,
                    textInputAction: TextInputAction.search,
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.homeSearchHint,
                      hintStyle: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: _clearSearch,
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: borderLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: textSecondary,
                      ),
                    ),
                  ),
                Container(width: 1, height: 26, color: borderLight),
                _buildSearchScopeMenu(
                  child: Container(
                    width: 52,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _searchScope == _SearchScope.product
                          ? Colors.transparent
                          : primaryBlue.withOpacity(0.08),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(100),
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedFilterHorizontal,
                          color: _searchScope == _SearchScope.product
                              ? textMuted
                              : primaryBlue,
                          size: 22,
                        ),
                        if (_searchScope != _SearchScope.product)
                          const Positioned(
                            top: -3,
                            right: -4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 8, height: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: _searchScope == _SearchScope.brand
              ? _buildBrandSearchResults()
              : _searchScope == _SearchScope.category
              ? _buildCategorySearchResults()
              : _isSearching && _searchResults.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                )
              : _hasActiveProductSearch
              ? _searchError != null && _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.homeSearchLoadFailed,
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () =>
                                  _searchProducts(_searchController.text),
                              child: Text(l10n.commonRetry),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.homeSearchNoResults,
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.trim().isEmpty
                                  ? l10n.homeSearchTryChangingFilters
                                  : l10n.homeTryDifferentSearch,
                              style: AppFonts.jakarta(
                                fontSize: 13,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.extentAfter < 320) {
                            _loadMoreSearchResults();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount:
                              _searchResults.length +
                              (_isLoadingMoreSearch ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _searchResults.length) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: primaryBlue,
                                  ),
                                ),
                              );
                            }
                            return _buildSuggestionCard(_searchResults[index]);
                          },
                        ),
                      )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recent Searches
                      if (_recentSearches.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.homeRecentSearches,
                                    style: AppFonts.jakarta(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _recentSearches = []);
                                      RecentSearchStore.save(const []);
                                    },
                                    child: Text(
                                      l10n.homeClearAll,
                                      style: AppFonts.jakarta(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: primaryBlue,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(
                                _recentSearches.length,
                                (i) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: surfaceWhite,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.03,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.history_rounded,
                                          color: textMuted,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            _searchController.text =
                                                _recentSearches[i];
                                            _handleSearchTextChanged(
                                              _recentSearches[i],
                                            );
                                          },
                                          child: Text(
                                            _recentSearches[i],
                                            style: AppFonts.jakarta(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _recentSearches.removeAt(i),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: textMuted,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (catalogCategories.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  l10n.homeBrowseCategories,
                                  style: AppFonts.jakarta(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: catalogCategories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final category = catalogCategories[index];
                                    final label = _getDisplayCategoryName(
                                      category,
                                    );
                                    return GestureDetector(
                                      onTap: () {
                                        _searchDebounce?.cancel();
                                        _invalidateSearchRequests();
                                        _searchController.clear();
                                        setState(() {
                                          _searchScope = _SearchScope.product;
                                          _searchQuery = '';
                                          _selectedFilterCategoryId =
                                              category['id']?.toString();
                                          _selectedFilterBrandId =
                                              category['brandId']?.toString();
                                        });
                                        _searchProducts('');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: surfaceWhite,
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          border: Border.all(
                                            color: borderLight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            label,
                                            style: AppFonts.jakarta(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Live catalog suggestions
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  suggestionTitle,
                                  style: AppFonts.jakarta(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...suggestionProducts
                                .take(5)
                                .map(
                                  (product) => _buildSuggestionCard(product),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> product) {
    final heroTag = 'search-product-${product['id']}';
    final hasOriginalPrice =
        product['originalPrice'] != null &&
        product['originalPrice'] != product['price'] &&
        product['originalPrice'] > 0;

    return GestureDetector(
      onTap: () => context.push(
        '/product/${product['id']}',
        extra: {'heroTag': heroTag},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderLight.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: heroTag,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: (product['image']?.toString() ?? '').isNotEmpty
                      ? AppImage(
                          imageUrl: product['image'].toString(),
                          blurHash: product['blurHash']?.toString(),
                          category: product['category']?.toString() ?? '',
                          name: product['name']?.toString() ?? '',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        )
                      : ProductImagePlaceholder(
                          category: product['category']?.toString() ?? '',
                          name: product['name']?.toString() ?? '',
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getDisplayName(product),
                          style: AppFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product['rating'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFF15803D),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${product['rating']}',
                                style: AppFonts.jakarta(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 4),
                  // Live Purchase Counter (list view)
                  Builder(
                    builder: (context) {
                      final pMin =
                          (product['purchaseCountMin'] as num?)?.toInt() ?? 0;
                      final pMax =
                          (product['purchaseCountMax'] as num?)?.toInt() ?? 0;
                      if (pMin <= 0 && pMax <= 0) {
                        return const SizedBox.shrink();
                      }
                      final effectiveMax = pMax > pMin ? pMax : pMin;
                      final dayOfYear = DateTime.now()
                          .difference(DateTime(DateTime.now().year))
                          .inDays;
                      final productIdHash = product['id']
                          .toString()
                          .hashCode
                          .abs();
                      final seed = productIdHash + dayOfYear;
                      final range = effectiveMax - pMin;
                      final count = range > 0
                          ? pMin + (seed % (range + 1))
                          : pMin;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 11,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                context.l10n.homeSoldIn24Hrs('$count'),
                                style: AppFonts.jakarta(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFEF4444),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if ((product['brand'] ?? '').toString().isNotEmpty)
                    Text(
                      product['brand'],
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textMuted,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₹${_formatPrice(product['price'] ?? 0)}',
                            style: AppFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          if (hasOriginalPrice) ...[
                            const SizedBox(width: 6),
                            Text(
                              '₹${_formatPrice(product['originalPrice'])}',
                              style: AppFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFFEF4444),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          context.l10n.commonView,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
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

  Widget _buildCartContent() {
    if (ref.watch(guestModeProvider)) {
      return _buildCustomerPreviewCart();
    }
    final cart = ref.watch(cartProvider);
    final l10n = context.l10n;
    final hasActiveCoupon = _hasActiveAppliedCoupon(cart);
    final isCouponLocked =
        _appliedCouponCode != null &&
        _normalizedCouponInput == _appliedCouponCode;
    final couponDiscount = hasActiveCoupon ? _appliedCouponDiscount : 0.0;
    final payableTotal = math
        .max(cart.grandTotal - couponDiscount, 0)
        .toDouble();
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: backgroundWhite,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.homeMyCart,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      if (cart.itemCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            l10n.commonItemsCount(cart.itemCount),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      if (cart.items.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              ref.read(cartProvider.notifier).clearCart(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderLight),
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedDelete02,
                                color: textMuted,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (cart.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _openCartAddressBottomSheet(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _addr1Ctrl.text.trim().isEmpty
                                ? l10n.homeAddShippingDetails
                                : '${_nameCtrl.text.trim()}, ${_addr1Ctrl.text.trim()}, ${_cityCtrl.text.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _addr1Ctrl.text.trim().isEmpty
                              ? l10n.homeAdd
                              : l10n.commonEdit,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: cart.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedShoppingCart01,
                            color: primaryBlue.withOpacity(0.4),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.homeCartEmptyTitle,
                        style: AppFonts.jakarta(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.homeCartEmptySubtitle,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => setState(() => _selectedNavIndex = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            l10n.homeBrowseProducts,
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final minimumQuantity = _isWholesaler
                        ? item.minWholesaleQuantity
                        : 1;
                    final isAtMinimum = item.quantity <= minimumQuantity;
                    return Dismissible(
                      key: Key(item.cartItemKey),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) =>
                          _removeCartItemAndRefreshCoupon(item.productId),
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderLight.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  item.image != null && item.image!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.image!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 80,
                                        height: 80,
                                        color: const Color(0xFFF1F5F9),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 80,
                                        height: 80,
                                        color: const Color(0xFFF1F5F9),
                                        child: Center(
                                          child: HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedImage01,
                                            color: textMuted,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: const Color(0xFFF1F5F9),
                                      child: Center(
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedImage01,
                                          color: textMuted,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickLocalizedName(
                                      context,
                                      item.name,
                                      item.nameHindi,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.jakarta(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                  if ((item.brand?.trim().isNotEmpty ??
                                          false) ||
                                      (item.category?.trim().isNotEmpty ??
                                          false)) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 2,
                                      children: [
                                        if (item.brand?.trim().isNotEmpty ??
                                            false)
                                          Text(
                                            l10n.homeBrandValue(
                                              item.brand!.trim(),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.jakarta(
                                              fontSize: 11,
                                              color: textSecondary,
                                            ),
                                          ),
                                        if (item.category?.trim().isNotEmpty ??
                                            false)
                                          Text(
                                            l10n.homeCategoryValue(
                                              item.category!.trim(),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.jakarta(
                                              fontSize: 11,
                                              color: textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  if (_isWholesaler) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.homeMinWholesaleQtyValue(
                                        '${item.minWholesaleQuantity}',
                                      ),
                                      style: AppFonts.jakarta(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${_formatPrice(item.price)}',
                                        style: AppFonts.jakarta(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: primaryBlue,
                                        ),
                                      ),
                                      if (item.mrp != null &&
                                          item.mrp! > item.price) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '₹${_formatPrice(item.mrp!)}',
                                          style: AppFonts.jakarta(
                                            fontSize: 12,
                                            color: const Color(0xFFEF4444),
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Quantity Controls
                                  Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: isAtMinimum
                                              ? null
                                              : () =>
                                                    _updateCartQtyAndRefreshCoupon(
                                                      item.productId,
                                                      item.quantity - 1,
                                                    ),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: surfaceWhite,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: borderLight,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.remove,
                                              size: 16,
                                              color: isAtMinimum
                                                  ? textMuted
                                                  : textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 36,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.quantity}',
                                            style: AppFonts.jakarta(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              _updateCartQtyAndRefreshCoupon(
                                                item.productId,
                                                item.quantity < minimumQuantity
                                                    ? minimumQuantity
                                                    : item.quantity + 1,
                                              ),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: primaryBlue,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Price Summary & Checkout
        if (cart.items.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Order Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.commonSubtotal,
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '₹${_formatPrice(cart.subtotal)}',
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.homeDelivery,
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '₹${_formatPrice(cart.deliveryFee)}',
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (hasActiveCoupon) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.homeCouponWithCode(
                                  _appliedCouponCode ?? '',
                                ),
                                style: AppFonts.jakarta(
                                  fontSize: 14,
                                  color: const Color(0xFF16A34A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '-\u20B9${_formatPrice(couponDiscount)}',
                                style: AppFonts.jakarta(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(height: 1, color: borderLight),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hasActiveCoupon
                                  ? l10n.homePayableTotal
                                  : l10n.commonTotal,
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              '₹${_formatPrice(payableTotal)}',
                              style: AppFonts.jakarta(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!kHideOfferCouponUi) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _couponCtrl,
                            enabled: !isCouponLocked && !_isApplyingCoupon,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9_-]'),
                              ),
                            ],
                            onChanged: (_) {
                              if (_appliedCouponCode != null &&
                                  _normalizedCouponInput !=
                                      _appliedCouponCode) {
                                setState(() => _clearAppliedCouponPreview());
                              }
                            },
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.homeCouponFieldLabel,
                              hintText: l10n.homeCouponFieldHint,
                              labelStyle: AppFonts.jakarta(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                              hintStyle: AppFonts.jakarta(
                                fontSize: 13,
                                color: textMuted,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: primaryBlue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _isApplyingCoupon || isCouponLocked
                                ? null
                                : _applyCouponPreview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            child: _isApplyingCoupon
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isCouponLocked
                                        ? l10n.homeCouponAppliedButton
                                        : l10n.commonApply,
                                    style: AppFonts.jakarta(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (isCouponLocked) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _clearAppliedCouponPreview(clearInput: true),
                          ),
                          child: Text(
                            l10n.homeChangeCode,
                            style: AppFonts.jakarta(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  // Checkout Button
                  GestureDetector(
                    onTap: _isCheckingOut ? null : _proceedToCheckout,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isCheckingOut
                            ? primaryBlue.withOpacity(0.6)
                            : primaryBlue,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isCheckingOut) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            _isCheckingOut
                                ? l10n.homeCreatingOrder
                                : l10n.homeProceedToCheckout,
                            style: AppFonts.jakarta(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (!_isCheckingOut) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerPreviewCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedShoppingCart01,
                  color: primaryBlue,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.homePreviewCartTitle,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.homePreviewCartMessage,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 14,
                height: 1.5,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _negotiationTab = 0;
  bool _isNegotiationsLoading = false;
  bool _isFetchingNegotiations = false;
  List<Map<String, dynamic>> _negotiations = [];

  void _selectNavIndex(int index) {
    if (_selectedNavIndex != index) {
      setState(() => _selectedNavIndex = index);
    }

    if (_isWholesaler && index == 3) {
      _fetchNegotiations();
    }
  }

  Future<void> _fetchNegotiations() async {
    if (!_isWholesaler) return;
    if (_isFetchingNegotiations) return;

    _isFetchingNegotiations = true;
    if (mounted) {
      setState(() => _isNegotiationsLoading = true);
    }

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/negotiations');
      if (!mounted) return;

      final List items = response.data['success'] == true
          ? response.data['data'] ?? []
          : [];
      setState(() {
        _negotiations = items.cast<Map<String, dynamic>>();
        _isNegotiationsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isNegotiationsLoading = false);
      }
    } finally {
      _isFetchingNegotiations = false;
    }
  }

  // ---- Dealer home: recent orders for track + repeat ----
  Future<void> _fetchHomeOrders() async {
    if (!_isWholesaler) return;
    if (mounted) setState(() => _isLoadingHomeOrders = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/orders',
        queryParameters: {'page': 1, 'limit': 10},
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List items = response.data['data'] ?? [];
        setState(() {
          _homeOrders = items.cast<Map<String, dynamic>>();
          _isLoadingHomeOrders = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingHomeOrders = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHomeOrders = false);
    }
  }

  List<Map<String, dynamic>> get _activeHomeOrders => _homeOrders
      .where((o) => !['delivered', 'cancelled'].contains(o['status']))
      .take(2)
      .toList();

  List<Map<String, dynamic>> get _repeatableHomeOrders => _homeOrders
      .where((o) => o['status'] == 'delivered' && o['orderType'] == 'wholesale')
      .take(3)
      .toList();

  List<Map<String, dynamic>> get _openHomeDeals => _negotiations
      .where((n) => ['pending', 'countered'].contains(n['status']))
      .take(3)
      .toList();

  // ---- Dealer home: upcoming scheduled price changes ----
  // Primary: GET /products/scheduled-changes (needs backend deploy).
  // Fallback: derive from already-loaded home products so cards work
  // even when the endpoint is missing on the server.
  Future<void> _fetchScheduledChanges() async {
    if (!_isWholesaler) return;
    if (mounted) setState(() => _isLoadingScheduledChanges = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/products/scheduled-changes');
      if (!mounted) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List items = response.data['data'] ?? [];
        if (items.isNotEmpty) {
          setState(() {
            _scheduledChanges = items.cast<Map<String, dynamic>>();
            _isLoadingScheduledChanges = false;
          });
          return;
        }
      }
    } catch (_) {
      // Endpoint missing (backend not deployed) or offline: fall through.
    }
    _deriveScheduledFromProducts();
    if (mounted) setState(() => _isLoadingScheduledChanges = false);
  }

  void _deriveScheduledFromProducts() {
    final derived = <Map<String, dynamic>>[];
    for (final product in _products) {
      final pending = product['pendingPriceChange'];
      if (pending is! Map<String, dynamic>) continue;
      final effectiveAt = DateTime.tryParse(
        (pending['effectiveAt'] ?? '').toString(),
      );
      if (effectiveAt == null || !effectiveAt.isAfter(DateTime.now())) {
        continue;
      }
      derived.add({
        'id': (product['id'] ?? '').toString(),
        'name': (product['name'] ?? '').toString(),
        'nameHindi': (product['nameHindi'] ?? '').toString(),
        'image': (product['image'] ?? '').toString(),
        'currentPrice': pending['currentPrice'] ?? product['price'] ?? 0,
        'newPrice': pending['newPrice'] ?? 0,
        'effectiveAt': effectiveAt.toIso8601String(),
      });
    }
    derived.sort(
      (a, b) =>
          (a['effectiveAt'] as String).compareTo(b['effectiveAt'] as String),
    );
    _scheduledChanges = derived.take(10).toList();
  }

  // ---- Dealer home: repeat a delivered wholesale order as a requirement ----
  Future<void> _repeatRequirement(Map<String, dynamic> order) async {
    final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (items.isEmpty) return;
    final first = items.first;
    final productId = (first['productId'] ?? '').toString();
    if (productId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.homeRepeatProductUnavailable)),
      );
      return;
    }
    setState(() => _repeatingOrderId = (order['id'] ?? '').toString());
    try {
      final api = ref.read(apiClientProvider);
      final productRes = await api.get('/products/$productId');
      final productData = Map<String, dynamic>.from(
        productRes.data['data'] ?? {},
      );
      final wsPrice =
          productData['wholesalePrice'] ?? first['pricePerUnit'] ?? 0;
      final quantity = (first['quantity'] as num?)?.toInt() ?? 1;
      final createRes = await api.post(
        '/negotiations',
        data: {
          'productId': productId,
          'quantity': quantity,
          'pricePerUnit': wsPrice,
          'message': 'Repeat requirement',
        },
      );
      if (!mounted) return;
      if ((createRes.statusCode == 200 || createRes.statusCode == 201) &&
          createRes.data['success'] == true) {
        final negotiationId = (createRes.data['data']?['id'] ?? '').toString();
        if (negotiationId.isNotEmpty) {
          await context.push('/negotiation-detail/$negotiationId');
          _fetchNegotiations();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (createRes.data['message'] ?? context.l10n.homeRepeatFailed)
                  .toString(),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.homeRepeatFailed)));
    } finally {
      if (mounted) setState(() => _repeatingOrderId = null);
    }
  }

  List<Map<String, dynamic>> get _filteredNegotiations {
    if (_negotiationTab == 0) {
      // Active tab - pending and countered negotiations
      return _negotiations
          .where((n) => ['pending', 'countered'].contains(n['status']))
          .toList();
    }
    // Completed tab - accepted, rejected, expired, converted negotiations
    return _negotiations
        .where(
          (n) => [
            'accepted',
            'rejected',
            'expired',
            'converted',
          ].contains(n['status']),
        )
        .toList();
  }

  Map<String, dynamic> _getNegStatusDisplay(
    String status,
    Map<String, dynamic> negotiation,
  ) {
    final l10n = context.l10n;
    final orderStatusLabel = DealDeskPresentation.orderStatusLabel(
      negotiation,
      l10n: l10n,
    );
    switch (status) {
      case 'pending':
        return {
          'label': orderStatusLabel == null
              ? l10n.homeDealStatusPending
              : orderStatusLabel.toUpperCase(),
          'color': const Color(0xFF6B7280),
          'bg': const Color(0xFFF3F4F6),
        };
      case 'countered':
        return {
          'label': orderStatusLabel == null
              ? l10n.homeDealStatusCountered
              : orderStatusLabel.toUpperCase(),
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFFFEF3C7),
        };
      case 'accepted':
        return {
          'label': (orderStatusLabel ?? l10n.statusDealAcceptedOrderPending)
              .toUpperCase(),
          'color': const Color(0xFF16A34A),
          'bg': const Color(0xFFDCFCE7),
        };
      case 'rejected':
        return {
          'label': orderStatusLabel == null
              ? l10n.homeDealStatusRejected
              : orderStatusLabel.toUpperCase(),
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
        };
      case 'expired':
        return {
          'label': orderStatusLabel == null
              ? l10n.homeDealStatusExpired
              : orderStatusLabel.toUpperCase(),
          'color': const Color(0xFF9CA3AF),
          'bg': const Color(0xFFF3F4F6),
        };
      case 'converted':
        return {
          'label': (orderStatusLabel ?? l10n.statusDealOrderCreated)
              .toUpperCase(),
          'color': const Color(0xFF0F766E),
          'bg': const Color(0xFFE6F7F5),
        };
      default:
        return {
          'label': orderStatusLabel == null
              ? status.toUpperCase()
              : orderStatusLabel.toUpperCase(),
          'color': const Color(0xFF6B7280),
          'bg': const Color(0xFFF3F4F6),
        };
    }
  }

  Widget _buildNegotiationsContent() {
    final l10n = context.l10n;
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          color: backgroundWhite,
          child: Text(
            l10n.homeDealDeskTitle,
            style: AppFonts.jakarta(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        // Tabs
        Container(
          color: backgroundWhite,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: borderLight, width: 1)),
            ),
            child: Row(
              children: [
                _buildNegotiationTab(l10n.homeDealTabActive, 0),
                _buildNegotiationTab(l10n.homeDealTabCompleted, 1),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: _isNegotiationsLoading
              ? const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                )
              : _filteredNegotiations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.handshake_outlined,
                        size: 48,
                        color: textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _negotiationTab == 0
                            ? l10n.homeDealEmptyActive
                            : l10n.homeDealEmptyCompleted,
                        style: AppFonts.jakarta(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.homeDealEmptyHint,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          color: const Color(0xFF4C669A),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNegotiations,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _filteredNegotiations.length,
                    itemBuilder: (context, index) =>
                        _buildNegotiationCard(_filteredNegotiations[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNegotiationTab(String label, int index) {
    final isSelected = _negotiationTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _negotiationTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryBlue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: isSelected ? primaryBlue : const Color(0xFF4C669A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNegotiationCard(Map<String, dynamic> negotiation) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final status = negotiation['status'] as String? ?? 'pending';
    final statusDisplay = _getNegStatusDisplay(status, negotiation);
    final product = negotiation['product'] as Map<String, dynamic>? ?? {};
    final productName = localizedName(
      context,
      product,
      fallback: l10n.homeUnknownProduct,
    );
    final imageUrl = product['image'] as String? ?? '';
    final quantity = negotiation['requestedQuantity'] ?? 0;
    final requestedPrice = negotiation['requestedPricePerUnit'] ?? 0;
    final currentPrice = negotiation['currentPricePerUnit'] ?? 0;
    final currentTotal = negotiation['currentTotalPrice'] ?? 0;
    final currentOfferBy = negotiation['currentOfferBy'] as String? ?? '';
    final negotiationNumber = negotiation['negotiationNumber'] as String? ?? '';
    final negotiationId = (negotiation['id'] ?? negotiation['_id'] ?? '')
        .toString();
    final canPay = negotiation['canPay'] == true;
    final createdAt = negotiation['createdAt'] as String? ?? '';

    String formattedDate = '';
    String formattedTime = '';
    if (createdAt.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(createdAt);
        formattedDate = DateFormat(
          'MMM d, yyyy',
          languageCode,
        ).format(dateTime);
        formattedTime = DateFormat('h:mm a', languageCode).format(dateTime);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () async {
          final result = await context.push(
            '/negotiation-detail/$negotiationId',
          );
          if (result == true) _fetchNegotiations();
        },
        child: Container(
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Product Image (100x100)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: const Color(0xFFF1F5F9)),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: Center(
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedImage01,
                                      color: textMuted,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedImage01,
                                    color: textMuted,
                                    size: 32,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right: Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Date, Time, Status
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDate.isNotEmpty
                                          ? formattedDate
                                          : l10n.homeNoDate,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.jakarta(
                                        fontSize: 11,
                                        color: textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (formattedTime.isNotEmpty)
                                      Text(
                                        formattedTime,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.jakarta(
                                          fontSize: 10,
                                          color: textMuted,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusDisplay['bg'] as Color,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    statusDisplay['label'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.jakarta(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: statusDisplay['color'] as Color,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // SKU / Negotiation Number
                          Text(
                            negotiationNumber.isNotEmpty
                                ? negotiationNumber
                                : l10n.homeNegotiationFallback,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4C669A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Product Name
                          Text(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Quantity
                          Text(
                            l10n.homeQtyUnits('$quantity'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF4C669A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Price Info (Compact)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: backgroundWhite,
                    borderRadius: BorderRadius.circular(6),
                    border: status == 'accepted'
                        ? const Border(
                            left: BorderSide(
                              color: Color(0xFF16A34A),
                              width: 3,
                            ),
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.homeYourPriceLabel,
                            style: AppFonts.jakarta(
                              fontSize: 11,
                              color: const Color(0xFF4C669A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₹$requestedPrice',
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            status == 'countered' && currentOfferBy == 'admin'
                                ? l10n.homeCounterLabel
                                : l10n.homeCurrentLabel,
                            style: AppFonts.jakarta(
                              fontSize: 11,
                              color: const Color(0xFF4C669A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₹$currentPrice',
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: status == 'accepted'
                                  ? const Color(0xFF16A34A)
                                  : primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.homeTotalLabel,
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            '₹$currentTotal',
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: status == 'accepted'
                                  ? const Color(0xFF16A34A)
                                  : textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Action Button
                _buildNegActionButton(
                  status,
                  currentOfferBy,
                  canPay,
                  negotiationId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNegActionButton(
    String status,
    String currentOfferBy,
    bool canPay,
    String negotiationId,
  ) {
    final l10n = context.l10n;
    String label;
    String style;
    IconData? icon;
    VoidCallback? onTap;
    if (status == 'countered' && currentOfferBy == 'admin') {
      label = l10n.homeRespondToCounter;
      style = 'primary';
      icon = Icons.reply_rounded;
      onTap = () async {
        final r = await context.push('/negotiation-detail/$negotiationId');
        if (r == true) _fetchNegotiations();
      };
    } else if (status == 'accepted' && canPay) {
      label = l10n.homeProceedToOrder;
      style = 'primary';
      icon = Icons.account_balance_wallet_rounded;
      onTap = () => _proceedToNegotiationOrder(negotiationId);
    } else if (status == 'pending') {
      label = l10n.homeUnderReview;
      style = 'disabled';
    } else if (status == 'rejected') {
      label = l10n.homeRejected;
      style = 'disabled';
    } else if (status == 'expired') {
      label = l10n.homeExpired;
      style = 'disabled';
    } else {
      label = l10n.commonViewDetails;
      style = 'outline';
      onTap = () async {
        final r = await context.push('/negotiation-detail/$negotiationId');
        if (r == true) _fetchNegotiations();
      };
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: style == 'primary'
              ? primaryBlue
              : style == 'disabled'
              ? borderLight
              : surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          border: style == 'outline' ? Border.all(color: borderLight) : null,
          boxShadow: style == 'primary' && icon != null
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: style == 'primary'
                    ? Colors.white
                    : style == 'disabled'
                    ? const Color(0xFF9CA3AF)
                    : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    if (ref.watch(guestModeProvider)) {
      return _buildCustomerPreviewProfile();
    }
    final l10n = context.l10n;
    final user = ref.watch(authProvider).user;
    final isGuest = user == null;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;
    final profileMaxWidth = isTablet ? 760.0 : double.infinity;
    final profileAvatarSize = isTablet ? 108.0 : 100.0;
    final quickStatSize = isTablet ? 128.0 : 100.0;

    final profileItems = [
      {
        'type': 'setting',
        'icon': Icons.translate,
        'color': const Color(0xFF0F766E),
        'title': context.isHindi
            ? l10n.languageTitle
            : '${l10n.languageTitle} / भाषा',
        'subtitle': context.isHindi ? l10n.languageHindi : l10n.languageEnglish,
        'onTap': () => showLanguagePicker(context, ref),
      },
      {
        'type': 'setting',
        'icon': HugeIcons.strokeRoundedLocation01,
        'color': const Color(0xFF059669),
        'title': l10n.homeProfileAddresses,
        'subtitle': null,
        'onTap': () {
          context.push('/addresses').then((_) => _loadSavedShippingAddresses());
        },
      },
      {
        'type': 'setting',
        'icon': HugeIcons.strokeRoundedNotification02,
        'color': const Color(0xFF0F766E),
        'title': l10n.homeNotificationsTitle,
        'subtitle': null,
        'onTap': () => context.push('/notifications', extra: {'bottomTab': 4}),
      },
      {
        'type': 'setting',
        'icon': HugeIcons.strokeRoundedHelpCircle,
        'color': const Color(0xFFD97706),
        'title': l10n.homeProfileHelpSupport,
        'subtitle': null,
        'onTap': () => context.push('/help'),
      },
      {
        'type': 'setting',
        'icon': HugeIcons.strokeRoundedFile01,
        'color': const Color(0xFF0891B2),
        'title': l10n.homeProfileLegalPolicies,
        'subtitle': null,
        'onTap': () => _showLegalPoliciesSheet(),
      },
      {
        'type': 'setting',
        'icon': Icons.privacy_tip_outlined,
        'color': const Color(0xFF0F766E),
        'title': l10n.homeProfileAccountPrivacy,
        'subtitle': null,
        'onTap': () => context.push(isGuest ? '/login' : '/account-privacy'),
      },
      {
        'type': 'setting',
        'icon': HugeIcons.strokeRoundedInformationCircle,
        'color': const Color(0xFF4338CA),
        'title': l10n.homeProfileAbout,
        'subtitle': null,
        'onTap': () => context.push('/about'),
      },
      if (!kHideOfferCouponUi)
        {
          'type': 'setting',
          'icon': HugeIcons.strokeRoundedTicket01,
          'color': const Color(0xFFDC2626),
          'title': l10n.homeProfileMyCoupons,
          'subtitle': null,
          'onTap': () => context.push('/my-coupons'),
        },
      if (user?.isWholesaler == true)
        {
          'type': 'setting',
          'icon': HugeIcons.strokeRoundedShoppingCart01,
          'color': primaryBlue,
          'title': l10n.homeProfileViewCustomerApp,
          'subtitle': l10n.homeProfileViewCustomerAppSubtitle,
          'onTap': () async {
            ref.read(guestModeProvider.notifier).enableGuestMode();
            try {
              await context.push('/guest-app-preview');
            } finally {
              await Future<void>.delayed(Duration.zero);
              ref.read(guestModeProvider.notifier).disableGuestMode();
            }
          },
        },
      if (user?.role != 'wholesaler')
        {
          'type': 'setting',
          'icon': HugeIcons.strokeRoundedStore02,
          'color': primaryBlue,
          'title': l10n.homeProfileApplyWholesaler,
          'subtitle': l10n.homeProfileApplyWholesalerSubtitle,
          'onTap': () => context.push('/convert-to-wholesaler'),
        },
    ];

    final wishlistCount = ref.watch(wishlistProvider).items.length;
    final orderCount = ref.watch(orderCountProvider).value ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Premium Profile Header
          Stack(
            children: [
              // Gradient Background with decorative shapes (fills header content)
              Positioned.fill(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.secondary, // Teal accent
                        AppColors.primary, // Brand teal
                        AppColors.primaryDark, // Deep teal
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative Circle 1
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // Decorative Circle 2
                      Positioned(
                        bottom: 40,
                        left: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Header Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 40, bottom: 56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: profileMaxWidth),
                    child: Column(
                      children: [
                        // Back Button & Settings Icon Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (_selectedNavIndex != 0) {
                                    setState(() => _selectedNavIndex = 0);
                                  }
                                },
                                icon: const Icon(
                                  HugeIcons.strokeRoundedArrowLeft01,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              Text(
                                l10n.homeProfileTitle,
                                style: AppFonts.jakarta(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                onPressed: () => context.push(
                                  isGuest ? '/login' : '/edit-profile',
                                ),
                                icon: const Icon(
                                  HugeIcons.strokeRoundedSettings01,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Animated Avatar
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white24,
                                ),
                                child: Container(
                                  width: profileAvatarSize,
                                  height: profileAvatarSize,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      user?.avatar != null &&
                                          user!.avatar!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: user.avatar!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                HugeIcons.strokeRoundedUser,
                                                size: 40,
                                                color: AppColors.primary,
                                              ),
                                        )
                                      : const Icon(
                                          HugeIcons.strokeRoundedUser,
                                          size: 40,
                                          color: AppColors.primary,
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // User Name
                        Text(
                          user?.name ?? l10n.homeGuestUser,
                          style: AppFonts.jakarta(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // User Email/Phone/Address
                        Column(
                          children: [
                            if (user != null && user.phone != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      HugeIcons.strokeRoundedCall02,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.phone!,
                                      style: AppFonts.jakarta(
                                        fontSize: 15,
                                        color: Colors.white.withOpacity(0.95),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (user != null &&
                                user.address != null &&
                                user.address!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      HugeIcons.strokeRoundedLocation01,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        user.address!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.jakarta(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isGuest ||
                                (user.phone == null && user.address == null))
                              Text(
                                user?.email ?? l10n.homeSignInToSync,
                                style: AppFonts.jakarta(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (isGuest) ...[
                              const SizedBox(height: 14),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  isTablet ? 0 : 24,
                                  0,
                                  isTablet ? 0 : 24,
                                  24,
                                ),
                                child: SizedBox(
                                  width: isTablet ? 420 : double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => context.push('/login'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.commonLogin,
                                      style: AppFonts.jakarta(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Main Content Card (overlapping the header)
          Transform.translate(
            offset: const Offset(0, -40),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 40 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: profileMaxWidth),
                  child: Column(
                    children: [
                      // Fast Actions / Stats row
                      // Fast Actions / Stats row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQuickStat(
                              HugeIcons.strokeRoundedPackage,
                              l10n.homeMyOrders,
                              orderCount.toString(),
                              size: quickStatSize,
                              color: AppColors.primary,
                              onTap: () => context.push('/previous-orders'),
                            ),
                            _buildQuickStat(
                              HugeIcons.strokeRoundedFavourite,
                              _isWholesaler
                                  ? l10n.homeWishlistDealer
                                  : l10n.homeWishlistCustomer,
                              wishlistCount.toString(),
                              size: quickStatSize,
                              color: const Color(0xFFF43F5E), // Vibrant Rose
                              onTap: () => context.push('/wishlist'),
                            ),
                            _buildQuickStat(
                              HugeIcons.strokeRoundedUserEdit01,
                              l10n.homeEditProfile,
                              '0',
                              size: quickStatSize,
                              color: const Color(0xFFF59E0B), // Amber
                              onTap: () => context.push(
                                isGuest ? '/login' : '/edit-profile',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Settings List Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: borderLight.withOpacity(0.7),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: List.generate(profileItems.length, (
                              index,
                            ) {
                              final item = profileItems[index];
                              final isHeader = item['type'] == 'header';
                              if (isHeader) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item['title'] as String,
                                      style: AppFonts.jakarta(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: textMuted,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final nextIsHeader =
                                  index < profileItems.length - 1 &&
                                  profileItems[index + 1]['type'] == 'header';
                              final showDivider =
                                  index < profileItems.length - 1 &&
                                  !nextIsHeader;

                              return _buildSettingItem(
                                icon: item['icon'] as IconData,
                                iconColor: item['color'] as Color,
                                title: item['title'] as String,
                                subtitle: item['subtitle'] as String?,
                                showDivider: showDivider,
                                onTap: item['onTap'] as VoidCallback,
                              );
                            }),
                          ),
                        ),
                      ),

                      // Danger Zone / Logout
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
                        child: TextButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (mounted) {
                              context.go('/login');
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            foregroundColor: Colors.red.shade600,
                            backgroundColor: Colors.red.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedLogout02,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          label: Text(
                            l10n.commonLogout,
                            style: AppFonts.jakarta(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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
        ],
      ),
    );
  }

  Widget _buildCustomerPreviewProfile() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUser,
                  color: primaryBlue,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.homePreviewGuestCustomer,
              style: AppFonts.jakarta(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.homePreviewProfileMessage,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 14,
                height: 1.5,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.pop();
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(context.l10n.homeExitCustomerPreview),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    IconData icon,
    String label,
    String value, {
    double size = 100,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                HugeIcon(icon: icon, color: color, size: 24),
                if (value != '0')
                  Positioned(
                    right: -10,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              label.toUpperCase(),
              style: AppFonts.jakarta(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textPrimary.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: borderLight.withOpacity(0.5),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(icon: icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLegalPoliciesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.homeProfileLegalPolicies,
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: LegalPolicyCatalog.items.length,
                      itemBuilder: (context, index) {
                        final policy = LegalPolicyCatalog.items[index];
                        return _buildPolicySheetItem(
                          icon: policy.icon,
                          color: policy.color,
                          title: policy.localizedTitle(context),
                          policyId: policy.id,
                        );
                      },
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

  Widget _buildPolicySheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required String policyId,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: HugeIcon(icon: icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      trailing: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        color: textMuted,
        size: 18,
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/legal/$policyId');
      },
    );
  }

  Widget _buildAppBar() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: backgroundWhite,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryBlue.withOpacity(0.14)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppFonts.jakarta(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -0.7,
                          ),
                          children: [
                            TextSpan(
                              text: '${l10n.homeBrandFirstWord} ',
                              style: TextStyle(color: textPrimary),
                            ),
                            TextSpan(
                              text: l10n.homeBrandSecondWord,
                              style: const TextStyle(color: primaryBlue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.homeBrandTagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<Locale>(
                offset: const Offset(0, 42),
                tooltip: l10n.languageTitle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (Locale value) {
                  ref.read(localeProvider.notifier).setLocale(value);
                },
                itemBuilder: (_) => [
                  _buildLanguageItem(
                    LocaleNotifier.english,
                    l10n.languageEnglish,
                  ),
                  _buildLanguageItem(LocaleNotifier.hindi, l10n.languageHindi),
                ],
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: primaryBlue,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        context.isHindi ? 'HI' : 'EN',
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: primaryBlue,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showNotificationPopup,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedNotification02,
                          color: textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_unreadCount',
                            textAlign: TextAlign.center,
                            style: AppFonts.jakarta(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<Locale> _buildLanguageItem(Locale value, String label) {
    final isSelected = (value.languageCode == 'hi') == context.isHindi;
    return PopupMenuItem<Locale>(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: AppFonts.jakarta(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primaryBlue : textPrimary,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, color: primaryBlue, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;
    final bannerHeight = isTablet ? 280.0 : 220.0;

    if (_isLoadingHeroBanners) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: bannerHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      );
    }
    if (_heroBanners.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: _heroBanners.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentCarouselIndex = index);
              // Pause auto-rotate while a video slide is visible.
              final current = _heroBanners[index];
              final currentMedia = (current['mediaType'] ?? 'image').toString();
              if (currentMedia != 'image' &&
                  (current['videoUrl'] ?? '').toString().isNotEmpty) {
                _heroAutoRotateTimer?.cancel();
              } else if (_heroBanners.length > 1 &&
                  _heroAutoRotateTimer?.isActive != true) {
                _startAutoRotate();
              }
            },
            itemBuilder: (context, index) {
              final item = _heroBanners[index];
              final mediaType = (item['mediaType'] ?? 'image').toString();
              final videoUrl = (item['videoUrl'] ?? '').toString();
              if ((mediaType == 'video_upload' || mediaType == 'youtube') &&
                  videoUrl.isNotEmpty) {
                final linkUrl = item['linkUrl']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: mediaType == 'youtube'
                      ? _HeroYoutubeSlide(
                          videoUrl: videoUrl,
                          posterUrl: (item['imageUrl'] ?? '').toString(),
                          linkUrl: linkUrl,
                          isActive: _currentCarouselIndex == index,
                          onOpenLink: () => _handleBannerTap(linkUrl),
                          onVideoComplete: () => _goToNextHeroSlide(),
                        )
                      : _HeroVideoSlide(
                          videoUrl: videoUrl,
                          posterUrl: (item['imageUrl'] ?? '').toString(),
                          linkUrl: linkUrl,
                          isActive: _currentCarouselIndex == index,
                          onOpenLink: () => _handleBannerTap(linkUrl),
                          onVideoComplete: () => _goToNextHeroSlide(),
                        ),
                );
              }
              final hasImage = (item['imageUrl'] ?? '').toString().isNotEmpty;
              final linkUrl = item['linkUrl']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _handleBannerTap(linkUrl),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: hasImage
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryBlue, primaryBlueDark],
                            ),
                      image: hasImage
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                item['imageUrl'],
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (hasImage)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['tag'] ?? l10n.homeBannerNewArrival,
                                  style: AppFonts.jakarta(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item['title'] ?? l10n.homeBannerExploreProducts,
                                style: AppFonts.jakarta(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item['buttonText'] ??
                                          l10n.homeBannerShopNow,
                                      style: AppFonts.jakarta(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    _getBannerIcon(
                                      item['buttonIcon'],
                                      primaryBlue,
                                      16,
                                    ),
                                  ],
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
            },
          ),
        ),
        if (_heroBanners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _heroBanners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentCarouselIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentCarouselIndex == index
                      ? primaryBlue
                      : primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleBannerTap(String linkUrl) {
    if (linkUrl.isEmpty) return;
    if (linkUrl.startsWith('/product/')) {
      context.push(linkUrl);
    } else if (linkUrl.startsWith('/category/')) {
      final categoryKey = Uri.decodeComponent(
        linkUrl.replaceFirst('/category/', ''),
      ).toLowerCase();
      Map<String, dynamic>? matchedCategory;
      for (final category in _searchCategoryData) {
        final keys = [
          category['id'],
          category['name'],
          category['slug'],
          category['queryName'],
        ].map((value) => value?.toString().toLowerCase());
        if (keys.contains(categoryKey)) {
          matchedCategory = category;
          break;
        }
      }
      if (matchedCategory == null) return;
      setState(() {
        _searchScope = _SearchScope.product;
        _selectedFilterCategoryId = matchedCategory!['id']?.toString();
        _selectedFilterBrandId = matchedCategory['brandId']?.toString();
        _selectedNavIndex = 1;
      });
      _searchProducts('');
    } else if (linkUrl.startsWith('http')) {
      launchUrl(Uri.parse(linkUrl), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildBrandsSection() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;
    final cardGap = isTablet ? 10.0 : 6.0;
    final cardWidth = isTablet
        ? 104.0
        : ((screenWidth - 32 - (cardGap * 4)) / 5).clamp(62.0, 76.0);
    final cardHeight = isTablet ? 122.0 : 104.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF0369A1).withOpacity(0.28), // Darker Sky Blue
            const Color(0xFF0EA5E9).withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.homeTopBrands,
                      style: AppFonts.jakarta(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedNavIndex = 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderLight),
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.commonSeeAll,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: cardHeight,
            child: _isLoadingBrands
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(right: cardGap),
                      child: Container(
                        width: cardWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  )
                : _brands.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.homeNoBrandsAvailable,
                      style: AppFonts.jakarta(color: textMuted),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _brands.length,
                    itemBuilder: (context, index) {
                      final brand = _brands[index];
                      final brandName = brand['name']?.toString() ?? '';
                      final accentColor = Color(
                        (brand['accent'] as int?) ?? 0xFF0F766E,
                      );
                      final hasLogo =
                          brand['logo'] != null &&
                          brand['logo'].toString().isNotEmpty;

                      return Padding(
                        padding: EdgeInsets.only(right: cardGap),
                        child: GestureDetector(
                          onTap: () {
                            final id = brand['id']?.toString() ?? '';
                            if (id.isEmpty) return;
                            context.push(
                              '/brand/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(brandName)}',
                            );
                          },
                          child: Container(
                            width: cardWidth,
                            padding: const EdgeInsets.fromLTRB(5, 6, 5, 7),
                            decoration: BoxDecoration(
                              color: surfaceWhite,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: const Color(0xFFE4EDF8),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF334155,
                                  ).withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: hasLogo
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                ApiConfig.normalizeMediaUrl(
                                                  brand['logo'].toString(),
                                                ),
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: accentColor,
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                _buildBrandInitial(
                                                  brandName,
                                                  accentColor,
                                                ),
                                          )
                                        : _buildBrandInitial(
                                            brandName,
                                            accentColor,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 25,
                                  child: Center(
                                    child: Text(
                                      brandName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.jakarta(
                                        fontSize: isTablet ? 10 : 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandInitial(String name, Color color) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initial,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsSection(String title, bool isFeatured) {
    final sectionProducts = isFeatured ? _featuredProducts : _hotProducts;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final productGridColumns = screenWidth >= 600
        ? 4
        : screenWidth >= 370
        ? 3
        : 2;
    final filteredProducts = sectionProducts.take(productGridColumns).toList();

    debugPrint(
      '🔵 [DISPLAY] Section: $title | isFeatured: $isFeatured | Available: ${sectionProducts.length} | Displayed: ${filteredProducts.length}',
    );

    final l10n = context.l10n;
    final subtitle = _isWholesaler
        ? isFeatured
              ? l10n.homePopularSubtitleDealer
              : l10n.homeHotDealsSubtitleDealer
        : isFeatured
        ? l10n.homePopularSubtitleCustomer
        : l10n.homeHotDealsSubtitleCustomer;
    const productGridSpacing = 7.0;
    const productGridHorizontalPadding = 10.0;
    final productCardHeight = productGridColumns == 2 ? 244.0 : 220.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EDFC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.jakarta(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.jakarta(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    if (isFeatured) {
                      context.push('/popular-products');
                    } else {
                      context.push('/hot-deals');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderLight),
                    ),
                    child: Row(
                      children: [
                        Text(
                          isFeatured ? l10n.commonSeeAll : l10n.commonViewAll,
                          style: AppFonts.jakarta(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: productGridHorizontalPadding,
            ),
            child: _isLoadingProducts
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: productGridColumns,
                      crossAxisSpacing: productGridSpacing,
                      mainAxisSpacing: productGridSpacing,
                      mainAxisExtent: productCardHeight,
                    ),
                    itemCount: productGridColumns,
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(
                        color: borderLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: textMuted.withOpacity(0.5),
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.homeNoProductsAvailable,
                            style: AppFonts.jakarta(color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: productGridColumns,
                      crossAxisSpacing: productGridSpacing,
                      mainAxisSpacing: productGridSpacing,
                      mainAxisExtent: productCardHeight,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      // Only show HOT badge in Hot Deals section, not in Popular Products
                      return _buildProductCard(
                        product,
                        showHotBadge: !isFeatured,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product, {
    bool showHotBadge = true,
  }) {
    final l10n = context.l10n;
    final productId = product['id'].toString();
    final heroTag = 'product-image-$productId';
    final hasOriginalPrice =
        product['originalPrice'] != null &&
        product['originalPrice'] != product['price'] &&
        (product['originalPrice'] as num?) != null &&
        (product['originalPrice'] as num) > 0;
    final discount = hasOriginalPrice
        ? (((product['originalPrice'] as num) - (product['price'] as num)) /
                  (product['originalPrice'] as num) *
                  100)
              .round()
        : 0;

    // Pick badge: HOT (only when showHotBadge=true) > SALE (discount) > NEW
    String? badgeLabel;
    Color? badgeColor;
    if (showHotBadge &&
        (product['isHot'] == true ||
            product['badge']?.toString().contains('HOT') == true)) {
      badgeLabel = l10n.homeBadgeHot; // Force clean label without flames
      badgeColor = const Color(0xFFEF4444);
    } else if (discount > 0) {
      badgeLabel = l10n.homeBadgeSale;
      badgeColor = const Color(0xFF16A34A);
    } else if (product['isNew'] == true) {
      badgeLabel = l10n.homeBadgeNew;
      badgeColor = primaryBlue;
    }

    final brand = (product['brand'] ?? product['category'] ?? '').toString();
    final rating = product['rating'];
    final reviewCount = product['reviewCount'] ?? product['reviews'] ?? '';
    final inStock = product['inStock'] != false;
    final isWishlisted = ref.watch(wishlistProvider).contains(productId);

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
            // ── Image area ──
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
                            ? CachedNetworkImage(
                                imageUrl: product['image'],
                                fit: BoxFit.contain,
                                placeholder: (_, __) => ProductImagePlaceholder(
                                  category:
                                      product['category']?.toString() ?? '',
                                  name: product['name']?.toString() ?? '',
                                ),
                                errorWidget: (_, __, ___) =>
                                    ProductImagePlaceholder(
                                      category:
                                          product['category']?.toString() ?? '',
                                      name: product['name']?.toString() ?? '',
                                    ),
                              )
                            : ProductImagePlaceholder(
                                category: product['category']?.toString() ?? '',
                                name: product['name']?.toString() ?? '',
                              ),
                      ),
                    ),
                    // Out of stock overlay
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
                    // Badge (top-left)
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
                              _showGuestModePopup(
                                l10n.homePreviewWishlistDisabled,
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
                                    price:
                                        (product['price'] as num?)
                                            ?.toDouble() ??
                                        0,
                                    mrp: hasOriginalPrice
                                        ? (product['originalPrice'] as num)
                                              .toDouble()
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
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.isEmpty ? l10n.homeBrandName : brand,
                    style: AppFonts.jakarta(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 30,
                    child: Text(
                      _getDisplayName(product),
                      style: AppFonts.jakarta(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (rating != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$rating',
                          style: AppFonts.jakarta(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                          ),
                        ),
                        if (reviewCount != null &&
                            reviewCount.toString().isNotEmpty) ...[
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
                                '₹${_formatPrice(product['price'] ?? 0)}',
                                style: AppFonts.jakarta(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            if (hasOriginalPrice)
                              Text(
                                '₹${_formatPrice(product['originalPrice'])}',
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
                                  _showGuestModePopup(
                                    l10n.homePreviewAddToCartDisabled,
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
                                final quantity = _isWholesaler
                                    ? math.max(minimumWholesaleQuantity, 1)
                                    : 1;
                                ref
                                    .read(cartProvider.notifier)
                                    .addItem(
                                      productId: productId,
                                      name: product['name'] ?? '',
                                      nameHindi: product['nameHindi']
                                          ?.toString(),
                                      brand: product['brand']?.toString(),
                                      category: product['category']?.toString(),
                                      minWholesaleQuantity:
                                          minimumWholesaleQuantity,
                                      price: (product['price'] as num)
                                          .toDouble(),
                                      mrp: hasOriginalPrice
                                          ? (product['originalPrice'] as num)
                                                .toDouble()
                                          : null,
                                      image: product['image']?.toString(),
                                      quantity: quantity,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.homeAddedToCart,
                                      style: AppFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: primaryBlue,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
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
                                l10n.homeAdd,
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

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final val = (price is int) ? price.toDouble() : (price as num).toDouble();
    return NumberFormatter.formatLakhs(val);
  }

  // ============ Dealer home sections (wholesalers only) ============

  String _dealerDealLabel(String status, String currentOfferBy) {
    if (status == 'countered' && currentOfferBy == 'admin') {
      return context.l10n.homeDealNewPriceReceived;
    }
    return context.l10n.homeDealRequirementSent;
  }

  String _dealerOrderStage(String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'pending_payment':
        return l10n.homeStagePaymentPending;
      case 'payment_uploaded':
        return l10n.homeStageVerificationPending;
      case 'payment_verified':
        return l10n.homeStagePaymentVerified;
      case 'processing':
        return l10n.homeStagePacking;
      case 'shipped':
        return l10n.homeStageDispatched;
      case 'delivered':
        return l10n.homeStageDelivered;
      case 'cancelled':
        return l10n.homeStageCancelled;
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _dealerStageColor(String status) {
    switch (status) {
      case 'payment_verified':
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'shipped':
      case 'processing':
        return primaryBlue;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _dealerSectionHeader(
    String title,
    String actionLabel,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dealerCard({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildScheduledChanges() {
    if (_isLoadingScheduledChanges && _scheduledChanges.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_scheduledChanges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _ScheduledStripCarousel(
        items: _scheduledChanges,
        onOpen: (productId) => context.push('/product/$productId'),
      ),
    );
  }

  Widget _buildContinueDeals() {
    final deals = _openHomeDeals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dealerSectionHeader(
          context.l10n.homeContinueDealChat,
          context.l10n.homeDealDeskTitle,
          () => _selectNavIndex(3),
        ),
        if (_isNegotiationsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (deals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _dealerCard(
              onTap: () => _selectNavIndex(2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      color: primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.homeNoOpenDeals,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: deals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final deal = deals[index];
                final product = deal['product'] as Map<String, dynamic>? ?? {};
                final status = (deal['status'] ?? 'pending').toString();
                final offerBy = (deal['currentOfferBy'] ?? '').toString();
                final total =
                    deal['currentTotalPrice'] ??
                    deal['requestedTotalPrice'] ??
                    0;
                final imageUrl = (product['image'] ?? '').toString();
                final isCounter = status == 'countered' && offerBy == 'admin';
                return SizedBox(
                  width: 250,
                  child: _dealerCard(
                    onTap: () async {
                      final id = (deal['id'] ?? deal['_id'] ?? '').toString();
                      if (id.isEmpty) return;
                      await context.push('/negotiation-detail/$id');
                      _fetchNegotiations();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          color: backgroundWhite,
                                          child: const Icon(
                                            Icons.handshake_outlined,
                                            color: textMuted,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: primaryBlue.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.handshake_outlined,
                                          color: primaryBlue,
                                          size: 24,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      (deal['negotiationNumber'] ?? '')
                                          .toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.jakarta(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: textMuted,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      localizedName(
                                        context,
                                        product,
                                        fallback: context
                                            .l10n
                                            .homeRequirementFallback,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.jakarta(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.homeDealQtyTotal(
                                    '${deal['requestedQuantity'] ?? ''}',
                                    _formatPrice(total),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isCounter
                                              ? const Color(0xFFF59E0B)
                                              : textMuted)
                                          .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  _dealerDealLabel(status, offerBy),
                                  maxLines: 1,
                                  style: AppFonts.jakarta(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: isCounter
                                        ? const Color(0xFFF59E0B)
                                        : textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTrackHomeOrders() {
    final orders = _activeHomeOrders;
    if (_isLoadingHomeOrders || orders.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dealerSectionHeader(
          context.l10n.homeTrackActiveOrders,
          context.l10n.homeAllOrders,
          () => context.push('/previous-orders'),
        ),
        ...orders.map((order) {
          final orderId = (order['id'] ?? '').toString();
          final status = (order['status'] ?? '').toString();
          final stageColor = _dealerStageColor(status);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _dealerCard(
              onTap: orderId.isEmpty
                  ? null
                  : () => context.push('/tracking/$orderId'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: stageColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        color: stageColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.homeOrderNumber(
                              (order['orderNumber'] ?? '').toString(),
                            ),
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.homeOrderStageTotal(
                              _dealerOrderStage(status),
                              _formatPrice(order['total']),
                            ),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRepeatHomeOrders() {
    final orders = _repeatableHomeOrders;
    if (_isLoadingHomeOrders || orders.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dealerSectionHeader(
          context.l10n.homeRepeatRequirement,
          context.l10n.homeAllOrders,
          () => context.push('/previous-orders'),
        ),
        ...orders.map((order) {
          final items =
              (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final first = items.isNotEmpty ? items.first : {};
          final orderId = (order['id'] ?? '').toString();
          final isRepeating = _repeatingOrderId == orderId;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _dealerCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.homeRepeatItemQty(
                              localizedName(
                                context,
                                first,
                                fallback: context.l10n.homeOrderFallback,
                              ),
                              '${first['quantity'] ?? ''}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.homeOrderNumberTotal(
                              (order['orderNumber'] ?? '').toString(),
                              _formatPrice(order['total']),
                            ),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: isRepeating
                          ? null
                          : () => _repeatRequirement(order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isRepeating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                context.l10n.homeRepeatButton,
                                style: AppFonts.jakarta(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // Checkout state for cart address + coupon
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  List<ShippingAddress> _savedShippingAddresses = [];
  String? _selectedShippingAddressId;
  final _couponCtrl = TextEditingController();
  bool _isApplyingCoupon = false;
  String? _appliedCouponCode;
  double _appliedCouponDiscount = 0;
  double? _appliedCouponSubtotalSnapshot;
  int? _appliedCouponItemCountSnapshot;

  String get _normalizedCouponInput => _couponCtrl.text.trim().toUpperCase();

  bool _hasActiveAppliedCoupon(CartState cart) {
    return _appliedCouponCode != null &&
        _appliedCouponCode == _normalizedCouponInput &&
        _appliedCouponSubtotalSnapshot == cart.subtotal &&
        _appliedCouponItemCountSnapshot == cart.itemCount;
  }

  void _clearAppliedCouponPreview({bool clearInput = false}) {
    if (clearInput) _couponCtrl.clear();
    _appliedCouponCode = null;
    _appliedCouponDiscount = 0;
    _appliedCouponSubtotalSnapshot = null;
    _appliedCouponItemCountSnapshot = null;
  }

  Future<void> _applyCouponPreview({
    bool showSuccessToast = true,
    bool showErrorToast = true,
    bool recordRedeem = true,
  }) async {
    final l10n = context.l10n;
    final cart = ref.read(cartProvider);
    final couponCode = _normalizedCouponInput;
    if (_isApplyingCoupon || couponCode.isEmpty || cart.items.isEmpty) return;

    setState(() => _isApplyingCoupon = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/orders/preview-coupon',
        data: {'couponCode': couponCode},
      );
      final data = Map<String, dynamic>.from(response.data['data'] ?? {});
      final discount = (data['discount'] as num?)?.toDouble() ?? 0;
      final discountSource = (data['discountSource'] as String?) ?? 'offer';

      if (!mounted) return;
      final latestCart = ref.read(cartProvider);
      setState(() {
        _isApplyingCoupon = false;
        _appliedCouponCode = couponCode;
        _appliedCouponDiscount = discount;
        _appliedCouponSubtotalSnapshot = latestCart.subtotal;
        _appliedCouponItemCountSnapshot = latestCart.itemCount;
      });
      if (recordRedeem) {
        final user = ref.read(authProvider).user;
        final userKey = user?.id.isNotEmpty == true
            ? user!.id
            : (user?.phone ?? user?.email ?? 'guest');
        await RedeemedCouponService.redeemCoupon(
          userKey: userKey,
          code: couponCode,
          title: couponCode,
          rule: l10n.homeCouponAppliedAtCheckout,
        );
      }
      if (showSuccessToast) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              discountSource == 'affiliate'
                  ? l10n.homeAffiliateCodeApplied
                  : l10n.homeCouponAppliedSuccess,
              style: AppFonts.jakarta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg =
          e.response?.data?['message']?.toString() ?? l10n.homeInvalidCoupon;
      setState(() {
        _isApplyingCoupon = false;
        _clearAppliedCouponPreview();
      });
      if (showErrorToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: AppFonts.jakarta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isApplyingCoupon = false);
    }
  }

  Future<void> _autoReapplyCouponIfNeeded() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      if (mounted) {
        setState(() => _clearAppliedCouponPreview(clearInput: true));
      }
      return;
    }

    if (_appliedCouponCode == null) return;
    if (_normalizedCouponInput != _appliedCouponCode) return;
    if (_hasActiveAppliedCoupon(cart)) return;
    if (_isApplyingCoupon) return;

    await _applyCouponPreview(
      showSuccessToast: false,
      showErrorToast: false,
      recordRedeem: false,
    );
  }

  Future<void> _updateCartQtyAndRefreshCoupon(
    String productId,
    int quantity,
  ) async {
    await ref.read(cartProvider.notifier).updateQuantity(productId, quantity);
    await _autoReapplyCouponIfNeeded();
  }

  Future<void> _removeCartItemAndRefreshCoupon(String productId) async {
    await ref.read(cartProvider.notifier).removeItem(productId);
    await _autoReapplyCouponIfNeeded();
  }

  Future<void> _loadSavedShippingAddresses() async {
    final addresses = await ShippingAddressService.getAddresses();
    final selectedId = await ShippingAddressService.getSelectedAddressId();
    if (!mounted) return;

    setState(() {
      _savedShippingAddresses = addresses;
      _selectedShippingAddressId =
          selectedId ?? (addresses.isNotEmpty ? addresses.first.id : null);
    });

    final selected = _getSelectedShippingAddress();
    if (selected != null) {
      _setAddressControllersFromMap(selected.toOrderPayload());
    }
  }

  ShippingAddress? _getSelectedShippingAddress() {
    if (_savedShippingAddresses.isEmpty) return null;
    return _savedShippingAddresses.firstWhere(
      (a) => a.id == _selectedShippingAddressId,
      orElse: () => _savedShippingAddresses.first,
    );
  }

  void _setAddressControllersFromMap(Map<String, String> address) {
    _nameCtrl.text = address['fullName'] ?? '';
    _phoneCtrl.text = address['phone'] ?? '';
    _addr1Ctrl.text = address['addressLine1'] ?? '';
    _cityCtrl.text = address['city'] ?? '';
    _stateCtrl.text = address['state'] ?? '';
    _pinCtrl.text = address['pincode'] ?? '';
  }

  Future<bool> _openCartAddressBottomSheet() async {
    final auth = ref.read(authProvider);
    final l10n = context.l10n;
    final fk = GlobalKey<FormState>();

    final selected = _getSelectedShippingAddress();
    final initial =
        selected?.toOrderPayload() ??
        {
          'fullName': _nameCtrl.text.isNotEmpty
              ? _nameCtrl.text
              : (auth.user?.name ?? ''),
          'phone': _phoneCtrl.text.isNotEmpty
              ? _phoneCtrl.text
              : (auth.user?.phone ?? ''),
          'addressLine1': _addr1Ctrl.text,
          'city': _cityCtrl.text,
          'state': _stateCtrl.text,
          'pincode': _pinCtrl.text,
        };

    final nameC = TextEditingController(text: initial['fullName'] ?? '');
    final phoneC = TextEditingController(text: initial['phone'] ?? '');
    final addr1C = TextEditingController(text: initial['addressLine1'] ?? '');
    final cityC = TextEditingController(text: initial['city'] ?? '');
    final stateC = TextEditingController(text: initial['state'] ?? '');
    final pinC = TextEditingController(text: initial['pincode'] ?? '');

    String? selectedId = _selectedShippingAddressId;

    final address = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: fk,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: borderLight,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    Text(
                      l10n.homeShippingAddress,
                      style: AppFonts.jakarta(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (_savedShippingAddresses.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _savedShippingAddresses.map((a) {
                            final active = selectedId == a.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  '${a.fullName} • ${a.shortAddress}',
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active ? Colors.white : textPrimary,
                                  ),
                                ),
                                selected: active,
                                onSelected: (_) {
                                  setSheetState(() => selectedId = a.id);
                                  nameC.text = a.fullName;
                                  phoneC.text = a.phone;
                                  addr1C.text = a.addressLine1;
                                  cityC.text = a.city;
                                  stateC.text = a.state;
                                  pinC.text = a.pincode;
                                },
                                selectedColor: primaryBlue,
                                backgroundColor: const Color(0xFFF1F5F9),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _addrField(l10n.homeFieldFullName, nameC),
                    const SizedBox(height: 12),
                    _addrField(
                      l10n.homeFieldPhone,
                      phoneC,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _addrField(l10n.homeFieldAddressLine1, addr1C),
                    const SizedBox(height: 12),
                    StateCityPincodeFields(
                      stateController: stateC,
                      cityController: cityC,
                      pincodeController: pinC,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!fk.currentState!.validate()) return;
                          Navigator.of(ctx).pop({
                            'id': selectedId ?? ShippingAddress.generateId(),
                            'fullName': nameC.text.trim(),
                            'phone': phoneC.text.trim(),
                            'addressLine1': addr1C.text.trim(),
                            'city': cityC.text.trim(),
                            'state': stateC.text.trim(),
                            'pincode': pinC.text.trim(),
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.homeSaveAddress,
                          style: AppFonts.jakarta(
                            fontSize: 15,
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
      ),
    );

    // Let modal route teardown complete before touching state/navigation.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    if (address == null || !mounted) return false;

    final savedAddress = ShippingAddress(
      id: address['id'] ?? ShippingAddress.generateId(),
      fullName: address['fullName'] ?? '',
      phone: address['phone'] ?? '',
      addressLine1: address['addressLine1'] ?? '',
      city: address['city'] ?? '',
      state: address['state'] ?? '',
      pincode: address['pincode'] ?? '',
      slot: '',
    );

    await ShippingAddressService.upsertAddress(savedAddress);
    await ShippingAddressService.setSelectedAddressId(savedAddress.id);
    await _loadSavedShippingAddresses();
    _setAddressControllersFromMap(savedAddress.toOrderPayload());
    return true;
  }

  Future<void> _proceedToCheckout() async {
    // Check if in guest mode first
    if (ref.read(guestModeProvider)) {
      await _showGuestModePopup(context.l10n.homePreviewCheckoutDisabled);
      return;
    }

    if (!ref.read(authProvider).isAuthenticated) {
      await _showCheckoutLoginRequiredPopup();
      return;
    }

    final cart = ref.read(cartProvider);
    final hasActiveCoupon = _hasActiveAppliedCoupon(cart);
    final typedCoupon = _normalizedCouponInput;
    if (typedCoupon.isNotEmpty && !hasActiveCoupon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.homeTapApplyCoupon,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Validate stock before opening address sheet
    setState(() => _isCheckingOut = true);
    final result = await ref.read(cartProvider.notifier).validateStock();
    if (!mounted) return;
    setState(() => _isCheckingOut = false);

    final bool valid = result['valid'] ?? true;
    if (!valid) {
      final issues = ((result['issues'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      _showStockIssueSnackbar(issues);
      return;
    }

    final saved = await _openCartAddressBottomSheet();
    if (!saved || !mounted) return;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _confirmAndPay();
  }

  void _showStockIssueSnackbar(List<Map<String, dynamic>> issues) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeStockIssuesTitle,
              style: AppFonts.jakarta(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            ...issues.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${i['message'] ?? l10n.homeStockIssueFallback}',
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _confirmAndPay() async {
    final l10n = context.l10n;
    final cart = ref.read(cartProvider);
    final hasActiveCoupon = _hasActiveAppliedCoupon(cart);

    final address = {
      'fullName': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'addressLine1': _addr1Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pinCtrl.text.trim(),
    };

    setState(() {
      _isCheckingOut = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      final payload = <String, dynamic>{'shippingAddress': address};
      if (hasActiveCoupon && _appliedCouponCode != null) {
        payload['couponCode'] = _appliedCouponCode;
      }
      final response = await api.post('/orders', data: payload);

      if (!mounted) return;
      setState(() => _isCheckingOut = false);

      if (response.data['success'] == true) {
        _clearAppliedCouponPreview(clearInput: true);
        ref.read(cartProvider.notifier).clearCart();
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        await OrderCheckoutActionsSheet.handleSuccessfulCheckout(
          context: context,
          apiClient: api,
          responseData: response.data,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
      if (e.response?.statusCode == 401) {
        await _showCheckoutLoginRequiredPopup();
        return;
      }
      final data = e.response?.data;
      final map = data is Map ? data : null;
      final error = map?['error'];
      final errorMap = error is Map ? error : null;
      final msg = apiErrorText(context, e, fallback: l10n.homeCheckoutFailed);
      // If it's a stock issue from the server, refresh cart to show updated stock
      final code = map?['code']?.toString() ?? errorMap?['code']?.toString();
      if (code == 'INSUFFICIENT_STOCK' ||
          code == 'MIN_WHOLESALE_QUANTITY_NOT_MET') {
        ref.read(cartProvider.notifier).fetchCart();
        ref.read(cartProvider.notifier).validateStock();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _showCheckoutLoginRequiredPopup() async {
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) return;

    final shouldOpenLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.homeGuestPromptTitle),
          content: Text(context.l10n.homeCheckoutLoginMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.homeNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.commonLogin),
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

  Future<void> _showGuestModePopup(String title) async {
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(context.l10n.homePreviewFeatureDisabled),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  Future<void> _proceedToNegotiationOrder(String negotiationId) async {
    final auth = ref.read(authProvider);
    final nameC = TextEditingController(text: auth.user?.name ?? '');
    final phoneC = TextEditingController(text: auth.user?.phone ?? '');
    final addr1C = TextEditingController();
    final cityC = TextEditingController();
    final stateC = TextEditingController();
    final pinC = TextEditingController();
    final fk = GlobalKey<FormState>();
    final l10n = context.l10n;

    final address = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: fk,
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
                        color: borderLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Text(
                    l10n.homeShippingAddress,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _addrField(l10n.homeFieldFullName, nameC),
                  const SizedBox(height: 12),
                  _addrField(
                    l10n.homeFieldPhone,
                    phoneC,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _addrField(l10n.homeFieldAddressLine1, addr1C),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _addrField(l10n.homeFieldCity, cityC)),
                      const SizedBox(width: 12),
                      Expanded(child: _addrField(l10n.homeFieldState, stateC)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _addrField(
                    l10n.homeFieldPincode,
                    pinC,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (fk.currentState!.validate()) {
                          Navigator.of(ctx).pop({
                            'fullName': nameC.text.trim(),
                            'phone': phoneC.text.trim(),
                            'addressLine1': addr1C.text.trim(),
                            'city': cityC.text.trim(),
                            'state': stateC.text.trim(),
                            'pincode': pinC.text.trim(),
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.homeConfirmAndProceed,
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

    nameC.dispose();
    phoneC.dispose();
    addr1C.dispose();
    cityC.dispose();
    stateC.dispose();
    pinC.dispose();

    if (address == null || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/orders/from-negotiation',
        data: {'negotiationId': negotiationId, 'shippingAddress': address},
      );

      if (!mounted) return;
      if (response.data['success'] == true) {
        await OrderCheckoutActionsSheet.handleSuccessfulCheckout(
          context: context,
          apiClient: api,
          responseData: response.data,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg =
          e.response?.data?['message']?.toString() ??
          l10n.homeCreateOrderFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.homeErrorWithDetails('$e'),
            style: AppFonts.jakarta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _addrField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? context.l10n.commonRequired : null,
      style: AppFonts.jakarta(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppFonts.jakarta(fontSize: 14, color: textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildPromoBannerCarousel() {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final bannerHeight = isTablet ? 190.0 : 160.0;

    if (_isLoadingPromoBanners) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: bannerHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      );
    }
    if (_promoBanners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _promoBannerController,
            itemCount: _promoBanners.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPromoBannerIndex = i),
            itemBuilder: (context, index) {
              final banner = _promoBanners[index];
              final hasImage = (banner['imageUrl'] ?? '').toString().isNotEmpty;
              final linkUrl = banner['linkUrl'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _handleBannerTap(linkUrl),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasImage)
                            CachedNetworkImage(
                              imageUrl: banner['imageUrl'] ?? '',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: primaryBlue.withOpacity(0.05),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryBlue.withOpacity(0.1),
                                      primaryBlue.withOpacity(0.2),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryBlue.withOpacity(0.12),
                                    primaryBlueDark.withOpacity(0.22),
                                  ],
                                ),
                              ),
                            ),
                          // Text Content Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  hasImage
                                      ? Colors.black.withOpacity(0.7)
                                      : primaryBlueDark.withOpacity(0.92),
                                  hasImage
                                      ? Colors.transparent
                                      : primaryBlue.withOpacity(0.8),
                                ],
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxHeight < 170;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: isCompact ? 14 : 20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (banner['tag'] != null &&
                                          banner['tag'].isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          margin: EdgeInsets.only(
                                            bottom: isCompact ? 5 : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            banner['tag'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.jakarta(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      if (banner['title'] != null &&
                                          banner['title'].isNotEmpty)
                                        Flexible(
                                          child: Text(
                                            banner['title'],
                                            style: AppFonts.jakarta(
                                              fontSize: isCompact ? 18 : 20,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              height: 1.05,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      SizedBox(height: isCompact ? 7 : 12),
                                      Flexible(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isCompact ? 12 : 16,
                                            vertical: isCompact ? 6 : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  banner['buttonText'] ??
                                                      context
                                                          .l10n
                                                          .homeBannerShopNow,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppFonts.jakarta(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: primaryBlue,
                                                  ),
                                                ),
                                              ),
                                              _getBannerIcon(
                                                banner['buttonIcon'],
                                                primaryBlue,
                                                14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_promoBanners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _promoBanners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPromoBannerIndex == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPromoBannerIndex == index
                      ? primaryBlue
                      : primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _getBannerIcon(String? iconName, Color color, double size) {
    if (iconName == 'none') {
      return const SizedBox.shrink();
    }

    String effectiveIcon = (iconName == null || iconName.trim().isEmpty)
        ? 'arrowright'
        : iconName.toLowerCase().trim();

    IconData iconData;
    switch (effectiveIcon) {
      case 'arrowright':
      case 'moveright':
      case 'chevronright':
        iconData = HugeIcons.strokeRoundedArrowRight01;
        break;
      case 'arrowupright':
        iconData = HugeIcons.strokeRoundedArrowUpRight01;
        break;
      case 'shoppingcart':
      case 'shoppingcart01icon':
        iconData = HugeIcons.strokeRoundedShoppingCart01;
        break;
      case 'externallink':
        iconData = HugeIcons.strokeRoundedLink01;
        break;
      case 'play':
      case 'playcircle':
        iconData = HugeIcons.strokeRoundedPlay;
        break;
      case 'eye':
        iconData = HugeIcons.strokeRoundedView;
        break;
      case 'info':
        iconData = HugeIcons.strokeRoundedInformationCircle;
        break;
      case 'package':
        iconData = HugeIcons.strokeRoundedPackage;
        break;
      case 'arrowrightcircle':
        iconData = HugeIcons.strokeRoundedArrowRight01;
        break;
      case 'heart':
        iconData = HugeIcons.strokeRoundedFavourite;
        break;
      case 'star':
        iconData = HugeIcons.strokeRoundedStar;
        break;
      case 'home':
        iconData = HugeIcons.strokeRoundedHome01;
        break;
      case 'user':
        iconData = HugeIcons.strokeRoundedUser;
        break;
      case 'settings':
        iconData = HugeIcons.strokeRoundedSettings01;
        break;
      case 'bell':
        iconData = HugeIcons.strokeRoundedNotification01;
        break;
      case 'check':
      case 'checkcircle':
        iconData = HugeIcons.strokeRoundedCheckmarkCircle01;
        break;
      case 'x':
      case 'xcircle':
        iconData = HugeIcons.strokeRoundedCancel01;
        break;
      case 'phone':
        iconData = HugeIcons.strokeRoundedCall;
        break;
      case 'mail':
        iconData = HugeIcons.strokeRoundedMail01;
        break;
      case 'plus':
        iconData = HugeIcons.strokeRoundedPlusSign;
        break;
      case 'minus':
        iconData = HugeIcons.strokeRoundedMinusSign;
        break;
      case 'lock':
      case 'unlock':
        iconData = HugeIcons.strokeRoundedSettings01; // Closer safe mapping
        break;
      case 'trash':
        iconData = HugeIcons.strokeRoundedDelete01;
        break;
      case 'search':
      case 'search01icon':
        iconData = HugeIcons.strokeRoundedSearch01;
        break;
      case 'calendar':
      case 'calendar01icon':
        iconData = HugeIcons.strokeRoundedCalendar01;
        break;
      case 'camera':
      case 'camera01icon':
        iconData = HugeIcons.strokeRoundedCamera01;
        break;
      case 'share':
      case 'share01icon':
        iconData = HugeIcons.strokeRoundedShare01;
        break;
      case 'download':
      case 'download01icon':
        iconData = HugeIcons.strokeRoundedDownload01;
        break;
      case 'upload':
      case 'upload01icon':
        iconData = HugeIcons.strokeRoundedUpload01;
        break;
      case 'tag':
      case 'tag01icon':
        iconData = HugeIcons.strokeRoundedTag01;
        break;
      case 'ticket':
      case 'ticket01icon':
        iconData = HugeIcons.strokeRoundedTicket01;
        break;
      case 'store':
      case 'store01icon':
        iconData = HugeIcons.strokeRoundedStore01;
        break;
      case 'gift':
      case 'gifticon':
        iconData = HugeIcons.strokeRoundedGift;
        break;
      case 'flash':
      case 'zap':
      case 'flashicon':
        iconData = HugeIcons.strokeRoundedFlash;
        break;
      case 'badgepercent':
      case 'percent':
      case 'percent01icon':
        iconData =
            HugeIcons.strokeRoundedCoins01; // Fallback for percent-like icon
        break;
      case 'shoppingbag':
      case 'shoppingbag01icon':
        iconData = HugeIcons.strokeRoundedShoppingBag01;
        break;
      case 'truck':
      case 'deliverybox01icon':
        iconData = HugeIcons.strokeRoundedDeliveryBox01;
        break;
      case 'creditcard':
      case 'creditcardicon':
        iconData = HugeIcons.strokeRoundedCreditCard;
        break;
      case 'arrowright':
      case 'arrowright01icon':
        iconData = HugeIcons.strokeRoundedArrowRight01;
        break;
      case 'sparkles':
      case 'sparklesicon':
        iconData = HugeIcons.strokeRoundedSparkles;
        break;
      default:
        iconData = HugeIcons.strokeRoundedArrowRight01;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(iconData, color: color, size: size),
    );
  }

  Widget _buildWhyBuySection() {
    final l10n = context.l10n;
    final items = [
      {
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF0F766E),
        'bg': const Color(0xFFF0FDFA),
        'title': l10n.homeWhyBuyQualityTitle,
        'subtitle': l10n.homeWhyBuyQualitySubtitle,
      },
      {
        'icon': Icons.local_offer_rounded,
        'color': const Color(0xFF0F766E),
        'bg': const Color(0xFFE6F7F5),
        'title': l10n.homeWhyBuyPricingTitle,
        'subtitle': l10n.homeWhyBuyPricingSubtitle,
      },
      {
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFF0891B2),
        'bg': const Color(0xFFECFEFF),
        'title': l10n.homeWhyBuyDeliveryTitle,
        'subtitle': l10n.homeWhyBuyDeliverySubtitle,
      },
      {
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFF0FDF4),
        'title': l10n.homeWhyBuySupportTitle,
        'subtitle': l10n.homeWhyBuySupportSubtitle,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              l10n.homeWhyBuyTitle,
              textAlign: TextAlign.center,
              style: AppFonts.jakarta(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildWhyBuyItem(items[0])),
                const SizedBox(width: 16),
                Expanded(child: _buildWhyBuyItem(items[1])),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildWhyBuyItem(items[2])),
                const SizedBox(width: 16),
                Expanded(child: _buildWhyBuyItem(items[3])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhyBuyItem(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (item['bg'] as Color).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item['icon'] as IconData,
            color: item['color'] as Color,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            item['title'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item['subtitle'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.jakarta(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    final l10n = context.l10n;

    if (_isLoadingReviews && _dynamicReviews.isEmpty) {
      return const SizedBox.shrink();
    }

    final reviews = _dynamicReviews.isNotEmpty
        ? _dynamicReviews
        : [
            {
              'name': l10n.homeSampleReview1Name,
              'role': l10n.homeSampleReview1Role,
              'review': l10n.homeSampleReview1Text,
              'rating': 5.0,
            },
            {
              'name': l10n.homeSampleReview2Name,
              'role': l10n.homeSampleReview2Role,
              'review': l10n.homeSampleReview2Text,
              'rating': 5.0,
            },
            {
              'name': l10n.homeSampleReview3Name,
              'role': l10n.homeSampleReview3Role,
              'review': l10n.homeSampleReview3Text,
              'rating': 4.5,
            },
            {
              'name': l10n.homeSampleReview4Name,
              'role': l10n.homeSampleReview4Role,
              'review': l10n.homeSampleReview4Text,
              'rating': 5.0,
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeReviewsEyebrow,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.homeReviewsTitle,
                    style: AppFonts.jakarta(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  color: primaryBlue,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 24, right: 8, bottom: 20),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: reviews
                .map(
                  (review) => _buildReviewCard(
                    Map<String, String>.from({
                      'name': review['name'].toString(),
                      'role': review['role'].toString(),
                      'review': review['review'].toString(),
                      'rating': review['rating'].toString(),
                    }),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, String> review) {
    return Container(
      width: 310,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Icon(
                Icons.format_quote_rounded,
                size: 100,
                color: Colors.black.withOpacity(0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primaryBlue, primaryBlue.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            review['name']!.substring(0, 1).toUpperCase(),
                            style: AppFonts.jakarta(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    review['name']!,
                                    style: AppFonts.jakarta(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF10B981),
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              review['role']!,
                              style: AppFonts.jakarta(
                                fontSize: 13,
                                color: textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        double rating = double.parse(review['rating']!);
                        if (index < rating.floor()) {
                          return const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          );
                        } else if (index < rating) {
                          return const Icon(
                            Icons.star_half_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          );
                        } else {
                          return const Icon(
                            Icons.star_outline_rounded,
                            color: Color(0xFFE2E8F0),
                            size: 18,
                          );
                        }
                      }),
                      const SizedBox(width: 8),
                      Text(
                        review['rating']!,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    review['review']!,
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      color: textSecondary.withOpacity(0.9),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: _isWholesaler
                ? [
                    _buildNavItem(
                      HugeIcons.strokeRoundedHome01,
                      l10n.homeNavHome,
                      0,
                    ),
                    _buildNavItem(
                      HugeIcons.strokeRoundedSearch01,
                      l10n.homeNavSearch,
                      1,
                    ),
                    _buildNavItem(
                      HugeIcons.strokeRoundedDashboardSquare01,
                      l10n.homeNavCategories,
                      2,
                    ),
                    _buildNavItem(
                      HugeIcons.strokeRoundedBriefcase01,
                      l10n.homeNavDealDesk,
                      3,
                    ),
                    _buildNavItem(
                      HugeIcons.strokeRoundedUser,
                      l10n.homeNavProfile,
                      4,
                    ),
                  ]
                : [
                    _buildNavItem(
                      HugeIcons.strokeRoundedHome01,
                      l10n.homeNavHome,
                      0,
                    ),
                    _buildNavItem(
                      HugeIcons.strokeRoundedSearch01,
                      l10n.homeNavSearch,
                      1,
                    ),
                    _buildNavItem(
                      HugeIcons.strokeRoundedDashboardSquare01,
                      l10n.homeNavCategories,
                      2,
                    ),
                    _buildCartNavItem(3),
                    _buildNavItem(
                      HugeIcons.strokeRoundedUser,
                      l10n.homeNavProfile,
                      4,
                    ),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartNavItem(int index) {
    final isSelected = _selectedNavIndex == index;
    final cart = ref.watch(cartProvider);
    final itemCount = ref.watch(guestModeProvider) ? 0 : cart.itemCount;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedNavIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedShoppingCart01,
                      color: isSelected ? primaryBlue : textMuted,
                      size: 24,
                    ),
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$itemCount',
                          style: AppFonts.jakarta(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppFonts.jakarta(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? primaryBlue : textMuted,
                ),
                child: Text(context.l10n.homeNavCart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectNavIndex(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: HugeIcon(
                  icon: icon,
                  color: isSelected ? primaryBlue : textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppFonts.jakarta(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? primaryBlue : textMuted,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// TRUST BADGE MARQUEE (auto-scrolling strip)
// ══════════════════════════════════════════
class _TrustBadgeMarquee extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool isActive;
  const _TrustBadgeMarquee({required this.items, required this.isActive});

  @override
  State<_TrustBadgeMarquee> createState() => _TrustBadgeMarqueeState();
}

class _TrustBadgeMarqueeState extends State<_TrustBadgeMarquee> {
  late final ScrollController _scrollController;
  bool _isAutoScrolling = false;

  static const Color _blue = Color(0xFF0F766E);
  static const Color _txtSec = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) _startScroll();
    });
  }

  @override
  void didUpdateWidget(covariant _TrustBadgeMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startScroll();
      return;
    }
    if (!widget.isActive && oldWidget.isActive) {
      _isAutoScrolling = false;
    }
  }

  void _startScroll() {
    if (_isAutoScrolling) return;
    _isAutoScrolling = true;
    _autoScrollLoop();
  }

  Future<void> _autoScrollLoop() async {
    while (mounted && _isAutoScrolling) {
      if (!widget.isActive) break;
      if (!_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }

      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        continue;
      }

      final remaining = (max - _scrollController.offset).clamp(0.0, max);
      if (remaining <= 1) {
        _scrollController.jumpTo(0);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        continue;
      }

      // Smooth GPU-driven animation is cheaper than a 30ms jumpTo timer loop.
      final durationMs = (remaining * 18).clamp(900, 7000).toInt();
      try {
        await _scrollController.animateTo(
          max,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted || !_isAutoScrolling) break;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  @override
  void dispose() {
    _isAutoScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: _blue.withOpacity(0.04),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.items.length,
        itemBuilder: (_, i) {
          final item = widget.items[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item['icon'] as IconData, size: 16, color: _blue),
                const SizedBox(width: 6),
                Text(
                  item['text'] as String,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _txtSec,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Helpers for ticket-style offer cards ──────────────────────────────────────

class _PartnershipMarquee extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool isActive;
  const _PartnershipMarquee({required this.items, required this.isActive});

  @override
  State<_PartnershipMarquee> createState() => _PartnershipMarqueeState();
}

class _PartnershipMarqueeState extends State<_PartnershipMarquee> {
  late final ScrollController _scrollController;
  bool _isAutoScrolling = false;

  static const Color _blue = Color(0xFF0F766E);
  static const Color _txtSec = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) _startScroll();
    });
  }

  @override
  void didUpdateWidget(covariant _PartnershipMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startScroll();
      return;
    }
    if (!widget.isActive && oldWidget.isActive) {
      _isAutoScrolling = false;
    }
  }

  void _startScroll() {
    if (_isAutoScrolling) return;
    _isAutoScrolling = true;
    _autoScrollLoop();
  }

  Future<void> _autoScrollLoop() async {
    while (mounted && _isAutoScrolling) {
      if (!widget.isActive) break;
      if (!_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }

      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        continue;
      }

      final remaining = (max - _scrollController.offset).clamp(0.0, max);
      if (remaining <= 1) {
        _scrollController.jumpTo(0);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        continue;
      }

      final durationMs = (remaining * 18).clamp(900, 7000).toInt();
      try {
        await _scrollController.animateTo(
          max,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted || !_isAutoScrolling) break;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  @override
  void dispose() {
    _isAutoScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;
        final pills = widget.items.map(_buildPill).toList();

        if (isTablet) {
          _isAutoScrolling = false;
          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(mainAxisSize: MainAxisSize.min, children: pills),
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: pills,
        );
      },
    );
  }

  Widget _buildPill(Map<String, dynamic> item) {
    final imagePath = item['image'] as String?;
    final imageUrl = item['imageUrl'] as String?;
    final icon = item['icon'] as IconData?;
    final label = (item['label'] ?? '') as String;

    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    Icon(Icons.handshake_outlined, size: 16, color: _blue),
              ),
            )
          else if (imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Image.asset(
                imagePath,
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.handshake_outlined, size: 16, color: _blue),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 16, color: _blue)
          else
            Icon(Icons.handshake_outlined, size: 16, color: _blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppFonts.jakarta(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _txtSec,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  @override
  Path getClip(Size size) {
    const double r = 10.0; // corner radius
    const double cr = 11.0; // cutout radius
    final double cy = size.height / 2; // cutout Y position

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, cy - cr)
      ..arcToPoint(
        Offset(size.width, cy + cr),
        radius: const Radius.circular(cr),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, cy + cr)
      ..arcToPoint(
        Offset(0, cy - cr),
        radius: const Radius.circular(cr),
        clockwise: false,
      )
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) => false;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    const double dw = 9.0;
    const double ds = 5.0;
    const double dh = 2.5;
    double x = 18.0;
    final double cy = size.height / 2;

    while (x < size.width - 18) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          cy - dh / 2,
          x + dw,
          cy + dh / 2,
          const Radius.circular(2),
        ),
        paint,
      );
      x += dw + ds;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}

class _VerticalDashedLinePainter extends CustomPainter {
  const _VerticalDashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;

    const double dashH = 5.0;
    const double gap = 4.0;
    const double dashW = 1.4;
    double y = 8.0;
    final double cx = size.width / 2;

    while (y < size.height - 8) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          cx - dashW / 2,
          y,
          cx + dashW / 2,
          y + dashH,
          const Radius.circular(2),
        ),
        paint,
      );
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(_VerticalDashedLinePainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const bars = [
      1.0,
      1.8,
      0.9,
      2.3,
      1.2,
      2.0,
      1.0,
      1.6,
      2.4,
      0.9,
      1.7,
      1.1,
      2.1,
      1.0,
      1.5,
      2.2,
      0.9,
      1.8,
      1.0,
      1.4,
      2.3,
      1.1,
      1.7,
      0.9,
    ];
    double y = 0;
    final left = size.width * 0.06;
    final right = size.width * 0.94;

    for (var i = 0; i < bars.length; i += 1) {
      final height = bars[i];
      paint.color = i.isEven
          ? const Color(0xFF334155)
          : const Color(0xFF94A3B8);
      canvas.drawRect(Rect.fromLTRB(left, y, right, y + height), paint);
      y += height + 1.35;
      if (y > size.height) break;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => false;
}

class _StarburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final Offset src = Offset(size.width / 2, size.height * -0.1);
    const int rayCount = 16;
    const double spread = 3.14159 * 1.1;

    for (int i = 0; i < rayCount; i++) {
      final double angle = -spread / 2 + (spread / (rayCount - 1)) * i;
      const double len = 380.0;
      const double halfW = 22.0;

      final double ex = src.dx + len * math.sin(angle);
      final double ey = src.dy + len * math.cos(angle);

      final double lx = src.dx + halfW * math.cos(angle);
      final double ly = src.dy - halfW * math.sin(angle);
      final double rx = src.dx - halfW * math.cos(angle);
      final double ry = src.dy + halfW * math.sin(angle);

      final path = Path()
        ..moveTo(lx, ly)
        ..lineTo(
          ex + halfW * math.cos(angle) * 0.3,
          ey - halfW * math.sin(angle) * 0.3,
        )
        ..lineTo(
          ex - halfW * math.cos(angle) * 0.3,
          ey + halfW * math.sin(angle) * 0.3,
        )
        ..lineTo(rx, ry)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StarburstPainter oldDelegate) => false;
}

/// Urgency tint shared by price-change UI: calm blue from 6h out,
/// amber under 6h, red under 1h. Discrete zones, no muddy mid-blends.
Color pulseAccentFor(DateTime? effectiveAt) {
  const primaryBlue = Color(0xFF134E4A);
  if (effectiveAt == null) return primaryBlue;
  final remain = effectiveAt.difference(DateTime.now());
  if (remain.isNegative || remain.inMinutes < 60) {
    return const Color(0xFFDC2626);
  }
  if (remain.inHours < 6) return const Color(0xFFF59E0B);
  return primaryBlue;
}

String changeCountdownFor(AppLocalizations l10n, DateTime effectiveAt) {
  final diff = effectiveAt.difference(DateTime.now());
  if (diff.isNegative) return l10n.homePriceApplyingSoon;
  if (diff.inHours >= 1) {
    final mins = diff.inMinutes % 60;
    final when = mins > 0
        ? l10n.homeDurationHoursMinutes('${diff.inHours}', '$mins')
        : l10n.homeDurationHours('${diff.inHours}');
    return l10n.homeNewPriceEffectiveIn(when);
  }
  final mins = diff.inMinutes;
  return mins > 0
      ? l10n.homeNewPriceEffectiveIn(l10n.homeDurationMinutes('$mins'))
      : l10n.homePriceApplyingSoon;
}

/// Compact auto-scrolling price-change strip carousel.
class _ScheduledStripCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String productId) onOpen;
  const _ScheduledStripCarousel({required this.items, required this.onOpen});

  @override
  State<_ScheduledStripCarousel> createState() =>
      _ScheduledStripCarouselState();
}

class _ScheduledStripCarouselState extends State<_ScheduledStripCarousel> {
  Timer? _timer;
  int _index = 0;

  static const Color _primaryBlue = Color(0xFF134E4A);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  String _fmt(dynamic price) {
    if (price == null) return '0';
    final val = (price is int) ? price.toDouble() : (price as num).toDouble();
    return NumberFormatter.formatLakhs(val);
  }

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) _startAutoRotate();
  }

  void _startAutoRotate() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _goTo(_index + 1);
    });
  }

  void _goTo(int next) {
    if (widget.items.isEmpty) return;
    final len = widget.items.length;
    setState(() => _index = ((next % len) + len) % len);
  }

  @override
  void didUpdateWidget(covariant _ScheduledStripCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _index = 0;
      return;
    }
    if (_index >= widget.items.length) _index = 0;
    if (widget.items.length > 1 && _timer == null) {
      _startAutoRotate();
    }
    if (widget.items.length <= 1) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < 0) {
                _goTo(_index + 1);
              } else if (details.primaryVelocity! > 0) {
                _goTo(_index - 1);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Front animated card.
                Positioned(
                  left: 20,
                  right: 20,
                  top: 0,
                  bottom: 4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(animation);
                      final scale = Tween<double>(
                        begin: 0.95,
                        end: 1.0,
                      ).animate(animation);
                      return SlideTransition(
                        position: slide,
                        child: FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: scale, child: child),
                        ),
                      );
                    },
                    child: Builder(
                      key: ValueKey<int>(_index),
                      builder: (context) {
                        if (widget.items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final item = widget.items[_index % widget.items.length];
                        final current =
                            (item['currentPrice'] as num?)?.toDouble() ?? 0;
                        final next =
                            (item['newPrice'] as num?)?.toDouble() ?? 0;
                        final dropping = next < current;
                        final effectiveAt = DateTime.tryParse(
                          (item['effectiveAt'] ?? '').toString(),
                        );
                        final productId = (item['id'] ?? '').toString();
                        final pct = current > 0
                            ? ((next - current) / current * 100)
                            : 0.0;
                        final accent = dropping
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF59E0B);
                        final urgency = pulseAccentFor(effectiveAt);
                        final remain =
                            effectiveAt?.difference(DateTime.now()) ??
                            Duration.zero;
                        final l10n = context.l10n;
                        final remainLabel = effectiveAt == null
                            ? '--'
                            : remain.isNegative
                            ? l10n.homeCountdownSoon
                            : remain.inHours >= 1
                            ? l10n.homeDurationHoursMinutes(
                                '${remain.inHours}',
                                '${remain.inMinutes % 60}',
                              )
                            : l10n.homeDurationMinutes('${remain.inMinutes}');
                        return GestureDetector(
                          onTap: productId.isEmpty
                              ? null
                              : () => widget.onOpen(productId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _surfaceWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: urgency.withOpacity(0.55),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: urgency.withOpacity(0.1),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: urgency.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: urgency,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        localizedName(context, item),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.jakarta(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: _textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '₹${_fmt(current)} → ₹${_fmt(next)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppFonts.jakarta(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: accent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                                            style: AppFonts.jakarta(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        effectiveAt == null
                                            ? l10n.homeScheduled
                                            : changeCountdownFor(
                                                l10n,
                                                effectiveAt,
                                              ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.jakarta(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: urgency,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: urgency.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        remainLabel,
                                        maxLines: 1,
                                        style: AppFonts.jakarta(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: urgency,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Text(
                                        l10n.homeTimeLeft,
                                        style: AppFonts.jakarta(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: urgency.withOpacity(0.7),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.items.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _index == i
                      ? _primaryBlue
                      : _primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline muted-autoplay video slide for hero video_upload banners.
/// Button + link only: the whole slide opens the link, mute toggle is separate.
class _HeroVideoSlide extends StatefulWidget {
  final String videoUrl;
  final String posterUrl;
  final String linkUrl;
  final bool isActive;
  final VoidCallback onOpenLink;
  final VoidCallback onVideoComplete;
  const _HeroVideoSlide({
    required this.videoUrl,
    required this.posterUrl,
    required this.linkUrl,
    required this.isActive,
    required this.onOpenLink,
    required this.onVideoComplete,
  });

  @override
  State<_HeroVideoSlide> createState() => _HeroVideoSlideState();
}

class _HeroVideoSlideState extends State<_HeroVideoSlide> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _muted = true;
  bool _notifiedComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(false)
      ..setVolume(0)
      ..addListener(_onTick)
      ..initialize().then(
        (_) {
          if (!mounted) return;
          setState(() => _initialized = true);
          _playIfActive();
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _hasError = true);
        },
      );
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !_initialized || _notifiedComplete) return;
    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 300)) {
      _notifiedComplete = true;
      widget.onVideoComplete();
    }
  }

  void _playIfActive() {
    if (!mounted || !_initialized || _hasError) return;
    if (widget.isActive) {
      _controller?.play();
    }
  }

  void _replay() {
    _notifiedComplete = false;
    _controller?.seekTo(Duration.zero);
    _controller?.play();
  }

  @override
  void didUpdateWidget(_HeroVideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) return;
    if (widget.isActive && !oldWidget.isActive) {
      _replay();
    } else if (widget.isActive) {
      _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenLink,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F766E).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_initialized && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (widget.posterUrl.isNotEmpty && !_hasError)
              CachedNetworkImage(
                imageUrl: widget.posterUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              ),
            if (!_initialized && !_hasError)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            // Bottom gradient for button legibility (no title/desc).
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                ),
              ),
            ),
            // Mute toggle (does not navigate).
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () async {
                  final next = !_muted;
                  await _controller?.setVolume(next ? 0 : 1);
                  if (mounted) setState(() => _muted = next);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 18,
                    color: Colors.white,
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

String _heroYoutubeId(String url) {
  final match = RegExp(
    r'(?:youtube\.com\/(?:watch\?[^#]*v=|shorts\/|embed\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})',
    caseSensitive: false,
  ).firstMatch(url.trim());
  return match?.group(1) ?? '';
}

/// Inline YouTube slide for hero youtube banners.
/// Thumbnail-first (autoplay policies): tap plays muted inline.
class _HeroYoutubeSlide extends StatefulWidget {
  final String videoUrl;
  final String posterUrl;
  final String linkUrl;
  final bool isActive;
  final VoidCallback onOpenLink;
  final VoidCallback onVideoComplete;
  const _HeroYoutubeSlide({
    required this.videoUrl,
    required this.posterUrl,
    required this.linkUrl,
    required this.isActive,
    required this.onOpenLink,
    required this.onVideoComplete,
  });

  @override
  State<_HeroYoutubeSlide> createState() => _HeroYoutubeSlideState();
}

class _HeroYoutubeSlideState extends State<_HeroYoutubeSlide> {
  YoutubePlayerController? _controller;
  bool _playing = false;

  String get _videoId => _heroYoutubeId(widget.videoUrl);

  String get _thumbnail {
    if (widget.posterUrl.isNotEmpty) return widget.posterUrl;
    if (_videoId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$_videoId/hqdefault.jpg';
    }
    return '';
  }

  @override
  void didUpdateWidget(_HeroYoutubeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && _playing) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startInline() {
    if (_videoId.isEmpty) {
      widget.onOpenLink();
      return;
    }
    _controller ??= YoutubePlayerController(
      initialVideoId: _videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: true,
        loop: true,
        enableCaption: false,
      ),
    );
    setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_playing && _controller != null)
            YoutubePlayer(
              controller: _controller!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFF0F766E),
              onEnded: (_) => widget.onVideoComplete(),
            )
          else ...[
            if (_thumbnail.isNotEmpty)
              GestureDetector(
                onTap: _startInline,
                child: CachedNetworkImage(
                  imageUrl: _thumbnail,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                ),
              ),
            ),
            // Link button -> opens linked product/brand/category.
            Positioned(
              left: 16,
              bottom: 14,
              child: GestureDetector(
                onTap: widget.onOpenLink,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    context.l10n.homeBannerShopNow,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
