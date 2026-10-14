import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/utils/coming_soon.dart';
import '../../core/utils/packing.dart';
import '../../core/providers/locale_provider.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/pack_text.dart';
import '../../widgets/cart_requirement.dart';
import '../../widgets/coming_soon_badge.dart';
import '../../widgets/deal_desk_groups.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/language_wave.dart';
import '../../core/config/api_config.dart';
import '../../core/config/feature_flags.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../core/services/redeemed_coupon_service.dart';
import '../../core/services/shipping_address_service.dart';
import '../../widgets/state_city_pincode_fields.dart';
import '../../core/services/storage_service.dart';
import '../cart/cart_parts.dart';
import '../categories/categories_screen.dart';
import '../negotiations/deal_desk_widgets.dart';
import '../profile/legal_policy_screen.dart';
import 'home_parts.dart';
import '../profile/profile_parts.dart';
import '../../core/utils/customer_order_presentation.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../widgets/app_image.dart';
import '../../widgets/notification_countdown_label.dart';
import '../../widgets/order_checkout_actions_sheet.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/order_count_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/product_search.dart';
import '../../core/utils/recent_searches.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/ui/ui.dart';

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

class _MarketplaceHomeScreenState extends ConsumerState<MarketplaceHomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _internalGeneralProductsBrand = 'GENERAL PRODUCTS';
  static const Duration _guestInitialFreeUseDuration = Duration(minutes: 3);
  static const Duration _guestPromptRepeatDuration = Duration(hours: 24);
  late int _selectedNavIndex;
  bool _isCheckingOut = false;
  // The visible slide of each carousel. Notifiers, so a slide change
  // rebuilds only the dots and video slides, not the whole screen.
  final ValueNotifier<int> _currentCarouselIndex = ValueNotifier(0);
  // Slightly under full width so the next banner peeks in at the edge.
  final PageController _carouselController = PageController(
    viewportFraction: 0.94,
  );
  final TextEditingController _searchController = TextEditingController();

  // The search bar gliding from Home into the Search tab's field.
  final GlobalKey _homeSearchBarKey = GlobalKey();
  final GlobalKey _heroCarouselKey = GlobalKey();
  final GlobalKey _promoCarouselKey = GlobalKey();
  final GlobalKey _searchFieldKey = GlobalKey();
  late final AnimationController _searchFlight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    // At rest the Search page is fully shown.
    value: 1,
  );
  // Even ease in and out, so the glide reads as movement, not a jump.
  late final Animation<double> _searchFlightCurve = CurvedAnimation(
    parent: _searchFlight,
    curve: Curves.easeInOutCubic,
  );
  // The rest of the Search page fades in once the bar is on its way.
  late final Animation<double> _searchPageFade = CurvedAnimation(
    parent: _searchFlight,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );
  OverlayEntry? _searchFlightEntry;
  bool _searchBarFlying = false;
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

  // State for dynamic data
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _featuredProducts = [];
  List<Map<String, dynamic>> _hotProducts = [];
  List<Map<String, dynamic>> _comingSoonProducts = [];
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
  final ValueNotifier<int> _currentPromoBannerIndex = ValueNotifier(0);
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
    _fetchComingSoonProducts();
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

          // Sort brands by admin order, then name
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
        'comingSoon': item['comingSoon'] == true,
        'priceHidden': item['priceHidden'] == true,
        'expectedDate': item['expectedDate'],
        'discount': 0,
        'rating': item['rating'] ?? 4.5,
        'reviewCount': item['reviewCount'] ?? item['reviews'] ?? '',
        'purchaseCountMin': item['purchaseCountMin'] ?? 0,
        'purchaseCountMax': item['purchaseCountMax'] ?? 0,
        'minWholesaleQuantity': item['minWholesaleQuantity'],
        'priceUnit': item['priceUnit'],
        'packing': item['packing'],
        'minCustomerQuantity': item['minCustomerQuantity'],
        'pendingPriceChange': item['pendingPriceChange'],
      };
    }
    return productsById.values.toList();
  }

  // Home "Coming Soon" row; hidden when there are none.
  Future<void> _fetchComingSoonProducts() async {
    try {
      final response = await _dio.get(
        '/products',
        queryParameters: {'comingSoon': true, 'limit': 6},
      );
      if (!mounted) return;
      final List<dynamic> items = response.data['data'] ?? const [];
      setState(() {
        _comingSoonProducts = _mapProductItems(
          items,
        ).where(isComingSoonProduct).toList();
      });
    } catch (e) {
      debugPrint('Coming soon products not loaded: $e');
    }
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
      final next = (_currentCarouselIndex.value + 1) % _heroBanners.length;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Whether [key]'s widget is on Home and on screen: the Home tab is showing,
  /// no other page covers it, and some of it is below the pinned search bar.
  bool _isShowingOnHome(GlobalKey key) {
    if (!mounted || _selectedNavIndex != 0) return false;
    // Off while another page is pushed over this one.
    if (!TickerMode.getNotifier(context).value) return false;
    final rect = _globalRectOf(key);
    if (rect == null) return false;
    final top = HomeHeroHeaderDelegate.collapsedHeight(
      MediaQuery.paddingOf(context).top,
    );
    return rect.bottom > top && rect.top < MediaQuery.sizeOf(context).height;
  }

  // Each tick is skipped while its carousel can't be seen, so a hidden
  // carousel doesn't keep sliding and rebuilding the page.
  void _startAutoRotate() {
    _heroAutoRotateTimer?.cancel();
    _promoAutoRotateTimer?.cancel();
    if (_heroBanners.length > 1) {
      _heroAutoRotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_isShowingOnHome(_heroCarouselKey)) _goToNextHeroSlide();
      });
    }
    if (_promoBanners.length > 1) {
      _promoAutoRotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_promoBannerController.hasClients &&
            _isShowingOnHome(_promoCarouselKey)) {
          final next =
              (_currentPromoBannerIndex.value + 1) % _promoBanners.length;
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
      _fetchComingSoonProducts(),
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
      'comingSoon': item['comingSoon'] == true,
      'priceHidden': item['priceHidden'] == true,
      'expectedDate': item['expectedDate'],
      'shortDescription': item['shortDescription']?.toString() ?? '',
      'rating': item['rating'],
      'purchaseCountMin': item['purchaseCountMin'] ?? 0,
      'purchaseCountMax': item['purchaseCountMax'] ?? 0,
      'minWholesaleQuantity': item['minWholesaleQuantity'],
      'priceUnit': item['priceUnit'],
      'packing': item['packing'],
      'minCustomerQuantity': item['minCustomerQuantity'],
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
        HugeIcons.strokeRoundedPackage,
      ),
      (
        _SearchScope.brand,
        l10n.homeSearchScopeBrand,
        HugeIcons.strokeRoundedStore01,
      ),
      (
        _SearchScope.category,
        l10n.homeSearchScopeCategory,
        HugeIcons.strokeRoundedDashboardSquare01,
      ),
    ];

    return PopupMenuButton<_SearchScope>(
      tooltip: l10n.homeSearchFilterTooltip,
      position: PopupMenuPosition.under,
      // The button sits at the right edge, so Flutter right-aligns the menu
      // with it; no sideways nudge, just a small drop below the bar.
      offset: const Offset(0, 10),
      constraints: const BoxConstraints.tightFor(width: 184),
      color: AppColors.surfaceLight,
      elevation: 12,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (scope) => _selectSearchScope(scope, openSearch: openSearch),
      itemBuilder: (context) => options.map((option) {
        final selected = option.$1 == _searchScope;
        return PopupMenuItem<_SearchScope>(
          value: option.$1,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              HugeIcon(
                icon: option.$3,
                size: 19,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  option.$2,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
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
                  top: MediaQuery.paddingOf(ctx).top + 60,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {}, // absorb taps on the popup itself
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.sizeOf(ctx).width * 0.88,
                        constraints: const BoxConstraints(maxHeight: 420),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(AppRadius.xl - 4),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.raised,
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
                                          color: AppColors.textPrimary,
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
                                            color: AppColors.primary,
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
                                        TextButton(
                                          onPressed: () =>
                                              _markNotificationsRead(
                                                setDialogState,
                                              ),
                                          child: Text(
                                            l10n.homeNotificationsMarkAllRead,
                                            style: AppFonts.jakarta(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        tooltip: l10n.commonClose,
                                        onPressed: () => Navigator.pop(ctx),
                                        icon: const HugeIcon(
                                          icon: HugeIcons.strokeRoundedCancel01,
                                          size: 20,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Content
                            _isLoadingNotifications
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: SkeletonShimmer(
                                      child: Column(
                                        children: [
                                          for (var i = 0; i < 3; i++)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  Skeleton(
                                                    width: 40,
                                                    height: 40,
                                                    radius: AppRadius.md,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Skeleton(height: 12),
                                                        SizedBox(height: 6),
                                                        Skeleton(
                                                          width: 140,
                                                          height: 10,
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
                                  )
                                : _notifications.isEmpty
                                ? EmptyState(
                                    icon: HugeIcons.strokeRoundedNotification02,
                                    title: l10n.homeNotificationsEmptyTitle,
                                    message:
                                        l10n.homeNotificationsEmptySubtitle,
                                    compact: true,
                                  )
                                : Flexible(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      itemCount: _notifications.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1, indent: 68),
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

                                        return InkWell(
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
                              const Divider(height: 1),
                              InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  // Reading them there clears the badge.
                                  context.push('/notifications').then((_) {
                                    if (mounted) _fetchNotificationCount();
                                  });
                                },
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: Center(
                                    child: Text(
                                      l10n.homeNotificationsViewAll,
                                      style: AppFonts.jakarta(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
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
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        iconColor = AppColors.success;
        iconBg = AppColors.successSoft;
        break;
      case 'payment_rejected':
        icon = HugeIcons.strokeRoundedCancelCircle;
        iconColor = AppColors.error;
        iconBg = AppColors.errorSoft;
        break;
      case 'order_update':
        icon = HugeIcons.strokeRoundedDeliveryTruck01;
        iconColor = AppColors.primary;
        iconBg = AppColors.primaryTint;
        break;
      case 'negotiation_update':
        icon = HugeIcons.strokeRoundedAgreement02;
        iconColor = AppColors.warning;
        iconBg = AppColors.warningSoft;
        break;
      case 'price_change_campaign_started':
      case 'price_change_campaign_12h':
      case 'price_change_campaign_6h':
      case 'price_change_campaign_20m':
      case 'price_change_campaign_3h':
      case 'price_change_campaign_1h':
      case 'price_change_campaign_5m':
      case 'price_change_campaign_applied':
        icon = HugeIcons.strokeRoundedClock01;
        iconColor = AppColors.warning;
        iconBg = AppColors.warningSoft;
        break;
      default:
        icon = HugeIcons.strokeRoundedNotification02;
        iconColor = AppColors.secondary;
        iconBg = AppColors.secondarySoft;
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
      color: isRead ? Colors.transparent : AppColors.primaryTint,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: HugeIcon(icon: icon, size: 20, color: iconColor),
            ),
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
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
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                NotificationCountdownLabel(
                  data: data,
                  color: AppColors.warning,
                  fontSize: 11,
                ),
                if (timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: AppFonts.jakarta(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
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
    _searchFlightEntry?.remove();
    _searchFlight.dispose();
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
    _currentCarouselIndex.dispose();
    _currentPromoBannerIndex.dispose();
    _dealPages.dispose();
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
      // Wholesaler nav: Home, Search, Categories, Cart, Deal Desk. Profile is
      // opened from the button next to notifications in the home header.
      // Page indexes stay fixed (Deal Desk 3, Profile 4) so existing links
      // such as /home?tab=4 keep working; Cart is page 5.
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
        _buildCartContent(),
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
        // Home's teal header runs up behind the status bar: light icons.
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: _selectedNavIndex == 0
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: _selectedNavIndex == 0
              ? Brightness.dark
              : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _selectedNavIndex,
                  children: [
                    // Home draws its own header under the status bar.
                    // Hidden tabs get TickerMode off, which pauses their
                    // animations and the Home hero's videos.
                    for (var i = 0; i < pages.length; i++)
                      TickerMode(
                        enabled: i == _selectedNavIndex,
                        child: SafeArea(
                          top: i != 0,
                          bottom: false,
                          child: pages[i],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // The floating nav sits over the body, which runs behind it.
          extendBody: true,
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final l10n = context.l10n;
    final user = ref.watch(authProvider).user;
    final firstName = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final header = HomeHeroHeaderDelegate(
      topInset: MediaQuery.paddingOf(context).top,
      topRow: _buildHomeTopRow(),
      greeting: firstName.isEmpty
          ? l10n.homeGreeting
          : l10n.homeGreetingName(firstName),
      headline: _isWholesaler
          ? l10n.homeHeadlineDealer
          : l10n.homeHeadlineCustomer,
      search: _buildHomeSearchBar(),
    );
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      edgeOffset: header.minExtent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPersistentHeader(pinned: true, delegate: header),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 22),
                _buildCategorySection(),
                const SizedBox(height: 26),
                _buildCarousel(),
                if (_isWholesaler) ...[
                  // The dealer section headers bring 20 of their own, so
                  // this makes the usual 28 between sections.
                  const SizedBox(height: 8),
                  _buildScheduledChanges(),
                  _buildContinueDeals(),
                  _buildTrackHomeOrders(),
                  _buildRepeatHomeOrders(),
                ],
                if (!kHideOfferCouponUi && !_isWholesaler) ...[
                  const SizedBox(height: 20),
                  _buildOfferSection(),
                ],
                // Launching soon; hidden when there are none.
                if (_comingSoonProducts.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildProductsSection(
                    l10n.homeComingSoonSection,
                    false,
                    items: _comingSoonProducts,
                    subtitle: l10n.homeComingSoonSubtitle,
                    onSeeAll: () => context.push('/coming-soon'),
                  ),
                ],
                const SizedBox(height: 28),
                _buildProductsSection(
                  _isWholesaler
                      ? l10n.homePopularProductsDealer
                      : l10n.homePopularProductsCustomer,
                  true,
                  grid: true,
                ),
                const SizedBox(height: 28),
                _buildBrandsSection(),
                const SizedBox(height: 28),
                _buildHotDealsBand(),
                if (_promoBanners.isNotEmpty && !_isWholesaler) ...[
                  const SizedBox(height: 12),
                  _buildPromoBannerCarousel(),
                ],
                const SizedBox(height: 28),
                _buildTrustRow(),
                if (!_isWholesaler) ...[
                  const SizedBox(height: 28),
                  _buildReviewSection(),
                ],
                // Room for the floating cart bar and nav.
                SizedBox(height: 96 + _navOverlap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hot deals on a warm band, so the page changes pace halfway down.
  Widget _buildHotDealsBand() {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accentSoft, AppColors.backgroundLight],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: _buildProductsSection(
          _isWholesaler ? l10n.homeHotDealsDealer : l10n.homeHotDealsCustomer,
          false,
        ),
      ),
    );
  }

  /// A few plain facts about the shop (replaces the scrolling marquee).
  Widget _buildTrustRow() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HomeTrustCard(
        title: l10n.homeWhyBuyTitle,
        facts: [
          (HugeIcons.strokeRoundedCalendar03, l10n.homeTrustTrustedByDealers),
          (HugeIcons.strokeRoundedInvoice01, l10n.homeTrustGstInvoice),
          (
            HugeIcons.strokeRoundedCheckmarkBadge01,
            l10n.homeTrustGenuineBrands,
          ),
          (HugeIcons.strokeRoundedCall, l10n.homeTrustCallUs),
        ],
      ),
    );
  }

  /// The search bar's look, shared by Home and the Search tab.
  BoxDecoration get _searchBarDecoration => BoxDecoration(
    color: AppColors.surfaceLight,
    // Concentric with the Home header's bottom corners.
    borderRadius: BorderRadius.circular(HomeHeroHeaderDelegate.searchRadius),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryDeep.withValues(alpha: 0.18),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// The filter button at the end of the search bar.
  Widget _searchFilterButton() {
    return Container(
      width: 40,
      height: 40,
      // Inset 6 from the bar's edge, so its radius is 6 less.
      decoration: ShapeDecoration(
        color: AppColors.primarySoft,
        shape: AppShapes.squircle(HomeHeroHeaderDelegate.searchRadius - 6),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedFilterHorizontal,
          size: 20,
          color: _searchScope == _SearchScope.product
              ? AppColors.primaryDeep
              : AppColors.primary,
        ),
      ),
    );
  }

  Rect? _globalRectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Opens the Search tab from Home's search bar: the bar glides into the
  /// Search tab's field while the rest of that page fades in, then the
  /// keyboard opens.
  void _openSearchFromHome() {
    void focusSearch() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }

    if (_searchBarFlying) return;
    final from = _globalRectOf(_homeSearchBarKey);
    // The Search tab is laid out even while hidden, so its field has a place.
    final to = _globalRectOf(_searchFieldKey);
    final overlay = Overlay.maybeOf(context);
    if (from == null ||
        to == null ||
        overlay == null ||
        AppMotion.reduced(context)) {
      setState(() => _selectedNavIndex = 1);
      focusSearch();
      return;
    }

    final rect = RectTween(begin: from, end: to);
    final entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _searchFlightCurve,
        // The overlay sits outside the page's Material, which the bar's
        // ink buttons need.
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: _buildHomeSearchBar(keyed: false),
          ),
        ),
        builder: (_, child) => Positioned.fromRect(
          rect: rect.evaluate(_searchFlightCurve)!,
          child: child!,
        ),
      ),
    );
    _searchFlightEntry = entry;
    setState(() {
      _selectedNavIndex = 1;
      _searchBarFlying = true;
    });
    overlay.insert(entry);
    _searchFlight.forward(from: 0).whenCompleteOrCancel(() {
      entry.remove();
      if (_searchFlightEntry == entry) _searchFlightEntry = null;
      if (!mounted) return;
      setState(() => _searchBarFlying = false);
      focusSearch();
    });
  }

  Widget _buildHomeSearchBar({bool keyed = true}) {
    return DecoratedBox(
      key: keyed ? _homeSearchBarKey : null,
      decoration: _searchBarDecoration,
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: _openSearchFromHome,
              scale: 0.99,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(HomeHeroHeaderDelegate.searchRadius),
              ),
              semanticLabel: context.l10n.homeSearchHint,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.homeSearchHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: _buildSearchScopeMenu(
              openSearch: true,
              child: _searchFilterButton(),
            ),
          ),
        ],
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
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                context.l10n.homeViewDeals,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
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
              baseColor: AppColors.gray200,
              highlightColor: AppColors.gray50,
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
                  AppColors.primary,
                  AppColors.success,
                  AppColors.warning,
                  AppColors.secondary,
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
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: AppShapes.squircle(4),
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
                color: AppColors.backgroundLight,
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
                color: AppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
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
        backgroundColor: AppColors.success,
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
  Widget _buildCategorySkeleton(double tileWidth, double railHeight) {
    return SkeletonShimmer(
      key: const ValueKey('categories-loading'),
      child: SizedBox(
        height: railHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => SizedBox(
            width: tileWidth,
            child: const Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Skeleton(
                    height: double.infinity,
                    radius: AppRadius.lg,
                  ),
                ),
                SizedBox(height: 8),
                Skeleton(width: 52, height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Category shortcuts as a sideways rail: the first categories, then an
  /// "All" tile at the end.
  Widget _buildCategorySection() {
    final l10n = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final tileWidth = screenWidth >= 600 ? 100.0 : 84.0;
    // Square art plus up to two lines of name, at the current text size.
    final railHeight = homeCategoryRailHeight(
      tileWidth,
      textScale: homeTextScale(context),
      hindi: context.isHindi,
    );

    final categories = _categoryData.isNotEmpty ? _categoryData : [];
    if (categories.isEmpty && !_isLoadingCategories) {
      return const SizedBox.shrink();
    }
    final shown = categories.take(15).toList();

    void openAll() => setState(() {
      _categoryNavigationRequest++;
      _requestedCategoryId = null;
      _requestedCategoryName = null;
      _requestedCategoryBrandId = null;
      _selectedNavIndex = 2;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: l10n.homeShopByCategory,
          actionLabel: l10n.commonSeeAll,
          onAction: openAll,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.base),
          child: _isLoadingCategories
              ? _buildCategorySkeleton(tileWidth, railHeight)
              : SizedBox(
                  key: const ValueKey('categories'),
                  height: railHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: shown.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final Widget tile;
                      if (index == shown.length) {
                        tile = HomeCategoryTile(
                          label: l10n.homeAllCategoriesTile,
                          isAll: true,
                          onTap: openAll,
                        );
                      } else {
                        final cat = shown[index] as Map<String, dynamic>;
                        tile = HomeCategoryTile(
                          label: _getDisplayCategoryName(cat),
                          imageUrl: cat['image']?.toString(),
                          blurHash: cat['blurHash']?.toString(),
                          onTap: () {
                            final name = cat['name']?.toString() ?? '';
                            setState(() {
                              _categoryNavigationRequest++;
                              _requestedCategoryId =
                                  cat['id']?.toString() ?? '';
                              _requestedCategoryName = name;
                              _requestedCategoryBrandId =
                                  cat['brandId']?.toString() ?? '';
                              _selectedNavIndex = 2;
                            });
                          },
                        );
                      }
                      return SizedBox(width: tileWidth, child: tile);
                    },
                  ),
                ),
        ),
      ],
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
      final searchableText = latinDigits(
        [
          category['name'],
          category['nameHindi'],
          category['queryName'],
          category['brandName'],
        ].whereType<Object>().join(' '),
      ).toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  Widget _buildScopedEmptyState(String message) {
    return EmptyState(
      icon: HugeIcons.strokeRoundedSearchRemove,
      tone: ChipTone.neutral,
      title: message,
      message: context.l10n.homeTryDifferentSearch,
    );
  }

  Widget _buildBrandSearchResults() {
    if (_isLoadingBrands) return _buildSearchSkeleton();
    final brands = _filteredSearchBrands;
    if (brands.isEmpty) {
      return _buildScopedEmptyState(context.l10n.homeNoBrandsFound);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 110 + _navOverlap),
      itemCount: brands.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final brand = brands[index];
        final id = brand['id']?.toString() ?? '';
        final name = brand['name']?.toString() ?? '';
        final logo = ApiConfig.normalizeMediaUrl(
          brand['logo']?.toString() ?? '',
        );
        return Material(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: id.isEmpty
                ? null
                : () => context.push(
                    '/brand/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(name)}',
                  ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: logo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: logo,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => const HugeIcon(
                                icon: HugeIcons.strokeRoundedStore01,
                                size: 22,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        : const HugeIcon(
                            icon: HugeIcons.strokeRoundedStore01,
                            size: 22,
                            color: AppColors.textTertiary,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: AppFonts.jakarta(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: AppColors.textTertiary,
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
    if (_isLoadingCategories) return _buildSearchSkeleton();
    final categories = _filteredSearchCategories;
    if (categories.isEmpty) {
      return _buildScopedEmptyState(context.l10n.homeNoCategoriesFound);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 110 + _navOverlap),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = categories[index];
        final name = category['name']?.toString() ?? '';
        final displayName = _getDisplayCategoryName(category);
        final brandName = category['brandName']?.toString() ?? '';
        return Material(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: () => setState(() {
              _categoryNavigationRequest++;
              _requestedCategoryId = category['id']?.toString() ?? '';
              _requestedCategoryName = name;
              _requestedCategoryBrandId = category['brandId']?.toString() ?? '';
              _selectedNavIndex = 2;
              _searchFocusNode.unfocus();
            }),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: (category['image']?.toString() ?? '').isNotEmpty
                        ? AppImage(
                            imageUrl: category['image'].toString(),
                            category: name,
                            name: name,
                            fit: BoxFit.contain,
                          )
                        : const HugeIcon(
                            icon: HugeIcons.strokeRoundedDashboardSquare01,
                            size: 22,
                            color: AppColors.textTertiary,
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (brandName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            brandName,
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Name of the category/brand the product search is filtered to, if any.
  String? get _activeSearchFilterLabel {
    final categoryId = _selectedFilterCategoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      for (final category in [..._searchCategoryData, ..._categoryData]) {
        if (category['id']?.toString() == categoryId) {
          return _getDisplayCategoryName(category);
        }
      }
    }
    final brandId = _selectedFilterBrandId;
    if (brandId != null && brandId.isNotEmpty) {
      for (final brand in _brands) {
        if (brand['id']?.toString() == brandId) {
          return brand['name']?.toString();
        }
      }
    }
    return null;
  }

  /// Removes the category/brand filter and searches the typed text again.
  void _clearSearchFilter() {
    _searchDebounce?.cancel();
    _invalidateSearchRequests();
    setState(() {
      _selectedFilterCategoryId = null;
      _selectedFilterBrandId = null;
      _searchResults = [];
      _isSearching = false;
      _isLoadingMoreSearch = false;
      _searchHasNext = false;
      _searchError = null;
    });
    if (_searchQuery.trim().isNotEmpty) _searchProducts(_searchQuery);
  }

  /// The same bar as on Home, with the real text field inside. Hidden while
  /// Home's bar glides into its place.
  Widget _buildSearchField() {
    final l10n = context.l10n;
    return Opacity(
      opacity: _searchBarFlying ? 0 : 1,
      child: Container(
        key: _searchFieldKey,
        height: HomeHeroHeaderDelegate.searchHeight,
        decoration: _searchBarDecoration,
        child: Row(
          children: [
            const SizedBox(width: 14),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _handleSearchTextChanged,
                onSubmitted: _submitSearch,
                textInputAction: TextInputAction.search,
                style: AppFonts.jakarta(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.homeSearchHint,
                  hintStyle: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.fast),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const ValueKey('clear'),
                      tooltip: l10n.commonClear,
                      onPressed: _clearSearch,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : const SizedBox(key: ValueKey('none'), width: 4),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: _buildSearchScopeMenu(child: _searchFilterButton()),
            ),
          ],
        ),
      ),
    );
  }

  /// Chips that show what the search is limited to, each with an ×.
  Widget _buildActiveSearchChips() {
    final l10n = context.l10n;
    final filterLabel = _searchScope == _SearchScope.product
        ? _activeSearchFilterLabel
        : null;
    final scopeLabel = switch (_searchScope) {
      _SearchScope.brand => l10n.homeSearchScopeBrand,
      _SearchScope.category => l10n.homeSearchScopeCategory,
      _SearchScope.product => null,
    };
    final chips = <Widget>[
      if (scopeLabel != null)
        InputChip(
          label: Text(scopeLabel),
          selected: true,
          showCheckmark: false,
          onDeleted: () => _selectSearchScope(_SearchScope.product),
          deleteButtonTooltipMessage: l10n.searchRemoveFilter,
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
        ),
      if (filterLabel != null)
        InputChip(
          label: Text(filterLabel),
          selected: true,
          showCheckmark: false,
          onDeleted: _clearSearchFilter,
          deleteButtonTooltipMessage: l10n.searchRemoveFilter,
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
        ),
    ];
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.base),
      curve: AppMotion.standard,
      alignment: Alignment.topLeft,
      child: chips.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Wrap(spacing: 8, runSpacing: 8, children: chips),
            ),
    );
  }

  Widget _buildSearchSkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const Row(
          children: [
            Skeleton(width: 84, height: 84, radius: AppRadius.md),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 13),
                  SizedBox(height: 8),
                  Skeleton(width: 120, height: 11),
                  SizedBox(height: 14),
                  Skeleton(width: 70, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsBody() {
    final l10n = context.l10n;
    if (_searchScope == _SearchScope.brand) return _buildBrandSearchResults();
    if (_searchScope == _SearchScope.category) {
      return _buildCategorySearchResults();
    }
    if (_isSearching && _searchResults.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('search-loading'),
        child: _buildSearchSkeleton(),
      );
    }
    if (!_hasActiveProductSearch) {
      return KeyedSubtree(
        key: const ValueKey('search-idle'),
        child: _buildSearchIdle(),
      );
    }
    if (_searchError != null && _searchResults.isEmpty) {
      return EmptyState(
        key: const ValueKey('search-error'),
        icon: HugeIcons.strokeRoundedWifiError01,
        tone: ChipTone.error,
        title: l10n.homeSearchLoadFailed,
        actionLabel: l10n.commonRetry,
        onAction: () => _searchProducts(_searchController.text),
      );
    }
    if (_searchResults.isEmpty) {
      return EmptyState(
        key: const ValueKey('search-empty'),
        icon: HugeIcons.strokeRoundedSearchRemove,
        tone: ChipTone.neutral,
        title: l10n.homeSearchNoResults,
        message: _searchQuery.trim().isEmpty
            ? l10n.homeSearchTryChangingFilters
            : l10n.homeTryDifferentSearch,
      );
    }
    final results = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 320) {
          _loadMoreSearchResults();
        }
        return false;
      },
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 110 + _navOverlap),
        itemCount: _searchResults.length + (_isLoadingMoreSearch ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }
          return StaggeredRevealItem(
            index: index,
            child: _buildSuggestionCard(_searchResults[index]),
          );
        },
      ),
    );
    // Same padding and gaps as the skeleton, so each row lands where its
    // skeleton row was, fading in one after another.
    return StaggeredReveal(
      key: const ValueKey('search-results'),
      child: results,
    );
  }

  Widget _buildSearchIdle() {
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

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(top: 16, bottom: 110 + _navOverlap),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          SectionHeader(
            title: l10n.homeRecentSearches,
            actionLabel: l10n.homeClearAll,
            onAction: () {
              setState(() => _recentSearches = []);
              RecentSearchStore.save(const []);
            },
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _recentSearches.length; i++)
                  InputChip(
                    avatar: const HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    label: Text(_recentSearches[i]),
                    onPressed: () {
                      final query = _recentSearches[i];
                      _searchController.text = query;
                      _handleSearchTextChanged(query);
                    },
                    deleteButtonTooltipMessage: l10n.commonRemove,
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () {
                      setState(() => _recentSearches.removeAt(i));
                      RecentSearchStore.save(_recentSearches);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (catalogCategories.isNotEmpty) ...[
          SectionHeader(title: l10n.homeBrowseCategories),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: catalogCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = catalogCategories[index];
                return ActionChip(
                  label: Text(_getDisplayCategoryName(category)),
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _invalidateSearchRequests();
                    _searchController.clear();
                    setState(() {
                      _searchScope = _SearchScope.product;
                      _searchQuery = '';
                      _selectedFilterCategoryId = category['id']?.toString();
                      _selectedFilterBrandId = category['brandId']?.toString();
                    });
                    _searchProducts('');
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        SectionHeader(title: suggestionTitle),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final product in suggestionProducts.take(5)) ...[
                _buildSuggestionCard(product),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeTransition(
          opacity: _searchPageFade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              l10n.homeExploreTitle,
              style: AppFonts.jakarta(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSearchField(),
        ),
        FadeTransition(
          opacity: _searchPageFade,
          child: _buildActiveSearchChips(),
        ),
        Expanded(
          child: FadeTransition(
            opacity: _searchPageFade,
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.base),
              switchInCurve: AppMotion.standard,
              child: _buildSearchResultsBody(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> product) {
    final l10n = context.l10n;
    final heroTag = 'search-product-${product['id']}';
    final price = (product['price'] as num?) ?? 0;
    final originalPrice = product['originalPrice'];
    final mrp = originalPrice is num && originalPrice > 0
        ? originalPrice
        : null;
    final rating = product['rating'];
    final pack = packInfoOf(product);
    final isMeter = isMeterProduct(product);
    final brand = (product['brand'] ?? '').toString();

    // Live purchase counter shown under the name (kept as designed).
    int soldCount = 0;
    final pMin = (product['purchaseCountMin'] as num?)?.toInt() ?? 0;
    final pMax = (product['purchaseCountMax'] as num?)?.toInt() ?? 0;
    if (pMin > 0 || pMax > 0) {
      final effectiveMax = pMax > pMin ? pMax : pMin;
      final dayOfYear = DateTime.now()
          .difference(DateTime(DateTime.now().year))
          .inDays;
      final seed = product['id'].toString().hashCode.abs() + dayOfYear;
      final range = effectiveMax - pMin;
      soldCount = range > 0 ? pMin + (seed % (range + 1)) : pMin;
    }

    return Pressable(
      onTap: () => context.push(
        '/product/${product['id']}',
        extra: {
          'heroTag': heroTag,
          'heroImage': product['image']?.toString(),
          'heroBlurHash': product['blurHash']?.toString(),
        },
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      semanticLabel: _getDisplayName(product),
      child: Row(
        children: [
          Hero(
            tag: heroTag,
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              // Rounded corners on the photo itself, inside the grey tile.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: (product['image']?.toString() ?? '').isNotEmpty
                    ? AppImage(
                        imageUrl: product['image'].toString(),
                        blurHash: product['blurHash']?.toString(),
                        category: product['category']?.toString() ?? '',
                        name: product['name']?.toString() ?? '',
                        width: 84,
                        height: 84,
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
                Text(
                  _getDisplayName(product),
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // One detail line: brand, rating and the sold-today count.
                Row(
                  children: [
                    if (brand.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          brand.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (rating != null || soldCount > 0)
                        const SizedBox(width: 8),
                    ],
                    if (rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.star,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$rating',
                        style: AppFonts.jakarta(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (soldCount > 0) const SizedBox(width: 8),
                    ],
                    if (soldCount > 0)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedFire,
                              size: 13,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                l10n.homeSoldIn24Hrs('$soldCount'),
                                style: AppFonts.jakarta(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (isComingSoonProduct(product)) ...[
                  const SizedBox(height: 6),
                  const ComingSoonBadge(compact: true),
                ],
                const SizedBox(height: 8),
                if (isPriceHidden(product))
                  Text(
                    l10n.comingSoonPrice,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: comingSoonColor,
                    ),
                  )
                else
                  PriceView(
                    price: price,
                    mrp: mrp,
                    size: 15,
                    unit: pack.isPack || isMeter
                        ? (isMeter ? l10n.uiPerMeter : l10n.uiPerPiece)
                        : null,
                    offLabel: (percent) => l10n.commonPercentOff('$percent'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCart() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.cartClearTitle,
      message: l10n.cartClearMessage,
      confirmLabel: l10n.cartClearConfirm,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      icon: HugeIcons.strokeRoundedDelete02,
    );
    if (!confirmed || !mounted) return;
    await ref.read(cartProvider.notifier).clearCart();
    await _autoReapplyCouponIfNeeded();
  }

  /// Removes a cart line and offers Undo, which puts the same line back.
  Future<void> _removeCartLineWithUndo(CartItem item) async {
    final l10n = context.l10n;
    final notifier = ref.read(cartProvider.notifier);
    await _removeCartItemAndRefreshCoupon(item.productId);
    if (!mounted) return;
    showAppSnack(
      context,
      l10n.uiItemRemoved(pickLocalizedName(context, item.name, item.nameHindi)),
      actionLabel: l10n.uiUndo,
      duration: const Duration(seconds: 5),
      onAction: () async {
        final error = await restoreCartItem(notifier, item);
        if (!mounted) return;
        if (error != null) {
          showAppSnack(
            context,
            apiErrorText(context, error),
            tone: SnackTone.error,
          );
        } else {
          await _autoReapplyCouponIfNeeded();
        }
      },
    );
  }

  Widget _buildCartContent() {
    if (ref.watch(guestModeProvider)) {
      return _buildCustomerPreviewCart();
    }
    // The cart is watched in here, so a cart change rebuilds this tab only.
    return Consumer(
      builder: (context, ref, _) => _buildCartBody(ref.watch(cartProvider)),
    );
  }

  Widget _buildCartBody(CartState cart) {
    final l10n = context.l10n;
    final hasActiveCoupon = _hasActiveAppliedCoupon(cart);
    final isCouponLocked =
        _appliedCouponCode != null &&
        _normalizedCouponInput == _appliedCouponCode;
    final couponDiscount = hasActiveCoupon ? _appliedCouponDiscount : 0.0;
    // Delivery is set by DemoMart when the order is confirmed.
    final payableTotal = math.max(cart.subtotal - couponDiscount, 0).toDouble();
    final hasAddress = _addr1Ctrl.text.trim().isNotEmpty;
    final addressText = [
      _addr1Ctrl.text.trim(),
      _cityCtrl.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
          child: Row(
            children: [
              Text(
                l10n.homeMyCart,
                style: AppFonts.jakarta(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.base),
                child: cart.items.isEmpty
                    ? const SizedBox.shrink()
                    : StatusChip(
                        key: ValueKey(cart.displayItemCount(_isWholesaler)),
                        label: l10n.commonItemsCount(
                          cart.displayItemCount(_isWholesaler),
                        ),
                        tone: ChipTone.brand,
                        dense: true,
                      ),
              ),
              const Spacer(),
              if (cart.items.isNotEmpty)
                HeaderIconButton(
                  icon: HugeIcons.strokeRoundedDelete02,
                  tooltip: l10n.cartClearTitle,
                  color: AppColors.textSecondary,
                  onPressed: _confirmClearCart,
                ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.base),
            child: cart.items.isEmpty
                ? EmptyState(
                    key: const ValueKey('cart-empty'),
                    icon: HugeIcons.strokeRoundedShoppingCart01,
                    title: l10n.homeCartEmptyTitle,
                    message: l10n.homeCartEmptySubtitle,
                    actionLabel: l10n.homeBrowseProducts,
                    onAction: () => _selectNavIndex(0),
                  )
                : ListView(
                    key: const ValueKey('cart-lines'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      CartAddressCard(
                        onTap: _openCartAddressBottomSheet,
                        name: _nameCtrl.text,
                        phone: _phoneCtrl.text,
                        address: hasAddress ? addressText : null,
                        emptyLabel: l10n.homeAddShippingDetails,
                      ),
                      const SizedBox(height: 12),
                      for (final item in cart.items)
                        Padding(
                          key: ValueKey(item.cartItemKey),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: Key('dismiss-${item.cartItemKey}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _removeCartLineWithUndo(item),
                            background: Container(
                              decoration: BoxDecoration(
                                color: AppColors.errorSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedDelete02,
                                color: AppColors.error,
                                size: 22,
                              ),
                            ),
                            child: CartLineCard(
                              item: item,
                              isWholesaler: _isWholesaler,
                              onQuantityChanged: (quantity) =>
                                  _updateCartQtyAndRefreshCoupon(
                                    item.productId,
                                    quantity,
                                  ),
                              onRemove: () => _removeCartLineWithUndo(item),
                              onLimitReached: (message) => showAppSnack(
                                context,
                                message,
                                tone: SnackTone.error,
                              ),
                            ),
                          ),
                        ),
                      if (!kHideOfferCouponUi) ...[
                        const SizedBox(height: 2),
                        CartCouponField(
                          controller: _couponCtrl,
                          locked: isCouponLocked,
                          applying: _isApplyingCoupon,
                          labelText: l10n.homeCouponFieldLabel,
                          hintText: l10n.homeCouponFieldHint,
                          onApply: _isApplyingCoupon || isCouponLocked
                              ? null
                              : _applyCouponPreview,
                          onChanged: (_) {
                            if (_appliedCouponCode != null &&
                                _normalizedCouponInput != _appliedCouponCode) {
                              setState(() => _clearAppliedCouponPreview());
                            }
                          },
                          onChangeCode: () => setState(
                            () => _clearAppliedCouponPreview(clearInput: true),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      CartBillCard(
                        itemTotal: cart.subtotal,
                        total: payableTotal,
                        discount: couponDiscount,
                        couponCode: hasActiveCoupon ? _appliedCouponCode : null,
                        savings: cartMrpSavings(cart.items) + couponDiscount,
                        itemCount: cart.displayItemCount(_isWholesaler),
                      ),
                    ],
                  ),
          ),
        ),
        if (cart.items.isNotEmpty)
          CartCheckoutBar(
            total: payableTotal,
            totalLabel: hasActiveCoupon ? l10n.homePayableTotal : null,
            loading: _isCheckingOut,
            label: _isWholesaler
                ? (_isCheckingOut
                      ? l10n.cartSendingRequirement
                      : l10n.productSendRequirement)
                : (_isCheckingOut
                      ? l10n.homeCreatingOrder
                      : l10n.homeProceedToCheckout),
            icon: _isWholesaler ? HugeIcons.strokeRoundedSent : null,
            trailingIcon: _isWholesaler
                ? null
                : HugeIcons.strokeRoundedArrowRight01,
            onPressed: _isCheckingOut
                ? null
                : (_isWholesaler ? _sendCartAsRequirement : _proceedToCheckout),
          ),
        // The checkout bar's own bottom safe area already covers the
        // floating nav (the body's bottom padding includes it), so its white
        // panel runs behind the nav to the bottom edge.
      ],
    );
  }

  Widget _buildCustomerPreviewCart() {
    return EmptyState(
      icon: HugeIcons.strokeRoundedShoppingCart01,
      title: context.l10n.homePreviewCartTitle,
      message: context.l10n.homePreviewCartMessage,
    );
  }

  int _negotiationTab = 0;
  // Active / Completed lists side by side: swipe or tap the switch.
  final PageController _dealPages = PageController();
  bool _isNegotiationsLoading = false;
  bool _isFetchingNegotiations = false;
  List<Map<String, dynamic>> _negotiations = [];

  void _selectNavIndex(int index) {
    if (_selectedNavIndex != index) {
      setState(() => _selectedNavIndex = index);
      // Profile shows the latest order; fetch it fresh on each visit.
      if (index == 4) ref.invalidate(recentOrdersProvider);
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

  List<Map<String, dynamic>> _negotiationsForTab(int tab) {
    // Active until the order is paid (or the deal is declined/expired).
    final completed = tab == 1;
    return _negotiations
        .where((n) => DealDeskPresentation.isCompleted(n) == completed)
        .toList();
  }

  Future<void> _openDealDetail(String negotiationId) async {
    if (negotiationId.isEmpty) return;
    final result = await context.push('/negotiation-detail/$negotiationId');
    if (result == true) _fetchNegotiations();
  }

  /// Slides the Deal Desk lists to [tab] (the switch follows them).
  void _showDealTab(int tab) {
    if (!_dealPages.hasClients) {
      setState(() => _negotiationTab = tab);
      return;
    }
    final duration = AppMotion.of(context, AppMotion.slow);
    if (duration == Duration.zero) {
      _dealPages.jumpToPage(tab);
    } else {
      _dealPages.animateToPage(
        tab,
        duration: duration,
        curve: AppMotion.standard,
      );
    }
  }

  Widget _buildNegotiationsContent() {
    final l10n = context.l10n;
    // Active until the order is paid (or the deal is declined/expired).
    final completedCount = _negotiations
        .where(DealDeskPresentation.isCompleted)
        .length;
    final activeCount = _negotiations.length - completedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(
            l10n.homeDealDeskTitle,
            style: AppFonts.jakarta(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DealSegmentedControl(
            labels: [l10n.homeDealTabActive, l10n.homeDealTabCompleted],
            selectedIndex: _negotiationTab,
            counts: [activeCount, completedCount],
            controller: _dealPages,
            onChanged: _showDealTab,
          ),
        ),
        Expanded(
          child: PageView(
            controller: _dealPages,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _negotiationTab = index);
            },
            children: [_buildDealPage(0), _buildDealPage(1)],
          ),
        ),
      ],
    );
  }

  /// One Deal Desk list: 0 = active (needs-reply first, under a count line),
  /// 1 = completed.
  Widget _buildDealPage(int tab) {
    final l10n = context.l10n;
    final deals = DealDeskPresentation.sortNeedsReplyFirst(
      _negotiationsForTab(tab),
    );
    final needReply = tab == 0 ? _dealsAwaitingReply : 0;

    Widget body;
    if (_isNegotiationsLoading && _negotiations.isEmpty) {
      body = ListView.separated(
        key: const ValueKey('deals-loading'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const DealInboxSkeleton(),
      );
    } else if (deals.isEmpty) {
      body = RefreshIndicator(
        key: const ValueKey('deals-empty'),
        onRefresh: _fetchNegotiations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 40),
            EmptyState(
              icon: HugeIcons.strokeRoundedAgreement02,
              title: tab == 0
                  ? l10n.homeDealEmptyActive
                  : l10n.homeDealEmptyCompleted,
              message: l10n.homeDealEmptyHint,
            ),
          ],
        ),
      );
    } else {
      final header = needReply > 0 ? 1 : 0;
      // Products sent together sit under one requirement header.
      final entries = dealDeskEntries(
        context,
        deals,
        (deal) {
          final id = (deal['id'] ?? deal['_id'] ?? '').toString();
          return DealInboxTile(
            negotiation: deal,
            onTap: () => _openDealDetail(id),
            onAction: (_) => _openDealDetail(id),
          );
        },
        color: AppColors.primaryDeep,
        gap: 10,
      );
      body = RefreshIndicator(
        key: const ValueKey('deals-list'),
        onRefresh: _fetchNegotiations,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 100 + _navOverlap),
          itemCount: entries.length + header,
          itemBuilder: (context, index) {
            if (index < header) {
              return Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 10),
                child: Row(
                  children: [
                    const DealNeedsReplyDot(size: 8),
                    const SizedBox(width: 8),
                    Text(
                      l10n.dealNeedsReplyCount(needReply),
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return entries[index - header];
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.base),
      child: body,
    );
  }

  /// Account badge: verified wholesaler, pending/rejected application, etc.
  (String, ChipTone, IconData) _accountStatus(UserModel? user) {
    final l10n = context.l10n;
    final businessInfo = user?.businessInfo;
    if (user?.isWholesaler == true && businessInfo?.verified == true) {
      return (
        l10n.profileStatusVerifiedWholesaler,
        ChipTone.success,
        HugeIcons.strokeRoundedCheckmarkCircle01,
      );
    }
    if (businessInfo?.status == 'pending') {
      return (
        l10n.profileStatusApplicationPending,
        ChipTone.warning,
        HugeIcons.strokeRoundedTime02,
      );
    }
    if (businessInfo?.status == 'rejected') {
      return (
        l10n.profileStatusApplicationRejected,
        ChipTone.error,
        HugeIcons.strokeRoundedAlert02,
      );
    }
    if (user?.isWholesaler == true) {
      return (
        l10n.profileStatusVerificationRequired,
        ChipTone.warning,
        HugeIcons.strokeRoundedAlert02,
      );
    }
    return (
      l10n.profileStatusCustomer,
      ChipTone.brand,
      HugeIcons.strokeRoundedUser,
    );
  }

  Future<void> _confirmLogout() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.homeLogoutConfirmTitle,
      message: l10n.homeLogoutConfirmMessage,
      confirmLabel: l10n.commonLogout,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      icon: HugeIcons.strokeRoundedLogout02,
    );
    if (!confirmed || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
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
    final profileMaxWidth = isTablet ? 720.0 : double.infinity;
    final wishlistCount = ref.watch(
      wishlistProvider.select((w) => w.items.length),
    );
    final ordersSnapshot =
        ref.watch(recentOrdersProvider).value ?? OrdersSnapshot.empty;
    final activeOrders = profileActiveOrders(ordersSnapshot.orders);
    final (statusLabel, statusTone, statusIcon) = _accountStatus(user);
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : l10n.homeGuestUser;
    final isVerifiedWholesaler =
        user?.isWholesaler == true && user?.businessInfo?.verified == true;

    void openOrders() => context.push('/previous-orders');

    final stats = isGuest
        ? const <ProfileStat>[]
        : [
            ProfileStat(
              value: ordersSnapshot.total,
              label: l10n.profileStatOrders,
              onTap: openOrders,
            ),
            if (_isWholesaler)
              ProfileStat(
                value: _negotiations
                    .where(DealDeskPresentation.isActive)
                    .length,
                label: l10n.profileStatDeals,
                onTap: () => _selectNavIndex(3),
              ),
            ProfileStat(
              value: wishlistCount,
              label: _isWholesaler
                  ? l10n.homeWishlistDealer
                  : l10n.homeWishlistCustomer,
              onTap: () => context.push('/wishlist'),
            ),
            if (!_isWholesaler)
              ProfileStat(
                value: _savedShippingAddresses.length,
                label: l10n.homeProfileAddresses,
                onTap: _openProfileAddresses,
              ),
          ];

    // Latest order still on its way; Track / View status follows the same
    // rules as the orders screen.
    Widget? activeOrderCard;
    if (activeOrders.isNotEmpty) {
      final order = activeOrders.first;
      final stage = CustomerOrderPresentation.stage(order);
      final orderId = order['id']?.toString() ?? '';
      final trackingNumber = order['trackingNumber']?.toString() ?? '';
      final hasAcceptance = CustomerOrderPresentation.acceptanceStatus(
        order,
      ).isNotEmpty;
      String? trackLabel;
      if (orderId.isNotEmpty) {
        if (trackingNumber.isNotEmpty) {
          trackLabel = l10n.ordersTrackOrder;
        } else if (hasAcceptance ||
            stage == 'payment_verified' ||
            stage == 'processing') {
          trackLabel = l10n.ordersViewStatus;
        }
      }
      activeOrderCard = ProfileActiveOrderCard(
        order: order,
        moreInProgress: activeOrders.length - 1,
        onOpen: openOrders,
        trackLabel: trackLabel,
        onTrack: trackLabel == null
            ? null
            : () => context.push('/tracking/$orderId'),
      );
    }

    // Wholesaler pitch for everyone who isn't a verified wholesaler yet.
    Widget? upgradeCard;
    if (!isVerifiedWholesaler) {
      final status = user?.businessInfo?.status;
      final (title, subtitle, cta) = status == 'pending'
          ? (
              l10n.profileWholesalerApplication,
              l10n.profileViewApplicationStatus,
              l10n.ordersViewStatus,
            )
          : user?.isWholesaler == true
          ? (
              l10n.profileCompleteWholesalerVerification,
              l10n.profileSubmitBusinessProof,
              l10n.profileUpgradeContinue,
            )
          : (
              l10n.homeProfileApplyWholesaler,
              status == 'rejected'
                  ? l10n.conversionRejectedNote
                  : l10n.homeProfileApplyWholesalerSubtitle,
              l10n.profileUpgradeCta,
            );
      upgradeCard = ProfileUpgradeCard(
        title: title,
        subtitle: subtitle,
        ctaLabel: cta,
        onTap: () => context.push('/convert-to-wholesaler'),
      );
    }

    final sections = <Widget>[
      ProfileIdentityCard(
        name: name,
        isGuest: isGuest,
        avatarUrl: user?.avatar,
        contactLine: isGuest
            ? l10n.homeSignInToSync
            : (user.phone?.trim().isNotEmpty == true
                  ? user.phone!.trim()
                  : user.email),
        businessName: _isWholesaler ? user?.businessInfo?.businessName : null,
        statusLabel: isGuest ? null : statusLabel,
        statusTone: statusTone,
        statusIcon: statusIcon,
        memberSince: profileMemberSinceText(context, user?.createdAt),
        onEdit: isGuest ? null : () => context.push('/edit-profile'),
        onLogin: () => context.push('/login'),
        stats: stats,
      ),
      if (activeOrderCard != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                l10n.profileYourOrder.toUpperCase(),
                style: AppText.eyebrow(),
              ),
            ),
            activeOrderCard,
          ],
        ),
      ?upgradeCard,
      SettingsGroup(
        title: l10n.profileSectionAccount,
        children: [
          SettingsTile(
            icon: HugeIcons.strokeRoundedLanguageSkill,
            title: context.isHindi
                ? l10n.languageTitle
                : '${l10n.languageTitle} / भाषा',
            trailing: Text(
              context.isHindi ? l10n.languageHindi : l10n.languageEnglish,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            onTap: () => showLanguagePicker(context, ref),
          ),
          SettingsTile(
            icon: HugeIcons.strokeRoundedLocation01,
            title: l10n.homeProfileAddresses,
            subtitle: l10n.profileAddressesSaved(
              _savedShippingAddresses.length,
            ),
            onTap: _openProfileAddresses,
          ),
          SettingsTile(
            icon: HugeIcons.strokeRoundedNotification02,
            title: l10n.homeNotificationsTitle,
            subtitle: l10n.profileNotificationsSubtitle,
            trailing: _unreadCount > 0
                ? ProfileCountPill(
                    count: _unreadCount,
                    semantic: l10n.profileUnreadCount(_unreadCount),
                  )
                : null,
            onTap: () =>
                context.push('/notifications', extra: {'bottomTab': 4})
                // Reading them there clears the badge.
                .then((_) {
                  if (mounted) _fetchNotificationCount();
                }),
          ),
          SettingsTile(
            icon: HugeIcons.strokeRoundedShield01,
            title: l10n.homeProfileAccountPrivacy,
            subtitle: l10n.profileAccountPrivacySubtitle,
            onTap: () => context.push(isGuest ? '/login' : '/account-privacy'),
          ),
          if (!kHideOfferCouponUi)
            SettingsTile(
              icon: HugeIcons.strokeRoundedTicket01,
              title: l10n.homeProfileMyCoupons,
              onTap: () => context.push('/my-coupons'),
            ),
        ],
      ),
      if (user?.isWholesaler == true)
        SettingsGroup(
          title: l10n.profileSectionWholesale,
          children: [
            SettingsTile(
              icon: HugeIcons.strokeRoundedView,
              title: l10n.homeProfileViewCustomerApp,
              subtitle: l10n.homeProfileViewCustomerAppSubtitle,
              onTap: () async {
                ref.read(guestModeProvider.notifier).enableGuestMode();
                try {
                  await context.push('/guest-app-preview');
                } finally {
                  await Future<void>.delayed(Duration.zero);
                  ref.read(guestModeProvider.notifier).disableGuestMode();
                }
              },
            ),
          ],
        ),
      SettingsGroup(
        title: l10n.profileSectionSupportLegal,
        children: [
          SettingsTile(
            icon: HugeIcons.strokeRoundedHelpCircle,
            title: l10n.homeProfileHelpSupport,
            subtitle: l10n.profileHelpSupportSubtitle,
            onTap: () => context.push('/help'),
          ),
          SettingsTile(
            icon: HugeIcons.strokeRoundedFile01,
            title: l10n.homeProfileLegalPolicies,
            subtitle: l10n.profileLegalSubtitle,
            onTap: _showLegalPoliciesSheet,
          ),
          SettingsTile(
            icon: HugeIcons.strokeRoundedInformationCircle,
            title: l10n.homeProfileAbout,
            onTap: () => context.push('/about'),
          ),
        ],
      ),
      // Logout only for signed-in users, and only after confirming.
      if (!isGuest)
        SettingsGroup(
          children: [
            SettingsTile(
              icon: HugeIcons.strokeRoundedLogout02,
              title: l10n.commonLogout,
              destructive: true,
              showChevron: false,
              onTap: _confirmLogout,
            ),
          ],
        ),
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => Future.wait([
        ref.refresh(recentOrdersProvider.future),
        _loadSavedShippingAddresses(),
      ]),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.only(bottom: 28 + _navOverlap),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: profileMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 4),
                  child: Row(
                    children: [
                      AppBackButton(
                        onPressed: () {
                          if (_selectedNavIndex != 0) _selectNavIndex(0);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.homeProfileTitle,
                          style: AppFonts.jakarta(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < sections.length; i++)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, i == 0 ? 10 : 20, 16, 0),
                    child: ProfileReveal(index: i, child: sections[i]),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: ProfileFooter(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfileAddresses() {
    context.push('/addresses').then((_) => _loadSavedShippingAddresses());
  }

  Widget _buildCustomerPreviewProfile() {
    return EmptyState(
      icon: HugeIcons.strokeRoundedUser,
      title: context.l10n.homePreviewGuestCustomer,
      message: context.l10n.homePreviewProfileMessage,
      actionLabel: context.l10n.homeExitCustomerPreview,
      onAction: () => context.pop(),
    );
  }

  Future<void> _showLegalPoliciesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    context.l10n.homeProfileLegalPolicies,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      SettingsGroup(
                        children: [
                          for (final policy in LegalPolicyCatalog.items)
                            SettingsTile(
                              icon: policy.icon,
                              title: policy.localizedTitle(context),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                context.push('/legal/${policy.id}');
                              },
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
      },
    );
  }

  /// Logo, name and the header actions, white on the teal header.
  Widget _buildHomeTopRow() {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
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
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${l10n.homeBrandFirstWord} ',
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: l10n.homeBrandSecondWord,
                      style: const TextStyle(color: AppColors.primaryGlow),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.homeBrandTagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.jakarta(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<Locale>(
          offset: const Offset(0, 48),
          tooltip: l10n.languageTitle,
          onSelected: (Locale value) {
            HapticFeedback.selectionClick();
            if (value.languageCode == ref.read(localeProvider).languageCode) {
              return;
            }
            // Waits for the menu to close so it isn't in the wave's snapshot.
            LanguageWave.run(
              context,
              () => ref.read(localeProvider.notifier).setLocale(value),
              settle: const Duration(milliseconds: 300),
            );
          },
          itemBuilder: (_) => [
            _buildLanguageItem(LocaleNotifier.english, l10n.languageEnglish),
            _buildLanguageItem(LocaleNotifier.hindi, l10n.languageHindi),
          ],
          // Round translucent language switch, sized like the bell next to
          // it. No backdrop blur: only the header's teal sits behind it.
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.base),
              child: Text(
                context.isHindi ? 'हि' : 'EN',
                key: ValueKey(context.isHindi),
                style: AppFonts.jakarta(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        HeaderIconButton(
          icon: HugeIcons.strokeRoundedNotification02,
          tooltip: l10n.notificationsTitle,
          badge: _unreadCount,
          onDark: true,
          onPressed: _showNotificationPopup,
        ),
        if (_isWholesaler) ...[
          const SizedBox(width: 6),
          HeaderIconButton(
            icon: HugeIcons.strokeRoundedUser,
            tooltip: l10n.homeNavProfile,
            onDark: true,
            onPressed: () => _selectNavIndex(4),
          ),
        ],
      ],
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
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 700;
    final bannerHeight = isTablet ? 260.0 : 188.0;
    const slideGap = EdgeInsets.symmetric(horizontal: 5);
    final radius = BorderRadius.circular(AppRadius.xl - 4);

    if (_isLoadingHeroBanners) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonShimmer(
          child: Skeleton(height: bannerHeight, radius: AppRadius.xl - 4),
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
          key: _heroCarouselKey,
          height: bannerHeight,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: _heroBanners.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              _currentCarouselIndex.value = index;
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
              const padding = slideGap;
              if ((mediaType == 'video_upload' || mediaType == 'youtube') &&
                  videoUrl.isNotEmpty) {
                final linkUrl = item['linkUrl']?.toString() ?? '';
                return Padding(
                  padding: padding,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentCarouselIndex,
                      builder: (context, current, _) => mediaType == 'youtube'
                          ? _HeroYoutubeSlide(
                              videoUrl: videoUrl,
                              posterUrl: (item['imageUrl'] ?? '').toString(),
                              linkUrl: linkUrl,
                              isActive: current == index,
                              onOpenLink: () => _handleBannerTap(linkUrl),
                              onVideoComplete: () => _goToNextHeroSlide(),
                            )
                          : _HeroVideoSlide(
                              videoUrl: videoUrl,
                              posterUrl: (item['imageUrl'] ?? '').toString(),
                              linkUrl: linkUrl,
                              isActive: current == index,
                              onOpenLink: () => _handleBannerTap(linkUrl),
                              onVideoComplete: () => _goToNextHeroSlide(),
                            ),
                    ),
                  ),
                );
              }
              final imageUrl = (item['imageUrl'] ?? '').toString();
              final hasImage = imageUrl.isNotEmpty;
              final linkUrl = item['linkUrl']?.toString() ?? '';
              final tag = (item['tag'] ?? '').toString().trim();
              final title = (item['title'] ?? '').toString().trim();
              final buttonText = (item['buttonText'] ?? '').toString().trim();
              return Padding(
                padding: padding,
                child: Pressable(
                  onTap: linkUrl.isEmpty
                      ? null
                      : () => _handleBannerTap(linkUrl),
                  borderRadius: radius,
                  scale: 0.985,
                  color: AppColors.primaryDeep,
                  semanticLabel: title.isEmpty ? null : title,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: AppMotion.slow,
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppColors.gray100),
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: AppColors.primaryDeep),
                        ),
                      if (hasImage && (title.isNotEmpty || tag.isNotEmpty))
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.75],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (tag.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  tag.toUpperCase(),
                                  style: AppFonts.jakarta(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (title.isNotEmpty || !hasImage)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: screenWidth * 0.62,
                                ),
                                child: Text(
                                  title.isEmpty
                                      ? l10n.homeBannerExploreProducts
                                      : title,
                                  style: AppFonts.jakarta(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.15,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (linkUrl.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      buttonText.isEmpty
                                          ? l10n.homeBannerShopNow
                                          : buttonText,
                                      style: AppFonts.jakarta(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryDeep,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _getBannerIcon(
                                      item['buttonIcon'],
                                      AppColors.primaryDeep,
                                      15,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        if (_heroBanners.length > 1) ...[
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
            valueListenable: _currentCarouselIndex,
            builder: (context, current, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _heroBanners.length,
                (index) => AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.base),
                  curve: AppMotion.standard,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: current == index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: current == index
                        ? AppColors.primary
                        : AppColors.gray300,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
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
    final size = screenWidth >= 600 ? 108.0 : 96.0;
    final rowHeight = size + 7 + 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.homeTopBrands,
          actionLabel: context.l10n.commonSeeAll,
          onAction: () => _selectNavIndex(2),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: rowHeight,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.base),
            child: _isLoadingBrands
                ? SkeletonShimmer(
                    key: const ValueKey('brands-loading'),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, _) => SizedBox(
                        width: size + 12,
                        child: Column(
                          children: [
                            Skeleton(
                              width: size,
                              height: size,
                              radius: AppRadius.xl,
                            ),
                            const SizedBox(height: 8),
                            const Skeleton(width: 48, height: 10),
                          ],
                        ),
                      ),
                    ),
                  )
                : _brands.isEmpty
                ? Center(
                    key: const ValueKey('brands-empty'),
                    child: Text(
                      context.l10n.homeNoBrandsAvailable,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('brands'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _brands.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final brand = _brands[index];
                      final brandName = brand['name']?.toString() ?? '';
                      return HomeBrandAvatar(
                        name: brandName,
                        logoUrl: brand['logo']?.toString(),
                        size: size,
                        onTap: () {
                          final id = brand['id']?.toString() ?? '';
                          if (id.isEmpty) return;
                          context.push(
                            '/brand/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(brandName)}',
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandInitial(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDeep,
          ),
        ),
      ),
    );
  }

  Widget _buildProductsSection(
    String title,
    bool isFeatured, {
    bool grid = false,
    // Another product list (e.g. Coming Soon) with its own subtitle and
    // "See all" destination.
    List<Map<String, dynamic>>? items,
    String? subtitle,
    VoidCallback? onSeeAll,
  }) {
    final sectionProducts =
        items ?? (isFeatured ? _featuredProducts : _hotProducts);
    final products = sectionProducts.take(12).toList();
    // Unique photo-flight tags when a product sits in two rows.
    final heroScope = isFeatured ? 'popular' : (items != null ? 'soon' : 'hot');
    final l10n = context.l10n;
    final sectionSubtitle =
        subtitle ??
        (_isWholesaler
            ? isFeatured
                  ? l10n.homePopularSubtitleDealer
                  : l10n.homeHotDealsSubtitleDealer
            : isFeatured
            ? l10n.homePopularSubtitleCustomer
            : l10n.homeHotDealsSubtitleCustomer);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth >= 600 ? 184.0 : 158.0;
    final railHeight = homeProductRailHeight(
      cardWidth,
      textScale: homeTextScale(context),
      hasPackNote: products.any((p) => packInfoOf(p).isPack),
      // The Coming Soon row (custom `items`) has no Add stepper.
      hasAction: items == null,
    );
    final header = SectionHeader(
      title: title,
      subtitle: sectionSubtitle,
      actionLabel: l10n.commonSeeAll,
      onAction:
          onSeeAll ??
          () => context.push(isFeatured ? '/popular-products' : '/hot-deals'),
    );

    // With enough products the grid becomes two rows that scroll sideways;
    // otherwise (and while loading) it's a single rail. Either way the cards
    // keep the rail's size, so they match the Hot Deals cards.
    if (grid && !_isLoadingProducts && products.length >= 6) {
      // Full columns only, so the last one never ends on a gap.
      final gridProducts = products.length.isOdd
          ? products.take(products.length - 1).toList()
          : products;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          SizedBox(
            height: railHeight * 2 + 12,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gridProducts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: cardWidth,
              ),
              itemBuilder: (context, index) => _buildProductCard(
                gridProducts[index],
                showHotBadge: false,
                heroScope: heroScope,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 12),
        SizedBox(
          height: railHeight,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.base),
            child: _isLoadingProducts
                ? ListView.separated(
                    key: const ValueKey('rail-loading'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, _) => SizedBox(
                      width: cardWidth,
                      child: const SkeletonProductCard(),
                    ),
                  )
                : products.isEmpty
                ? EmptyState(
                    key: const ValueKey('rail-empty'),
                    icon: HugeIcons.strokeRoundedPackage,
                    title: l10n.homeNoProductsAvailable,
                    compact: true,
                  )
                : ListView.separated(
                    key: ValueKey('rail-${products.length}'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: cardWidth,
                      child: _buildProductCard(
                        products[index],
                        // No HOT tag: the section title already says it.
                        showHotBadge: false,
                        heroScope: heroScope,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Quantity of [productId] in the cart (pieces or meters), 0 when absent.
  int _cartQuantityOf(String productId) {
    for (final item in ref.read(cartProvider).items) {
      if (item.productId == productId) return item.quantity;
    }
    return 0;
  }

  /// Adds, changes or removes a product from a card's stepper. The first tap
  /// adds the minimum quantity, exactly like the old "Add" button did.
  Future<void> _setCardQuantity(
    Map<String, dynamic> product,
    int quantity,
  ) async {
    final l10n = context.l10n;
    if (ref.read(guestModeProvider)) {
      _showGuestModePopup(l10n.homePreviewAddToCartDisabled);
      return;
    }
    final productId = product['id'].toString();
    final cart = ref.read(cartProvider.notifier);
    final current = _cartQuantityOf(productId);
    if (current > 0) {
      final error = await cart.updateQuantity(productId, quantity);
      if (error != null && mounted) {
        final stock = ref
            .read(cartProvider)
            .items
            .where((item) => item.productId == productId)
            .map((item) => item.stock)
            .firstOrNull;
        showAppSnack(
          context,
          stock != null && stock > 0
              ? l10n.cartOnlyUnitsAvailable(stock)
              : error,
          tone: SnackTone.error,
        );
      }
      return;
    }
    if (quantity <= 0) return;
    final hasOriginalPrice =
        product['originalPrice'] is num &&
        (product['originalPrice'] as num) > 0 &&
        product['originalPrice'] != product['price'];
    final configuredMinimum = product['minWholesaleQuantity'];
    final minimumWholesaleQuantity = configuredMinimum is num
        ? configuredMinimum.toInt()
        : int.tryParse(configuredMinimum?.toString() ?? '') ?? 1;
    final error = await cart.addItem(
      productId: productId,
      name: product['name'] ?? '',
      nameHindi: product['nameHindi']?.toString(),
      brand: product['brand']?.toString(),
      category: product['category']?.toString(),
      minWholesaleQuantity: minimumWholesaleQuantity,
      minCustomerQuantity: customerMinimumOf(product),
      priceUnit: product['priceUnit']?.toString(),
      packing: product['packing']?.toString(),
      price: (product['price'] as num).toDouble(),
      mrp: hasOriginalPrice
          ? (product['originalPrice'] as num).toDouble()
          : null,
      image: product['image']?.toString(),
      quantity: quantity,
    );
    if (error != null && mounted) {
      showAppSnack(
        context,
        apiErrorText(context, error),
        tone: SnackTone.error,
      );
    }
  }

  Widget _buildProductCard(
    Map<String, dynamic> product, {
    bool showHotBadge = true,
    // Keeps photo tags unique when a product sits in both rails.
    String heroScope = 'home',
  }) {
    final l10n = context.l10n;
    final productId = product['id'].toString();
    final heroTag = '$heroScope-product-image-$productId';
    final price = (product['price'] as num?) ?? 0;
    final originalPrice = product['originalPrice'];
    final mrp = originalPrice is num && originalPrice > 0
        ? originalPrice
        : null;
    final discount = mrp != null && mrp > price
        ? (((mrp - price) / mrp) * 100).round()
        : 0;

    // Pick badge: HOT (only when showHotBadge=true) > SALE (discount) > NEW
    String? badgeLabel;
    var badgeTone = ChipTone.brand;
    if (showHotBadge &&
        (product['isHot'] == true ||
            product['badge']?.toString().contains('HOT') == true)) {
      badgeLabel = l10n.homeBadgeHot;
      badgeTone = ChipTone.error;
    } else if (discount > 0) {
      // No badge: the card tags the photo with the discount ("16% OFF").
    } else if (product['isNew'] == true) {
      badgeLabel = l10n.homeBadgeNew;
      badgeTone = ChipTone.info;
    }

    final brand = (product['brand'] ?? product['category'] ?? '').toString();
    final rating = product['rating'];
    final reviewCount = product['reviewCount'] ?? product['reviews'];
    final inStock = product['inStock'] != false;
    final pack = packInfoOf(product);
    final isMeter = isMeterProduct(product);
    final step = _isWholesaler && pack.isPack ? pack.size : 1;
    final minimum = _isWholesaler
        ? wholesaleMinimumOf(product)
        : customerMinimumOf(product);
    final stock = product['stock'];
    final packParts = pack.isPack ? packCardParts(l10n, pack, price) : null;

    // Each card watches only its own heart and cart quantity, so a cart or
    // wishlist change rebuilds the cards it touches, not the whole screen.
    return Consumer(
      builder: (context, ref, _) {
        final isWishlisted = ref.watch(
          wishlistProvider.select((w) => w.contains(productId)),
        );
        final quantity = ref.watch(
          cartProvider.select(
            (cart) =>
                cart.items
                    .where((item) => item.productId == productId)
                    .map((item) => item.quantity)
                    .firstOrNull ??
                0,
          ),
        );
        return ProductCard(
          name: _getDisplayName(product),
          brand: brand.isEmpty ? l10n.homeBrandName : brand,
          category: product['category']?.toString() ?? '',
          imageUrl: product['image']?.toString(),
          price: price,
          mrp: mrp,
          unit: pack.isPack || isMeter
              ? (isMeter ? l10n.uiPerMeter : l10n.uiPerPiece)
              : null,
          packNote: packParts?.label,
          packPrice: packParts?.price,
          rating: rating is num ? rating.toDouble() : null,
          reviewCount: reviewCount is num ? reviewCount.toInt() : null,
          badge: badgeLabel,
          badgeTone: badgeTone,
          inStock: inStock,
          soldOutLabel: l10n.commonOutOfStock,
          offLabel: (percent) => l10n.commonPercentOff('$percent'),
          comingSoon: isComingSoonProduct(product),
          comingSoonPrice: isPriceHidden(product) ? l10n.comingSoonPrice : null,
          heroTag: heroTag,
          wishlisted: isWishlisted,
          wishlistLabel: isWishlisted
              ? l10n.uiRemoveFromWishlist
              : l10n.uiAddToWishlist,
          onWishlist: () {
            if (ref.read(guestModeProvider)) {
              _showGuestModePopup(l10n.homePreviewWishlistDisabled);
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
                    mrp: mrp?.toDouble(),
                    category: product['category']?.toString(),
                    nameHindi: product['nameHindi']?.toString(),
                    blurHash: product['blurHash']?.toString(),
                  ),
                );
          },
          onTap: () => context.push(
            '/product/$productId',
            extra: {
              'heroTag': heroTag,
              'heroImage': product['image']?.toString(),
              'heroBlurHash': product['blurHash']?.toString(),
            },
          ),
          action: QuantityStepper(
            quantity: quantity,
            compact: true,
            expand: true,
            enabled: inStock,
            step: step,
            minimum: minimum,
            maximum: stock is num && stock > 0 ? stock.toInt() : null,
            addLabel: l10n.homeAdd,
            decreaseLabel: l10n.uiDecreaseQuantity,
            increaseLabel: l10n.uiIncreaseQuantity,
            displayQuantity: step > 1 ? (value) => '${value ~/ step}' : null,
            onLimitReached: () => showAppSnack(
              context,
              l10n.cartOnlyUnitsAvailable((stock as num).toInt()),
              tone: SnackTone.error,
            ),
            onChanged: (value) => _setCardQuantity(product, value),
          ),
        );
      },
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
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'shipped':
      case 'processing':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  Widget _dealerSectionHeader(
    String title,
    String actionLabel,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: SectionHeader(
        title: title,
        actionLabel: actionLabel,
        onAction: onTap,
      ),
    );
  }

  Widget _dealerCard({required Widget child, VoidCallback? onTap}) {
    return Pressable(
      onTap: onTap,
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
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
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonShimmer(
              child: Skeleton(height: 118, radius: AppRadius.lg),
            ),
          )
        else if (deals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _dealerCard(
              onTap: () => _selectNavIndex(2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAgreement02,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.homeNoOpenDeals,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: deals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                                        errorWidget: (_, _, _) => Container(
                                          width: 48,
                                          height: 48,
                                          color: AppColors.gray50,
                                          child: const Center(
                                            child: HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedAgreement02,
                                              color: AppColors.textTertiary,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.md,
                                          ),
                                        ),
                                        child: const Center(
                                          child: HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedAgreement02,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.3,
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
                                        color: AppColors.textPrimary,
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
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: StatusChip(
                                  label: _dealerDealLabel(status, offerBy),
                                  tone: isCounter
                                      ? ChipTone.warning
                                      : ChipTone.neutral,
                                  dense: true,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _dealerCard(
              onTap: orderId.isEmpty
                  ? null
                  : () => context.push('/tracking/$orderId'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDeliveryTruck01,
                          color: stageColor,
                          size: 22,
                        ),
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
                              color: AppColors.textPrimary,
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
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: AppColors.textTertiary,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                              color: AppColors.textPrimary,
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
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: context.l10n.homeRepeatButton,
                      icon: HugeIcons.strokeRoundedRepeat,
                      variant: AppButtonVariant.tonal,
                      size: AppButtonSize.small,
                      expand: false,
                      loading: isRepeating,
                      onPressed: () => _repeatRequirement(order),
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
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
    final error = await ref
        .read(cartProvider.notifier)
        .updateQuantity(productId, quantity);
    if (error != null && mounted) {
      // Say why "+" didn't work (usually the stock limit).
      final item = ref
          .read(cartProvider)
          .items
          .where((i) => i.productId == productId)
          .firstOrNull;
      showAppSnack(
        context,
        item != null
            ? cartStockLimitText(context.l10n, item, _isWholesaler)
            : error,
        tone: SnackTone.error,
      );
      return;
    }
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

  /// Edits the delivery address. With [forCheckout] the sheet's button
  /// places the order right after saving, so it says so.
  Future<bool> _openCartAddressBottomSheet({bool forCheckout = false}) async {
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
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
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
                    const SheetHandle(),
                    const SizedBox(height: 8),
                    Text(
                      l10n.homeShippingAddress,
                      style: AppFonts.jakarta(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
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
                                showCheckmark: false,
                                label: Text(
                                  '${a.fullName} • ${a.shortAddress}',
                                  style: AppFonts.jakarta(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? AppColors.primaryDeep
                                        : AppColors.textPrimary,
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
                                selectedColor: AppColors.primarySoft,
                                backgroundColor: AppColors.surfaceLight,
                                side: BorderSide(
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
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
                    AppButton(
                      label: forCheckout
                          ? l10n.cartPlaceOrderRequest
                          : l10n.homeSaveAddress,
                      icon: forCheckout ? HugeIcons.strokeRoundedSent : null,
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

  // Wholesalers: the whole cart goes to the Deal Desk as a requirement.
  Future<void> _sendCartAsRequirement() async {
    if (ref.read(cartProvider).items.isEmpty) return;
    setState(() => _isCheckingOut = true);
    final sent = await sendCartRequirement(context, ref);
    if (!mounted) return;
    setState(() => _isCheckingOut = false);
    if (sent) _selectNavIndex(3);
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
          backgroundColor: AppColors.warning,
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

    final saved = await _openCartAddressBottomSheet(forCheckout: true);
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
        backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.error,
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
        labelStyle: AppFonts.jakarta(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
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
        child: SkeletonShimmer(
          child: Skeleton(height: bannerHeight, radius: AppRadius.xl - 4),
        ),
      );
    }
    if (_promoBanners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          key: _promoCarouselKey,
          height: bannerHeight,
          child: PageView.builder(
            controller: _promoBannerController,
            itemCount: _promoBanners.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => _currentPromoBannerIndex.value = i,
            itemBuilder: (context, index) {
              final banner = _promoBanners[index];
              final hasImage = (banner['imageUrl'] ?? '').toString().isNotEmpty;
              final linkUrl = banner['linkUrl'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Pressable(
                  onTap: () => _handleBannerTap(linkUrl),
                  scale: 0.985,
                  borderRadius: BorderRadius.circular(AppRadius.xl - 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl - 4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl - 4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasImage)
                            CachedNetworkImage(
                              imageUrl: banner['imageUrl'] ?? '',
                              fit: BoxFit.cover,
                              fadeInDuration: AppMotion.slow,
                              placeholder: (_, _) =>
                                  const ColoredBox(color: AppColors.gray100),
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: AppColors.primaryDeep,
                              ),
                            )
                          else
                            const ColoredBox(color: AppColors.primaryDeep),
                          // Text Content Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  hasImage
                                      ? Colors.black.withValues(alpha: 0.6)
                                      : Colors.transparent,
                                  Colors.transparent,
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
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.6,
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
                                              fontWeight: FontWeight.w800,
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
                                              AppRadius.pill,
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
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryDeep,
                                                  ),
                                                ),
                                              ),
                                              _getBannerIcon(
                                                banner['buttonIcon'],
                                                AppColors.primaryDeep,
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
          ValueListenableBuilder<int>(
            valueListenable: _currentPromoBannerIndex,
            builder: (context, current, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _promoBanners.length,
                (index) => AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.base),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: current == index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: current == index
                        ? AppColors.primary
                        : AppColors.gray300,
                    borderRadius: BorderRadius.circular(4),
                  ),
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
        SectionHeader(
          title: l10n.homeReviewsTitle,
          subtitle: l10n.homeReviewsEyebrow,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _buildReviewCard(
                Map<String, String>.from({
                  'name': review['name'].toString(),
                  'role': review['role'].toString(),
                  'review': review['review'].toString(),
                  'rating': review['rating'].toString(),
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, String> review) {
    final name = review['name'] ?? '';
    final rating = double.tryParse(review['rating'] ?? '') ?? 0;
    return SizedBox(
      width: 280,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primarySoft,
                  ),
                  child: Center(
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                      style: AppFonts.jakarta(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                            color: AppColors.success,
                            size: 15,
                          ),
                        ],
                      ),
                      Text(
                        review['role'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...List.generate(5, (index) {
                  final icon = index < rating.floor()
                      ? Icons.star_rounded
                      : index < rating
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded;
                  return Icon(
                    icon,
                    color: index < rating ? AppColors.star : AppColors.gray300,
                    size: 16,
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  review['rating'] ?? '',
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                review['review'] ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.jakarta(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deals where DemoMart has sent a new price and is waiting for the
  /// wholesaler; shown as a badge on the Deal Desk tab.
  int get _dealsAwaitingReply => _negotiations.where((negotiation) {
    final status = (negotiation['status'] ?? '').toString();
    final offerBy = (negotiation['currentOfferBy'] ?? '').toString();
    return status == 'countered' && offerBy == 'admin';
  }).length;

  // Floating bottom nav: a frosted pill a little above the bottom edge,
  // holding round tabs; the active tab widens into a teal pill with its
  // label. Pages scroll behind it, so they leave [_navOverlap] at the end.
  static const double _navItemSize = 48;
  static const double _navPadding = 5;
  static const double _navGap = 4;
  static const double _navBottomGap = 10;

  /// Space between the floating cart pill and the nav below it.
  static const double _cartNavGap = 12;

  /// How much of the bottom of the screen the floating nav covers.
  double get _navOverlap =>
      _navItemSize +
      _navPadding * 2 +
      _navBottomGap +
      MediaQuery.paddingOf(context).bottom;

  Widget _buildBottomNav() {
    final l10n = context.l10n;
    final isGuest = ref.watch(guestModeProvider);
    // Only the count: other cart changes don't rebuild the screen.
    final cartCount = isGuest
        ? 0
        : ref.watch(
            cartProvider.select((c) => c.displayItemCount(_isWholesaler)),
          );
    final showCartPill = _selectedNavIndex <= 2 && !isGuest;
    final (labelWidth, navGap) = _navLayout([
      l10n.homeNavHome,
      l10n.homeNavSearch,
      l10n.homeNavCategories,
      l10n.homeNavCart,
      _isWholesaler ? l10n.homeNavDealDesk : l10n.homeNavProfile,
    ]);
    Widget navItem(IconData icon, String label, int index, {int badge = 0}) =>
        _buildNavItem(icon, label, index, labelWidth: labelWidth, badge: badge);
    final items = _isWholesaler
        ? [
            navItem(HugeIcons.strokeRoundedHome01, l10n.homeNavHome, 0),
            navItem(HugeIcons.strokeRoundedSearch01, l10n.homeNavSearch, 1),
            navItem(
              HugeIcons.strokeRoundedDashboardSquare01,
              l10n.homeNavCategories,
              2,
            ),
            navItem(
              HugeIcons.strokeRoundedShoppingCart01,
              l10n.homeNavCart,
              5,
              badge: cartCount,
            ),
            navItem(
              HugeIcons.strokeRoundedBriefcase01,
              l10n.homeNavDealDesk,
              3,
              badge: _dealsAwaitingReply,
            ),
          ]
        : [
            navItem(HugeIcons.strokeRoundedHome01, l10n.homeNavHome, 0),
            navItem(HugeIcons.strokeRoundedSearch01, l10n.homeNavSearch, 1),
            navItem(
              HugeIcons.strokeRoundedDashboardSquare01,
              l10n.homeNavCategories,
              2,
            ),
            navItem(
              HugeIcons.strokeRoundedShoppingCart01,
              l10n.homeNavCart,
              3,
              badge: cartCount,
            ),
            navItem(HugeIcons.strokeRoundedUser, l10n.homeNavProfile, 4),
          ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, _navBottomGap),
        child: Center(
          heightFactor: 1,
          // The floating cart pill rides above the nav, left-aligned with
          // it: the column is as wide as the nav, so they share a left edge.
          // Every tab's label gets the same width, so the nav keeps one
          // width whichever tab is open.
          // The cart pill's and the nav's blurs share one read of the page
          // behind them.
          child: BackdropGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Its own context reads the keyboard inset, so the keyboard
                // animating rebuilds only the pill, not every tab.
                Builder(
                  builder: (context) => FloatingCartBar(
                    margin: const EdgeInsets.only(bottom: _cartNavGap),
                    visible:
                        showCartPill &&
                        MediaQuery.viewInsetsOf(context).bottom == 0,
                    onTap: () => _selectNavIndex(_isWholesaler ? 5 : 3),
                  ),
                ),
                // The shadow sits outside the pill's clip so it isn't cut off.
                DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: [
                      BoxShadow(
                        color: AppColors.primaryDeep.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  // Only the frosted backdrop is clipped to the pill; the tabs
                  // sit on top unclipped so a badge on the end tab isn't cut
                  // off by the rounded end.
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        // A rounded-rect clip (not a path): it holds around
                        // a blur under transforms too, and is cheaper.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          // Frosted glass: the page scrolling behind shows
                          // through.
                          child: BackdropFilter.grouped(
                            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: AppColors.surfaceLight.withValues(
                                  alpha: 0.84,
                                ),
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(_navPadding),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) SizedBox(width: navGap),
                              items[i],
                            ],
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
      ),
    );
  }

  static final _navLabelStyle = AppFonts.jakarta(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  /// Width of the active tab's label and the gap between tabs. The label
  /// gets the widest of [labels], but never more than the room the nav
  /// leaves on this screen (four round tabs, gaps, padding and the active
  /// pill's icon), so it can't overflow a 360 dp phone or a larger text
  /// size. When it doesn't fit, the tabs close up first; a label that still
  /// doesn't fit is drawn slightly smaller.
  (double, double) _navLayout(List<String> labels) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _navLabelStyle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width.ceilToDouble());
      painter.dispose();
    }
    double room(double gap) =>
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        24 - // side padding
        _navPadding * 2 -
        _navItemSize * 4 -
        gap * 4 -
        (16 * 2 + 22 + 8) - // active pill: padding, icon, gap
        4; // slack for the spring
    final target = math.min(widest, 110.0);
    final gap = room(_navGap) >= target ? _navGap : 1.0;
    return (math.max(0.0, math.min(target, room(gap))), gap);
  }

  /// One tab of the floating nav: a grey circle with its icon, or, while
  /// active, a teal pill with a white icon and its label ([labelWidth]
  /// wide). Switching tabs springs one pill open and the other closed.
  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    required double labelWidth,
    int badge = 0,
  }) {
    final isSelected = _selectedNavIndex == index;
    final duration = AppMotion.of(context, AppMotion.springDuration);
    const curve = AppMotion.spring;
    const idleColor = AppColors.textSecondary;
    // The icon's sides in a circle: (48 - 22) / 2.
    const circleInset = (_navItemSize - 22) / 2;

    final tab = AnimatedContainer(
      duration: duration,
      curve: curve,
      height: _navItemSize,
      padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : circleInset),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: isSelected ? Colors.white : idleColor),
            duration: AppMotion.of(context, AppMotion.slow),
            builder: (context, iconColor, _) =>
                HugeIcon(icon: icon, color: iconColor ?? idleColor, size: 22),
          ),
          // The label unfolds beside the icon in the active pill. The spring
          // overshoots, so the fold is kept from going below zero (Align
          // rejects a negative width factor).
          ClipRect(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: isSelected ? 1 : 0),
              duration: duration,
              curve: curve,
              builder: (context, fold, child) => Align(
                alignment: Alignment.centerLeft,
                // Never wider than the label: the nav's width was budgeted
                // for it (see _navLabelWidth).
                widthFactor: fold.clamp(0.0, 1.0),
                child: child,
              ),
              child: AnimatedOpacity(
                duration: AppMotion.of(context, AppMotion.slow),
                opacity: isSelected ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: labelWidth,
                    // Shrinks a label that's wider than the room left.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, maxLines: 1, style: _navLabelStyle),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!isSelected) HapticFeedback.selectionClick();
          _selectNavIndex(index);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tab,
            if (badge > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: RollingNumber(
                    value: badge,
                    format: (value) => value > 99 ? '99+' : '${value.toInt()}',
                    style: AppFonts.jakarta(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _VerticalDashedLinePainter extends CustomPainter {
  const _VerticalDashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gray300
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
      paint.color = i.isEven ? AppColors.gray700 : AppColors.gray400;
      canvas.drawRect(Rect.fromLTRB(left, y, right, y + height), paint);
      y += height + 1.35;
      if (y > size.height) break;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => false;
}

/// Urgency tint shared by price-change UI: calm blue from 6h out,
/// amber under 6h, red under 1h. Discrete zones, no muddy mid-blends.
Color pulseAccentFor(DateTime? effectiveAt) {
  if (effectiveAt == null) return AppColors.primary;
  final remain = effectiveAt.difference(DateTime.now());
  if (remain.isNegative || remain.inMinutes < 60) {
    return AppColors.error;
  }
  if (remain.inHours < 6) return AppColors.warning;
  return AppColors.primary;
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

  static const Color _primaryBlue = AppColors.primary;
  static const Color _surfaceWhite = AppColors.surfaceLight;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textMuted = AppColors.textTertiary;

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
      // Hold still while its tab or page is hidden.
      if (!TickerMode.getNotifier(context).value) return;
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
                            ? AppColors.success
                            : AppColors.warning;
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
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: urgency.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: urgency.withValues(alpha: 0.1),
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
                                    color: urgency.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_outlined,
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
                                          fontSize: 11.5,
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
                                    color: urgency.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
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
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: urgency.withValues(alpha: 0.7),
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
          const SizedBox(height: 10),
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
                  color: _index == i ? _primaryBlue : AppColors.gray300,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// For the Home hero's video slides: tracks whether the slide can actually
/// be seen. That means its tab and page are showing (TickerMode) and at least
/// half of it is on screen below the pinned search bar. Calls
/// [onSlideVisibilityChanged] when that flips.
mixin _HeroSlideVisibility<T extends StatefulWidget> on State<T> {
  ValueListenable<bool>? _tickerMode;
  ScrollPosition? _pageScroll;
  bool slideVisible = false;

  void onSlideVisibilityChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticker = TickerMode.getNotifier(context);
    if (!identical(ticker, _tickerMode)) {
      _tickerMode?.removeListener(_checkSlideVisibility);
      _tickerMode = ticker..addListener(_checkSlideVisibility);
    }
    final scroll = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (!identical(scroll, _pageScroll)) {
      _pageScroll?.removeListener(_checkSlideVisibility);
      _pageScroll = scroll?..addListener(_checkSlideVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkSlideVisibility(),
    );
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_checkSlideVisibility);
    _pageScroll?.removeListener(_checkSlideVisibility);
    super.dispose();
  }

  void _checkSlideVisibility() {
    if (!mounted) return;
    final visible = (_tickerMode?.value ?? true) && _halfOnScreen();
    if (visible == slideVisible) return;
    slideVisible = visible;
    onSlideVisibilityChanged();
  }

  bool _halfOnScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final top = HomeHeroHeaderDelegate.collapsedHeight(
      MediaQuery.paddingOf(context).top,
    );
    final bottom = MediaQuery.sizeOf(context).height;
    final shown = math.min(rect.bottom, bottom) - math.max(rect.top, top);
    return shown >= rect.height * 0.5;
  }
}

/// Inline muted-autoplay video slide for hero video_upload banners.
/// Button + link only: the whole slide opens the link, mute toggle is separate.
///
/// It plays only while it's the active slide and can be seen; scrolled away,
/// on another tab or under another page, it pauses, and picks up where it
/// left off when it's back. The video isn't loaded until the slide is first
/// played; until then the poster shows.
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

class _HeroVideoSlideState extends State<_HeroVideoSlide>
    with _HeroSlideVisibility {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _muted = true;
  bool _notifiedComplete = false;

  bool get _shouldPlay => widget.isActive && slideVisible;

  /// Loads the video the first time the slide should play.
  void _ensureController() {
    if (_controller != null) return;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(false)
      ..setVolume(_muted ? 0 : 1)
      ..addListener(_onTick)
      ..initialize().then(
        (_) {
          if (!mounted) return;
          setState(() => _initialized = true);
          _syncPlayback();
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _hasError = true);
        },
      );
    // Shows the loading spinner over the poster.
    setState(() {});
  }

  /// Plays while active and visible, pauses otherwise. A video that has
  /// finished stays finished until the slide becomes active again.
  void _syncPlayback() {
    if (!mounted || _hasError) return;
    if (_shouldPlay) {
      _ensureController();
      final controller = _controller!;
      if (_initialized && !_notifiedComplete && !controller.value.isPlaying) {
        controller.play();
      }
    } else if (_initialized && _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  @override
  void onSlideVisibilityChanged() => _syncPlayback();

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

  @override
  void didUpdateWidget(_HeroVideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Swiped back to: start again from the beginning.
    if (widget.isActive && !oldWidget.isActive) {
      _notifiedComplete = false;
      if (_initialized) _controller?.seekTo(Duration.zero);
    }
    _syncPlayback();
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
              color: AppColors.primary.withOpacity(0.3),
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
            if (_controller != null && !_initialized && !_hasError)
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
            // Mute toggle (does not navigate). A 44 px tap area around the
            // 34 px circle.
            Positioned(
              right: 7,
              bottom: 7,
              child: Semantics(
                button: true,
                label: _muted
                    ? context.l10n.uiUnmuteVideo
                    : context.l10n.uiMuteVideo,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final next = !_muted;
                    await _controller?.setVolume(next ? 0 : 1);
                    if (mounted) setState(() => _muted = next);
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

class _HeroYoutubeSlideState extends State<_HeroYoutubeSlide>
    with _HeroSlideVisibility {
  YoutubePlayerController? _controller;
  bool _playing = false;

  // Started by a tap; pauses while the slide can't be seen and resumes when
  // it can again.
  @override
  void onSlideVisibilityChanged() {
    if (!_playing) return;
    if (slideVisible && widget.isActive) {
      _controller?.play();
    } else {
      _controller?.pause();
    }
  }

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
            color: AppColors.primary.withOpacity(0.3),
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
              progressIndicatorColor: AppColors.primary,
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
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: AppShapes.squircle(14),
                  ),
                  child: Text(
                    context.l10n.homeBannerShopNow,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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

/// Keeps the Home search bar pinned under the header while the page scrolls,
/// adding a hairline once content slides beneath it.
