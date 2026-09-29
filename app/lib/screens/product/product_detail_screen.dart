import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/api_config.dart';
import '../../core/config/public_business_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../widgets/pending_price_change_notice.dart';
import '../../widgets/verified_seller_badge.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? heroTag;

  const ProductDetailScreen({super.key, required this.productId, this.heroTag});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _cartBounce;
  // Time spent on this product page, reported to the backend for leads.
  final Stopwatch _watchTimer = Stopwatch();
  String? _watchAuthToken;
  final PageController _imgCtrl = PageController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final FocusNode _quantityFocusNode = FocusNode();
  int _imgIndex = 0;
  bool _addedToCart = false;
  int _quantity = 1;
  bool _descExpanded = false;
  // _isFav removed â€“ now using wishlistProvider
  bool _shippingOpen = false;
  bool _isBuyNowLoading = false;
  YoutubePlayerController? _ytCtrl;
  bool _videoReady = false;
  Map<String, dynamic>? _product;
  List<dynamic> _relatedProducts = [];
  bool _isLoading = true;
  bool _isRelatedLoading = false;
  int _bgKey = 0;
  String? _selectedVariantId;
  String? _error;
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

  // Spotlyst Q1 Design Tokens
  static const Color _blue = Color(0xFF0F766E);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFEF4444);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _txt = Color(0xFF1E293B);
  static const Color _txtSec = Color(0xFF64748B);
  static const Color _txtMuted = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _violet = Color(0xFF0F766E);
  static const Color _mrpAmount = Color(0xFF94A3B8);
  static const Color _customerAmount = Color(0xFF0F766E);
  static const Color _specialAmountWholesale = Color(0xFF15803D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cartBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _quantityFocusNode.addListener(() {
      if (!_quantityFocusNode.hasFocus) {
        _commitQuantityInput(_product?['stock']);
      }
    });
    _fetchProduct();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushWatchTime();
    _cartBounce.dispose();
    _imgCtrl.dispose();
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    _ytCtrl?.dispose();
    super.dispose();
  }

  int _stockLimit(dynamic stock) {
    if (stock is num && stock > 0) return stock.toInt();
    return 99;
  }

  int _minimumQuantity([Map<String, dynamic>? product]) {
    if (!ref.read(effectiveIsWholesalerProvider)) return 1;
    final configured =
        product?['minWholesaleQuantity'] ?? _product?['minWholesaleQuantity'];
    final quantity = configured is num
        ? configured.toInt()
        : int.tryParse(configured?.toString() ?? '');
    return quantity != null && quantity > 0 ? quantity : 1;
  }

  void _setQuantity(int value, dynamic stock) {
    final minimum = _minimumQuantity();
    final limit = math.max(minimum, _stockLimit(stock));
    final next = value.clamp(minimum, limit).toInt();
    setState(() => _quantity = next);
    _quantityController.text = '$next';
    _quantityController.selection = TextSelection.collapsed(
      offset: _quantityController.text.length,
    );
  }

  void _commitQuantityInput(dynamic stock) {
    final parsed = int.tryParse(_quantityController.text.trim());
    _setQuantity(parsed ?? _minimumQuantity(), stock);
  }

  void _onQuantityTextChanged(String value, dynamic stock) {
    if (value.isEmpty) return;
    final parsed = int.tryParse(value);
    if (parsed == null) return;

    final minimum = _minimumQuantity();
    final limit = math.max(minimum, _stockLimit(stock));
    if (parsed > limit) {
      _setQuantity(limit, stock);
      return;
    }

    setState(() => _quantity = parsed < minimum ? minimum : parsed);
  }

  String _quantityUnitLabel() {
    final l10n = context.l10n;
    final raw =
        (_product?['priceUnit'] ?? _product?['unit'] ?? _product?['uom'])
            ?.toString()
            .trim() ??
        '';
    if (raw.isEmpty) return l10n.productUnitPiece;

    final normalized = raw.toLowerCase().replaceAll('.', '');
    if (normalized.contains('mtr') || normalized.contains('meter')) {
      return l10n.productUnitMeter;
    }
    if (normalized.contains('packet') || normalized.contains('pack')) {
      return l10n.productUnitPacket;
    }
    if (normalized.contains('piece') ||
        normalized.contains('pcs') ||
        normalized.contains('unit') ||
        normalized.contains('nos')) {
      return l10n.productUnitPiece;
    }

    return raw;
  }

  void _initYoutube() {
    final url = _product?['videoUrl']?.toString() ?? '';
    if (url.isEmpty) return;
    final id = YoutubePlayer.convertUrlToId(url);
    if (id == null) return;
    _ytCtrl = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        showLiveFullscreenButton: false,
        disableDragSeek: false,
        forceHD: false,
      ),
    );
  }

  void _openFullscreenVideo() {
    final url = _product?['videoUrl']?.toString() ?? '';
    if (url.isEmpty) return;
    final vid = YoutubePlayer.convertUrlToId(url);
    if (vid == null) return;

    // Pause inline player if playing
    _ytCtrl?.pause();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullscreenVideoPage(videoId: vid),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _fetchProduct() async {
    try {
      final r = await _dio.get('/products/${widget.productId}');
      if (r.statusCode == 200) {
        final rawData = r.data['data'] ?? r.data;
        final productData = rawData is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawData)
            : Map<String, dynamic>.from(rawData as Map);
        if (_needsLabelFallback(productData)) {
          productData['labels'] = await _fetchFallbackLabels(
            productData['labelIds'] as List<dynamic>,
          );
        }
        setState(() {
          _product = productData;
          _selectedVariantId = _resolveInitialVariantId(productData);
          _quantity = _minimumQuantity(productData);
          _quantityController.text = '$_quantity';
          _quantityController.selection = TextSelection.collapsed(
            offset: _quantityController.text.length,
          );
          _isLoading = false;
        });
        _trackView();
        _fetchRelatedProducts();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      final data = e.response?.data;
      final map = data is Map ? data : null;
      final error = map?['error'];
      final errorMap = error is Map ? error : null;
      var msg =
          map?['message']?.toString() ??
          errorMap?['message']?.toString() ??
          e.message ??
          l10n.productLoadFailed;
      if (e.type == DioExceptionType.connectionError ||
          msg.contains('No route to host') ||
          msg.contains('Connection refused')) {
        msg = l10n.commonNetworkError;
      }
      debugPrint('Error fetching product: $msg');
      setState(() {
        _isLoading = false;
        _error = msg;
      });
    } catch (e) {
      debugPrint('Error fetching product: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = context.l10n.productLoadFailed;
      });
    }
  }

  bool _needsLabelFallback(Map<String, dynamic> productData) {
    final labels = productData['labels'];
    final labelIds = productData['labelIds'];
    final hasResolvedLabels = labels is List && labels.isNotEmpty;
    final hasLabelIds = labelIds is List && labelIds.isNotEmpty;
    return !hasResolvedLabels && hasLabelIds;
  }

  Future<List<Map<String, dynamic>>> _fetchFallbackLabels(
    List<dynamic> labelIds,
  ) async {
    try {
      final response = await _dio.get('/');
      if (response.statusCode != 200) {
        return const [];
      }

      final payload = response.data['data'];
      if (payload is! Map) return const [];
      final rawLabels = payload['labels'];
      if (rawLabels is! List) return const [];

      final lookup = <String, Map<String, dynamic>>{};
      for (final item in rawLabels.whereType<Map>()) {
        final label = Map<String, dynamic>.from(item);
        final labelId = _normalizedLabelLookup(label['id']);
        final labelTitle = _normalizedLabelLookup(label['title']);
        if (labelId.isNotEmpty) {
          lookup[labelId] = label;
        }
        if (labelTitle.isNotEmpty) {
          lookup.putIfAbsent(labelTitle, () => label);
        }
      }

      final resolved = labelIds
          .map((id) => lookup[_normalizedLabelLookup(id)])
          .whereType<Map<String, dynamic>>()
          .toList();
      resolved.sort((a, b) {
        final aOrder = (a['order'] as num?)?.toInt() ?? 0;
        final bOrder = (b['order'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });
      return resolved;
    } catch (e) {
      debugPrint('Error resolving fallback product labels: $e');
      return const [];
    }
  }

  String _normalizedLabelLookup(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  List<Map<String, dynamic>> get _variants {
    return const [];
  }

  String? _resolveInitialVariantId(Map<String, dynamic> product) {
    return null;
  }

  Map<String, dynamic>? get _selectedVariant {
    return null;
  }

  String _variantLabel(Map<String, dynamic> variant) {
    final productName = (_product?['name']?.toString() ?? '').trim();
    final rawLabel =
        (variant['displayName']?.toString() ??
                variant['name']?.toString() ??
                '')
            .trim();
    if (rawLabel.isEmpty) return context.l10n.productVariantFallback;
    if (productName.isEmpty) return rawLabel;

    final normalizedProduct = productName.toLowerCase();
    final rawLower = rawLabel.toLowerCase();
    var cleaned = rawLabel;

    if (rawLower.startsWith('$normalizedProduct - ')) {
      cleaned = rawLabel.substring(productName.length + 3).trim();
    } else if (rawLower.startsWith('${normalizedProduct}: ')) {
      cleaned = rawLabel.substring(productName.length + 3).trim();
    } else if (rawLower.startsWith('$normalizedProduct ')) {
      cleaned = rawLabel.substring(productName.length).trim();
    }

    return cleaned.isEmpty ? rawLabel : cleaned;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_product != null && !_watchTimer.isRunning) _watchTimer.start();
    } else {
      // Backgrounded, locked or interrupted: report what we have so far.
      _flushWatchTime();
    }
  }

  // Sends the seconds spent on the page since the last report. Fire-and-forget
  // so it also works from dispose(); guests and customer preview are skipped
  // because no token is captured for them.
  void _flushWatchTime() {
    final seconds = _watchTimer.elapsed.inSeconds;
    _watchTimer
      ..stop()
      ..reset();
    final token = _watchAuthToken;
    if (seconds < 1 || token == null) return;
    _dio
        .post(
          '/products/${widget.productId}/watch-time',
          data: {'seconds': seconds},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
        .then((_) {}, onError: (_) {});
  }

  Future<void> _trackView() async {
    try {
      final token = ref.read(guestModeProvider)
          ? null
          : await StorageService.getAccessToken();
      _watchAuthToken = token;
      if (mounted) {
        _watchTimer
          ..reset()
          ..start();
      }
      await _dio.post(
        '/products/${widget.productId}/view',
        data: {'source': 'direct'},
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );
    } catch (_) {}
  }

  Future<void> _trackEvent(String event) async {
    try {
      final token = ref.read(guestModeProvider)
          ? null
          : await StorageService.getAccessToken();
      await _dio.post(
        '/products/${widget.productId}/event',
        data: {'event': event, 'source': 'direct'},
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );
    } catch (_) {}
  }

  Future<void> _showGuestModePopup(String title) async {
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(dialogContext.l10n.productGuestModeDisabledMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, String>> get _imagesData {
    if (_product == null) return [];
    final imgs = _product!['images'] as List<dynamic>?;
    if (imgs == null || imgs.isEmpty) return [];
    return imgs
        .map((e) {
          final m = e as Map<String, dynamic>;
          return {
            'url': m['url']?.toString() ?? '',
            'blurHash': m['blurHash']?.toString() ?? '',
          };
        })
        .where((m) => m['url']!.isNotEmpty)
        .toList();
  }

  List<String> get _images {
    if (_product == null) return [];
    final imgs = _product!['images'] as List<dynamic>?;
    if (imgs == null || imgs.isEmpty) return [];
    return imgs
        .map((e) => (e as Map<String, dynamic>)['url']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> get _specs {
    if (_product == null) return [];
    return (_product!['specifications'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
  }

  List<String> get _bullets {
    if (_product == null) return [];
    return (_product!['bulletPoints'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
  }

  String _fmt(dynamic price) {
    if (price == null) return '0';
    final v = (price is int) ? price.toDouble() : (price as num).toDouble();
    // Always show full numbers on product detail page
    return v.toStringAsFixed(0);
  }

  Future<void> _openVariantSelectorSheet(
    List<Map<String, dynamic>> variants,
    String? selectedId,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) {
        final media = MediaQuery.of(context);
        final maxHeight = media.size.height * 0.72;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: maxHeight),
            padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + media.padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.productSelectVariant,
                            style: AppFonts.jakarta(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _txt,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.productChooseVariantHint,
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _txtSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: _txtSec),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: variants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final variantId = variant['id']?.toString();
                      final isSelected = variantId == selectedId;
                      final variantPrice =
                          variant['price'] ?? variant['retailPrice'];

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: variantId == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                setState(() {
                                  _selectedVariantId = variantId;
                                  _quantity = 1;
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF0FDFA)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? _blue
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _variantLabel(variant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.jakarta(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? _blue : _txt,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      variantPrice != null
                                          ? '₹${_fmt(variantPrice)}'
                                          : l10n.productTapToSelect,
                                      style: AppFonts.jakarta(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? _blue : _txtSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isSelected ? _blue : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? _blue
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.circle_outlined,
                                  size: isSelected ? 17 : 14,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------
  // BUILD
  // ------------------------------------------
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bp = MediaQuery.of(context).padding.bottom;
    final tp = MediaQuery.of(context).padding.top;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: _blue,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.productLoading,
                style: AppFonts.jakarta(color: _txtSec, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: _blue,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: _txtMuted,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error ?? l10n.productNotFound,
                        style: AppFonts.jakarta(color: _txtSec, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _fetchProduct();
                        },
                        child: Text(
                          l10n.commonRetry,
                          style: AppFonts.jakarta(
                            color: _blue,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
      );
    }

    final name = localizedName(
      context,
      _product,
      fallback: l10n.productPlaceholderProduct,
    );

    final desc =
        _product!['description']?.toString() ??
        _product!['shortDescription']?.toString() ??
        '';
    final sku = _product!['sku']?.toString() ?? '';
    final isWholesaler = ref.watch(effectiveIsWholesalerProvider);
    final price = isWholesaler
        ? _product!['price'] ?? _product!['wholesalePrice']
        : _product!['retailPrice'] ?? _product!['price'];
    final customerPrice = _product!['retailPrice'] ?? _product!['price'];
    final mrp = _product!['mrp'];
    final wsPrice = _product!['wholesalePrice'];
    final pendingPriceChange = (_product!)['pendingPriceChange'];
    final minWsQty = _minimumQuantity(_product);
    final stock = _product!['stock'] ?? 0;
    final inStock = (stock is int ? stock : 0) > 0;
    final negEnabled = _product!['negotiationEnabled'] == true && isWholesaler;
    final bottomContentInset = inStock ? 185.0 : 120.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _fetchProduct,
              color: _blue,
              backgroundColor: Colors.white,
              edgeOffset: tp + 60,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: tp + 64)),
                  SliverToBoxAdapter(child: _imageCarousel(name)),
                  SliverToBoxAdapter(
                    child: _infoSection(
                      name,
                      sku,
                      price,
                      mrp,
                      customerPrice,
                      wsPrice,
                      pendingPriceChange,
                      stock,
                      inStock,
                      isWholesaler,
                      l10n,
                    ),
                  ),
                  if (_specs.isNotEmpty)
                    SliverToBoxAdapter(child: _specsSection(l10n)),
                  SliverToBoxAdapter(child: _trustBadgesStrip()),
                  if (_productLabels.isNotEmpty)
                    SliverToBoxAdapter(child: _productLabelsSection()),
                  SliverToBoxAdapter(child: _descSection(desc, l10n)),
                  SliverToBoxAdapter(child: _allImagesSection(name, l10n)),
                  SliverToBoxAdapter(child: _videoSection(l10n)),
                  SliverToBoxAdapter(child: _shippingSection(l10n)),
                  SliverToBoxAdapter(child: _relatedProductsSection(l10n)),
                  SliverToBoxAdapter(
                    child: SizedBox(height: bottomContentInset + bp),
                  ),
                ],
              ),
            ),
            _topBar(tp, name, inStock, l10n),
            _bottomBar(
              name,
              price,
              mrp,
              stock,
              inStock,
              bp,
              negEnabled,
              wsPrice,
              minWsQty,
              l10n,
            ),
          ],
        ),
      ),
    );
  }

  // -- TOP BAR --
  Widget _topBar(double tp, String name, bool inStock, AppLocalizations l10n) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(8, tp + 4, 8, 10),
            decoration: BoxDecoration(
              color: _card.withOpacity(0.85),
              border: Border(
                bottom: BorderSide(color: _border.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                _circleBtn(Icons.arrow_back_ios_new, () => context.pop()),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _txt,
                        ),
                      ),
                      Text(
                        inStock ? l10n.commonInStock : l10n.commonOutOfStock,
                        style: AppFonts.jakarta(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: inStock ? _green : _red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _circleBtn(Icons.share_outlined, () {
                  final p = _product;
                  if (p == null) return;
                  final pName = localizedName(
                    context,
                    p,
                    fallback: l10n.productPlaceholderProduct,
                  );
                  final pPrice = ref.read(guestModeProvider)
                      ? p['retailPrice'] ?? p['price']
                      : p['price'] ?? p['retailPrice'];
                  final productUrl = PublicBusinessConfig.productUrl(
                    p['slug']?.toString(),
                  );
                  final shareText = pPrice != null
                      ? l10n.productShareTextWithPrice(
                          pName,
                          _fmt(pPrice),
                          productUrl,
                        )
                      : l10n.productShareText(pName, productUrl);
                  SharePlus.instance.share(ShareParams(text: shareText));
                }),
                Builder(
                  builder: (ctx) {
                    final isCustomerPreview = ref.watch(guestModeProvider);
                    final isFav =
                        !isCustomerPreview &&
                        ref.watch(wishlistProvider).contains(widget.productId);
                    return _circleBtn(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      () {
                        if (isCustomerPreview) {
                          _showGuestModePopup(
                            l10n.productWishlistDisabledPreview,
                          );
                          return;
                        }
                        final p = _product;
                        if (p == null) return;
                        final item = WishlistItem(
                          productId: widget.productId,
                          name: p['name']?.toString() ?? '',
                          image: _images.isNotEmpty ? _images.first : null,
                          price: (p['retailPrice'] ?? p['price'] ?? 0)
                              .toDouble(),
                          mrp: p['mrp'] != null
                              ? (p['mrp'] as num).toDouble()
                              : null,
                          category: p['category']?.toString(),
                          nameHindi: p['nameHindi']?.toString(),
                        );
                        ref.read(wishlistProvider.notifier).toggle(item);
                      },
                      color: isFav ? _red : _txtSec,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _bg.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color ?? _txt),
      ),
    );
  }

  // ── IMAGE CAROUSEL ──
  Widget _imageCarousel(String name) {
    if (_images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.image_outlined, size: 56, color: _txtMuted),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: PageView.builder(
                  controller: _imgCtrl,
                  itemCount: _imagesData.length,
                  onPageChanged: (i) => setState(() => _imgIndex = i),
                  itemBuilder: (_, i) {
                    final data = _imagesData[i];
                    final img = AppImage(
                      imageUrl: data['url']!,
                      blurHash: data['blurHash'],
                      category: _product?['category']?.toString() ?? '',
                      name: name, // assuming name is available in scope
                      fit: BoxFit.contain,
                    );
                    if (i == 0 && widget.heroTag != null) {
                      return Hero(
                        tag: widget.heroTag!,
                        child: Container(color: _card, child: img),
                      );
                    }
                    return Container(color: _card, child: img);
                  },
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                          Colors.black.withOpacity(0.06),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (_images.length > 1)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border.withOpacity(0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _images.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: i == _imgIndex ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _imgIndex
                                  ? _blue
                                  : _txt.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(3),
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
      ),
    );
  }

  // ── PRODUCT INFO ──
  Widget _infoSection(
    String name,
    String sku,
    dynamic price,
    dynamic mrp,
    dynamic customerPrice,
    dynamic wsPrice,
    dynamic pendingPriceChange,
    dynamic stock,
    bool inStock,
    bool isWholesaler,
    AppLocalizations l10n,
  ) {
    final priceNum = price is num
        ? price.toDouble()
        : double.tryParse('$price') ?? 0;
    final mrpNum = mrp is num ? mrp.toDouble() : double.tryParse('$mrp') ?? 0;
    final disc = (mrpNum > 0 && priceNum > 0 && mrpNum > priceNum)
        ? (((mrpNum - priceNum) / mrpNum) * 100).round()
        : 0;

    final rawRating = _product?['averageRating'] ?? _product?['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '') ?? 0.0;
    final ratingCountRaw = _product?['ratingCount'] ?? _product?['reviewCount'];
    final ratingCount = ratingCountRaw is num
        ? ratingCountRaw.toInt()
        : int.tryParse(ratingCountRaw?.toString() ?? '') ?? 0;
    String getBrand() {
      final keys = ['brandName', 'brand', 'companyName', 'manufacturer'];
      for (final key in keys) {
        final val = _product?[key]?.toString().trim();
        if (val != null && val.isNotEmpty) return val;
      }
      return l10n.productBrandFallback;
    }

    final brandDetails = getBrand();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD6E6FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _txt,
                      ),
                    ),
                    if (ratingCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($ratingCount)',
                        style: AppFonts.jakarta(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _txtSec,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              const VerifiedSellerBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 16, color: _txtSec),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.productBrandValue(brandDetails),
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _txtSec,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: AppFonts.jakarta(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _txt,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.productSkuValue(sku.isNotEmpty ? sku : 'MILL-001'),
            style: AppFonts.jakarta(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _txtSec,
              letterSpacing: 0.2,
            ),
          ),
          if (_variants.isNotEmpty) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final variantOptions = _variants
                    .where((variant) => variant['id'] != null)
                    .toList();
                if (variantOptions.isEmpty) return const SizedBox.shrink();

                final selectedIdExists = variantOptions.any(
                  (variant) => variant['id']?.toString() == _selectedVariantId,
                );
                final selectedId = selectedIdExists
                    ? _selectedVariantId
                    : variantOptions.first['id']?.toString();

                final selectedVariant = variantOptions.firstWhere(
                  (variant) => variant['id']?.toString() == selectedId,
                  orElse: () => variantOptions.first,
                );

                return GestureDetector(
                  onTap: () => _openVariantSelectorSheet(
                    variantOptions,
                    selectedId,
                    l10n,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF4F9FF), Color(0xFFFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCFE2FF)),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.productSelectVariant,
                                style: AppFonts.jakarta(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _blue,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _variantLabel(selectedVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.jakarta(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _txt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCFE2FF)),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _blue,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 8),

          RichText(
            text: TextSpan(
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _txtSec,
              ),
              children: [
                TextSpan(text: l10n.productMrpLabel),
                TextSpan(
                  text: mrp != null
                      ? '₹${_fmt(mrp)}'
                      : (price != null ? '₹${_fmt(price)}' : 'N/A'),
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _mrpAmount,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
          if (price != null) ...[
            const SizedBox(height: 4),
            // For wholesalers, show Suggested Selling Price first (was Customer Price)
            if (isWholesaler) ...[
              Row(
                children: [
                  Text(
                    l10n.productSuggestedSellingPriceLabel,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _txtSec,
                    ),
                  ),
                  Text(
                    '₹${_fmt(customerPrice)}',
                    style: AppFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _customerAmount,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            // Show the main price (Your Dealer Price for wholesalers, Special Price for buyers)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _txtSec,
                      ),
                      children: [
                        TextSpan(
                          text: isWholesaler
                              ? l10n.productYourDealerPriceLabel
                              : l10n.productSpecialPriceLabel,
                        ),
                        TextSpan(
                          text: isWholesaler
                              ? l10n.productPriceWithUnit(
                                  _fmt(wsPrice ?? price),
                                  _quantityUnitLabel(),
                                )
                              : '₹${_fmt(price)}',
                          style: AppFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isWholesaler
                                ? _specialAmountWholesale
                                : _blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (disc > 0) const SizedBox(width: 8),
                if (disc > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 14,
                          color: _green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.commonPercentOff('$disc'),
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            PendingPriceChangeNotice(
              pendingPriceChange: pendingPriceChange is Map<String, dynamic>
                  ? pendingPriceChange
                  : null,
              primaryColor: _txtSec,
              accentColor: const Color(0xFFC2410C),
              backgroundColor: const Color(0xFFFFF7ED),
            ),
          ],
          const SizedBox(height: 12),
          // Live Purchase Counter
          Builder(
            builder: (context) {
              final pMin =
                  (_product!['purchaseCountMin'] as num?)?.toInt() ?? 0;
              final pMax =
                  (_product!['purchaseCountMax'] as num?)?.toInt() ?? 0;
              if (pMin <= 0 && pMax <= 0) return const SizedBox.shrink();
              final effectiveMax = pMax > pMin ? pMax : pMin;
              final dayOfYear = DateTime.now()
                  .difference(DateTime(DateTime.now().year))
                  .inDays;
              final productIdHash = widget.productId.toString().hashCode.abs();
              final seed = productIdHash + dayOfYear;
              final range = effectiveMax - pMin;
              final count = range > 0 ? pMin + (seed % (range + 1)) : pMin;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.productSoldLast24h(count),
                        style: AppFonts.jakarta(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Delivery info and icons
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: _txtSec),
              const SizedBox(width: 4),
              Icon(Icons.storefront_outlined, size: 14, color: _txtSec),
              const SizedBox(width: 4),
              Icon(Icons.local_shipping_outlined, size: 14, color: _txtSec),
              const SizedBox(width: 8),
              Text(
                l10n.productDeliveryWithin5Days,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  color: _txtSec,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                inStock ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: inStock ? _green : _red,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  inStock ? l10n.commonInStock : l10n.commonOutOfStock,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: inStock ? _green : _red,
                  ),
                ),
              ),
              Text(
                l10n.productInclTaxes,
                style: AppFonts.jakarta(fontSize: 12, color: _txtMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppFonts.jakarta(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ── SPECIFICATIONS ──
  List<Map<String, dynamic>> get _productLabels {
    final raw = _product?['labels'];
    if (raw is! List) return const [];
    final labels = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    labels.sort((a, b) {
      final aOrder = (a['order'] as num?)?.toInt() ?? 0;
      final bOrder = (b['order'] as num?)?.toInt() ?? 0;
      return aOrder.compareTo(bOrder);
    });
    return labels;
  }

  Widget _productLabelsSection() {
    final labels = _productLabels;
    if (labels.isEmpty) return const SizedBox.shrink();

    // Show max 5 labels
    final displayLabels = labels.take(5).toList();
    final labelCount = displayLabels.length;

    // Gap adapts based on label count (smaller gap for more labels)
    final gap = labelCount >= 4 ? 6.0 : (labelCount >= 3 ? 8.0 : 10.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalGaps = (labelCount - 1) * gap;
          final availableWidth = constraints.maxWidth - totalGaps;
          final labelWidth = availableWidth / labelCount;
          // Fixed height for all labels
          const labelHeight = 80.0;

          return Row(
            children: displayLabels.asMap().entries.map((entry) {
              final isLast = entry.key == labelCount - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : gap),
                  child: SizedBox(
                    width: labelWidth,
                    height: labelHeight,
                    child: _buildProductLabelCard(entry.value),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildProductLabelCard(Map<String, dynamic> label) {
    final title = label['title']?.toString().trim() ?? '';
    final sourceType = label['sourceType']?.toString() == 'image'
        ? 'image'
        : 'icon';
    final imageUrl = _resolveLabelAssetUrl(label['image']?.toString() ?? '');
    final iconName = label['icon']?.toString() ?? '';

    // Light blue background matching trust badges strip
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F8),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: sourceType == 'image' && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => _labelVisualSkeleton(),
                    errorWidget: (_, __, ___) => Icon(
                      _productLabelIcon(iconName, title),
                      size: 28,
                      color: const Color(0xFF2B6F73),
                    ),
                  )
                : Icon(
                    _productLabelIcon(iconName, title),
                    size: 28,
                    color: const Color(0xFF2B6F73),
                  ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelVisualSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _resolveLabelAssetUrl(String imageUrl) {
    return ApiConfig.normalizeMediaUrl(imageUrl);
  }

  IconData _productLabelIcon(String rawIconName, String title) {
    final iconName = rawIconName.trim().toLowerCase();
    const iconMap = <String, IconData>{
      'autorenew': Icons.autorenew_rounded,
      'autorenew_rounded': Icons.autorenew_rounded,
      'assignment_return': Icons.assignment_return_rounded,
      'assignment_return_rounded': Icons.assignment_return_rounded,
      'published_with_changes': Icons.published_with_changes_rounded,
      'published_with_changes_rounded': Icons.published_with_changes_rounded,
      'verified': Icons.verified_rounded,
      'verified_rounded': Icons.verified_rounded,
      'workspace_premium': Icons.workspace_premium_rounded,
      'workspace_premium_rounded': Icons.workspace_premium_rounded,
      'inventory_2': Icons.inventory_2_rounded,
      'inventory_2_rounded': Icons.inventory_2_rounded,
      'local_shipping': Icons.local_shipping_rounded,
      'local_shipping_rounded': Icons.local_shipping_rounded,
      'support_agent': Icons.support_agent_rounded,
      'support_agent_rounded': Icons.support_agent_rounded,
      'headset_mic': Icons.headset_mic_rounded,
      'headset_mic_rounded': Icons.headset_mic_rounded,
      'shield': Icons.shield_rounded,
      'shield_rounded': Icons.shield_rounded,
      'security': Icons.security_rounded,
      'security_rounded': Icons.security_rounded,
      'payments': Icons.payments_rounded,
      'payments_rounded': Icons.payments_rounded,
      'currency_rupee': Icons.currency_rupee_rounded,
      'currency_rupee_rounded': Icons.currency_rupee_rounded,
      'check_circle': Icons.check_circle_rounded,
      'check_circle_rounded': Icons.check_circle_rounded,
    };

    if (iconMap.containsKey(iconName)) {
      return iconMap[iconName]!;
    }

    final probe = '$iconName ${title.toLowerCase()}';
    if (probe.contains('return') || probe.contains('refund')) {
      return Icons.autorenew_rounded;
    }
    if (probe.contains('quality') || probe.contains('assurance')) {
      return Icons.verified_rounded;
    }
    if (probe.contains('delivery') || probe.contains('dispatch')) {
      return Icons.inventory_2_rounded;
    }
    if (probe.contains('support') || probe.contains('assist')) {
      return Icons.headset_mic_rounded;
    }
    if (probe.contains('protect') || probe.contains('secure')) {
      return Icons.shield_rounded;
    }
    if (probe.contains('trust') || probe.contains('safe')) {
      return Icons.check_circle_rounded;
    }
    return Icons.verified_user_rounded;
  }

  Widget _specsSection(AppLocalizations l10n) {
    final displayCount = _specs.length > 4 ? 4 : _specs.length;
    final hasMore = _specs.length > 4;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.productSpecifications,
                  style: AppFonts.jakarta(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _txt,
                  ),
                ),
              ),
              if (_specs.isNotEmpty)
                Text(
                  l10n.commonItemsCount(_specs.length),
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _txtMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayCount,
            separatorBuilder: (_, __) => Divider(
              color: _border.withOpacity(0.4),
              height: 24,
              thickness: 0.8,
            ),
            itemBuilder: (context, i) {
              final spec = _specs[i];
              String key = spec['key']?.toString() ?? '';
              final val = spec['value']?.toString() ?? '';
              bool isGeneric = key.toLowerCase().startsWith('feature_');

              return Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: _blue, size: 14),
                  const SizedBox(width: 16),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          color: _txt,
                          height: 1.3,
                        ),
                        children: [
                          if (!isGeneric && key.isNotEmpty)
                            TextSpan(
                              text: '$key: ',
                              style: AppFonts.jakarta(
                                fontWeight: FontWeight.w600,
                                color: _txtMuted,
                                fontSize: 13,
                              ),
                            ),
                          TextSpan(
                            text: val,
                            style: AppFonts.jakarta(
                              fontWeight: FontWeight.w700,
                              color: _txt,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (hasMore) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _openSpecsSheet(l10n),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.productViewAllSpecifications,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: _blue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openSpecsSheet(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    l10n.productSpecifications,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _txt,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.commonItemsCount(_specs.length),
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _txtSec,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                itemCount: _specs.length,
                separatorBuilder: (_, __) =>
                    Divider(color: _border.withOpacity(0.5), height: 1),
                itemBuilder: (ctx, i) {
                  final spec = _specs[i];
                  final key = spec['key']?.toString() ?? '';
                  final val = spec['value']?.toString() ?? '';
                  bool isGeneric = key.toLowerCase().startsWith('feature_');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: _blue,
                          size: 14,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                color: _txt,
                              ),
                              children: [
                                if (!isGeneric && key.isNotEmpty)
                                  TextSpan(
                                    text: '$key: ',
                                    style: AppFonts.jakarta(
                                      fontWeight: FontWeight.w600,
                                      color: _txtSec,
                                      fontSize: 13,
                                    ),
                                  ),
                                TextSpan(
                                  text: val,
                                  style: AppFonts.jakarta(
                                    fontWeight: FontWeight.w700,
                                    color: _txt,
                                    fontSize: 14,
                                  ),
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
    );
  }

  // -- NEGOTIATE CARD --
  Widget _negotiateCard(
    String name,
    dynamic price,
    dynamic wsPrice,
    dynamic minQty,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.productBulkNegotiation,
                      style: AppFonts.jakarta(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.productBulkNegotiationSubtitle,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (wsPrice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.productWholesaleLabel,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    l10n.commonPricePerUnit(_fmt(wsPrice)),
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () =>
                _openNegotiateSheet(name, price, wsPrice, minQty, l10n),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_quote_outlined, size: 18, color: _violet),
                  const SizedBox(width: 8),
                  Text(
                    l10n.productSendRequirement,
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _violet,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ALL IMAGES ──
  Widget _allImagesSection(String name, AppLocalizations l10n) {
    if (_imagesData.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.productGallery,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _txt,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _imagesData.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final data = _imagesData[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppImage(
                  imageUrl: data['url']!,
                  blurHash: data['blurHash'],
                  category: _product?['category']?.toString() ?? '',
                  name: name,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── DESCRIPTION ──
  Widget _descSection(String description, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.productDescription,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _txt,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description.isNotEmpty
                ? (_descExpanded
                      ? description
                      : (description.length > 200
                            ? '${description.substring(0, 200)}...'
                            : description))
                : l10n.productNoDescription,
            style: AppFonts.jakarta(
              fontSize: 14,
              color: description.isNotEmpty ? _txtSec : _txtMuted,
              height: 1.7,
              fontStyle: description.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
          if (_bullets.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...(_descExpanded ? _bullets : _bullets.take(3)).map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _txt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (description.length > 200 || _bullets.length > 3) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(
                _descExpanded ? l10n.productShowLess : l10n.productReadMore,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── VIDEO (lazy) ──
  Widget _videoSection(AppLocalizations l10n) {
    final url = _product?['videoUrl']?.toString() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    final vid = YoutubePlayer.convertUrlToId(url);
    if (vid == null) return const SizedBox.shrink();

    if (!_videoReady) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () {
            _initYoutube();
            setState(() => _videoReady = true);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://img.youtube.com/vi/$vid/hqdefault.jpg',
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 200, color: _bg),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      color: _bg,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: _txtMuted,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_filled,
                            color: Color(0xFFFF0000),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.productDemoVideo,
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
        ),
      );
    }
    if (_ytCtrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: YoutubePlayer(
              controller: _ytCtrl!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: _blue,
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFFFF0000),
                handleColor: Color(0xFFFF0000),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _openFullscreenVideo,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- SHIPPING --
  // ── RELATED PRODUCTS ──
  Widget _relatedProductsSection(AppLocalizations l10n) {
    if (_isRelatedLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    if (_relatedProducts.isEmpty) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      key: ValueKey(_bgKey),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 10), // Slow drift
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(math.sin(value * 2 * math.pi), -1),
              end: Alignment(-math.sin(value * 2 * math.pi), 1),
              colors: const [
                Color(0xFFF0FDFA), // Sky Blue 50
                Color(0xFFDBEAFE), // Sky Blue 100
                Color(0xFFF0FDFA),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  l10n.productRelatedProducts,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1200
                      ? 6
                      : constraints.maxWidth >= 900
                      ? 5
                      : constraints.maxWidth >= 600
                      ? 4
                      : constraints.maxWidth >= 370
                      ? 3
                      : 2;
                  const horizontalPadding = 16.0;
                  const spacing = 8.0;
                  final cardWidth =
                      (constraints.maxWidth -
                          (horizontalPadding * 2) -
                          (spacing * (columns - 1))) /
                      columns;
                  final cardHeight = columns == 2 ? 244.0 : 220.0;

                  return SizedBox(
                    height: cardHeight,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: _relatedProducts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: spacing),
                      itemBuilder: (context, index) {
                        final item = Map<String, dynamic>.from(
                          _relatedProducts[index] as Map,
                        );
                        final pid =
                            item['id']?.toString() ??
                            item['_id']?.toString() ??
                            '';
                        final images = item['images'];
                        final firstImage = images is List && images.isNotEmpty
                            ? images.first
                            : null;
                        final image =
                            (item['primaryImage'] ??
                                    item['image'] ??
                                    item['imageUrl'] ??
                                    (firstImage is Map
                                        ? firstImage['url']
                                        : firstImage) ??
                                    '')
                                .toString();
                        final nameHindi = item['nameHindi']?.toString() ?? '';
                        final nameEnglish = item['name']?.toString() ?? '';
                        final displayName = localizedName(context, item);
                        final brand = (item['brand'] ?? item['category'] ?? '')
                            .toString();
                        final price = catalogPriceForAudience(
                          item,
                          isCustomerPreview: ref.read(guestModeProvider),
                        );
                        final mrp = item['mrp'] ?? item['originalPrice'] ?? 0;
                        final hasMrp =
                            mrp is num &&
                            price is num &&
                            mrp > 0 &&
                            mrp != price;
                        final discount = hasMrp
                            ? (((mrp - price) / mrp) * 100).round()
                            : 0;
                        final stock = item['stock'] ?? 0;
                        final inStock = stock is num && stock > 0;
                        final rating =
                            item['averageRating'] ?? item['rating'] ?? 4.5;
                        final reviewCount =
                            item['ratingCount'] ??
                            item['reviewCount'] ??
                            item['reviews'] ??
                            0;
                        final isWishlisted = ref
                            .watch(wishlistProvider)
                            .contains(pid);

                        String? badgeLabel;
                        Color? badgeColor;
                        if (item['isHot'] == true ||
                            item['badge']?.toString().contains('HOT') == true) {
                          badgeLabel = l10n.productBadgeHot;
                          badgeColor = _red;
                        } else if (discount > 0) {
                          badgeLabel = l10n.productBadgeSale;
                          badgeColor = _green;
                        } else if (item['isNew'] == true) {
                          badgeLabel = l10n.productBadgeNew;
                          badgeColor = _blue;
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/product/$pid'),
                            borderRadius: BorderRadius.circular(11),
                            child: Container(
                              width: cardWidth,
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: const Color(0xFFE1E8F2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF334155,
                                    ).withOpacity(0.07),
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
                                          Container(
                                            color: const Color(0xFFFAFCFF),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              8,
                                              8,
                                              8,
                                              4,
                                            ),
                                            child: AppImage(
                                              imageUrl: image,
                                              blurHash:
                                                  (item['primaryBlurHash'] ??
                                                          item['blurHash'])
                                                      ?.toString(),
                                              category:
                                                  item['category']
                                                      ?.toString() ??
                                                  '',
                                              name: nameEnglish,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          if (!inStock)
                                            Container(
                                              color: Colors.white.withOpacity(
                                                0.65,
                                              ),
                                              alignment: Alignment.center,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: badgeColor,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
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
                                              color: Colors.white.withOpacity(
                                                0.94,
                                              ),
                                              shape: const CircleBorder(),
                                              child: InkWell(
                                                onTap: () {
                                                  if (ref.read(
                                                    guestModeProvider,
                                                  )) {
                                                    _showGuestModePopup(
                                                      l10n.productWishlistDisabledPreview,
                                                    );
                                                    return;
                                                  }
                                                  ref
                                                      .read(
                                                        wishlistProvider
                                                            .notifier,
                                                      )
                                                      .toggle(
                                                        WishlistItem(
                                                          productId: pid,
                                                          name: nameEnglish,
                                                          image: image,
                                                          price: price is num
                                                              ? price.toDouble()
                                                              : 0,
                                                          mrp: hasMrp
                                                              ? (mrp as num)
                                                                    .toDouble()
                                                              : null,
                                                          category:
                                                              item['category']
                                                                  ?.toString(),
                                                          nameHindi: nameHindi,
                                                          blurHash:
                                                              (item['primaryBlurHash'] ??
                                                                      item['blurHash'])
                                                                  ?.toString(),
                                                        ),
                                                      );
                                                },
                                                customBorder:
                                                    const CircleBorder(),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    5,
                                                  ),
                                                  child: Icon(
                                                    isWishlisted
                                                        ? Icons.favorite_rounded
                                                        : Icons
                                                              .favorite_border_rounded,
                                                    size: 15,
                                                    color: isWishlisted
                                                        ? _red
                                                        : _txtMuted,
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
                                    padding: const EdgeInsets.fromLTRB(
                                      7,
                                      6,
                                      7,
                                      8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          brand.isEmpty
                                              ? l10n.productBrandFallback
                                              : brand,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.jakarta(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: _blue,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        SizedBox(
                                          height: 30,
                                          child: Text(
                                            displayName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.jakarta(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _txt,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 12,
                                              color: _amber,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '$rating',
                                              style: AppFonts.jakarta(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: _txtSec,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                '($reviewCount)',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppFonts.jakarta(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w500,
                                                  color: _txtMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      '₹${_fmt(price)}',
                                                      style: AppFonts.jakarta(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: _txt,
                                                      ),
                                                    ),
                                                  ),
                                                  if (hasMrp)
                                                    Text(
                                                      '₹${_fmt(mrp)}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: AppFonts.jakarta(
                                                        fontSize: 7.5,
                                                        color: _txtMuted,
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            GestureDetector(
                                              onTap: inStock
                                                  ? () {
                                                      if (ref.read(
                                                        guestModeProvider,
                                                      )) {
                                                        _showGuestModePopup(
                                                          l10n.productAddToCartDisabledPreview,
                                                        );
                                                        return;
                                                      }
                                                      final minimumQuantity =
                                                          _minimumQuantity(
                                                            item,
                                                          );
                                                      _trackEvent(
                                                        'related_add_to_cart_$pid',
                                                      );
                                                      ref
                                                          .read(
                                                            cartProvider
                                                                .notifier,
                                                          )
                                                          .addItem(
                                                            productId: pid,
                                                            name: nameEnglish,
                                                            nameHindi:
                                                                item['nameHindi']
                                                                    ?.toString(),
                                                            brand: item['brand']
                                                                ?.toString(),
                                                            category:
                                                                item['category']
                                                                    ?.toString(),
                                                            minWholesaleQuantity:
                                                                minimumQuantity,
                                                            price: price is num
                                                                ? price
                                                                      .toDouble()
                                                                : 0,
                                                            image: image,
                                                            quantity:
                                                                minimumQuantity,
                                                            stock: stock
                                                                .toInt(),
                                                          );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            l10n.productAddedToCart,
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                seconds: 1,
                                                              ),
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: inStock
                                                      ? _blue
                                                      : const Color(0xFFCBD5E1),
                                                  borderRadius:
                                                      BorderRadius.circular(7),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .shopping_cart_outlined,
                                                      color: Colors.white,
                                                      size: 11,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      l10n.productAddShort,
                                                      style: AppFonts.jakarta(
                                                        fontSize: 8.5,
                                                        fontWeight:
                                                            FontWeight.w800,
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
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {
            _bgKey++;
          });
        }
      },
    );
  }

  Future<void> _fetchRelatedProducts() async {
    try {
      debugPrint('Fetching related products for: ${widget.productId}');
      setState(() => _isRelatedLoading = true);
      final r = await _dio.get('/products/${widget.productId}/related');
      debugPrint('Related products response: ${r.data}');
      if (mounted) {
        setState(() {
          _relatedProducts = r.data['data'] ?? [];
          _isRelatedLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching related products: $e');
      if (mounted) {
        setState(() => _isRelatedLoading = false);
      }
    }
  }

  Widget _shippingSection(AppLocalizations l10n) {
    final terms =
        _product?['shippingTerms']?.toString() ??
        l10n.productShippingTermsDefault;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _shippingOpen = !_shippingOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: _txtSec,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.productShippingReturns,
                      style: AppFonts.jakarta(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _txt,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _shippingOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.chevron_right,
                      color: _txtMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                terms,
                style: AppFonts.jakarta(
                  fontSize: 13,
                  color: _txtSec,
                  height: 1.6,
                ),
              ),
            ),
            crossFadeState: _shippingOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  // -- BOTTOM BAR --
  Widget _bottomBar(
    String name,
    dynamic price,
    dynamic mrp,
    dynamic stock,
    bool inStock,
    double bp,
    bool negEnabled,
    dynamic wsPrice,
    dynamic minQty,
    AppLocalizations l10n,
  ) {
    final unitLabel = _quantityUnitLabel();
    final isWholesaler = ref.watch(effectiveIsWholesalerProvider);
    final minimumQuantity = minQty is num
        ? minQty.toInt()
        : int.tryParse(minQty?.toString() ?? '') ?? 1;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bp + 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWholesaler && inStock)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l10n.productMinWholesaleQuantity('$minimumQuantity'),
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _txtSec,
                  ),
                ),
              ),
            if (inStock)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(
                      l10n.productSelectQuantity,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _txt,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          _qtyBtn(
                            Icons.remove,
                            () => _setQuantity(_quantity - 1, stock),
                          ),
                          Container(
                            width: 46,
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _quantityController,
                              focusNode: _quantityFocusNode,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _txt,
                              ),
                              onChanged: (value) =>
                                  _onQuantityTextChanged(value, stock),
                              onSubmitted: (_) => _commitQuantityInput(stock),
                              onTapOutside: (_) => _quantityFocusNode.unfocus(),
                            ),
                          ),
                          _qtyBtn(
                            Icons.add,
                            () => _setQuantity(_quantity + 1, stock),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        unitLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _txtSec,
                        ),
                      ),
                    ),
                    if (stock != null) ...[
                      const SizedBox(width: 8),
                      _buildStockStatus(stock, l10n),
                    ],
                  ],
                ),
              ),
            if (isWholesaler)
              GestureDetector(
                onTap: inStock
                    ? () => _openNegotiateSheet(
                        name,
                        price,
                        wsPrice,
                        minQty,
                        l10n,
                      )
                    : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: inStock ? _blue : _txtMuted,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: inStock
                        ? [
                            BoxShadow(
                              color: _blue.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.productSendRequirement,
                              style: AppFonts.jakarta(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              l10n.productOnlyPlatformCanConfirm,
                              style: AppFonts.jakarta(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!isWholesaler)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: inStock && !_addedToCart
                          ? () {
                              // Check guest mode
                              if (ref.read(guestModeProvider)) {
                                _showGuestModePopup(
                                  l10n.productAddToCartDisabledPreview,
                                );
                                return;
                              }

                              final img = _images.isNotEmpty
                                  ? _images[0]
                                  : null;
                              ref
                                  .read(cartProvider.notifier)
                                  .addItem(
                                    productId: widget.productId,
                                    name: _product?['name']?.toString() ?? name,
                                    nameHindi: _product?['nameHindi']
                                        ?.toString(),
                                    image: img,
                                    price: (price is int)
                                        ? price.toDouble()
                                        : (price as num?)?.toDouble() ?? 0,
                                    mrp: (mrp is int)
                                        ? mrp.toDouble()
                                        : (mrp as num?)?.toDouble(),
                                    minWholesaleQuantity: minQty is num
                                        ? minQty.toInt()
                                        : int.tryParse(
                                                minQty?.toString() ?? '',
                                              ) ??
                                              1,
                                    quantity: _quantity,
                                    stock: stock is int ? stock : 99,
                                  );
                              _trackEvent('cart_add');
                              setState(() => _addedToCart = true);
                              _cartBounce.forward().then(
                                (_) => _cartBounce.reverse(),
                              );
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() => _addedToCart = false);
                                }
                              });
                            }
                          : null,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _border),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _addedToCart
                                    ? Icons.check_rounded
                                    : Icons.shopping_cart_outlined,
                                size: 22,
                                color: _txt,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.productAddToCart,
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _txt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: inStock && !_isBuyNowLoading
                          ? () async {
                              // Check guest mode
                              if (ref.read(guestModeProvider)) {
                                _showGuestModePopup(
                                  l10n.productBuyNowDisabledPreview,
                                );
                                return;
                              }

                              setState(() => _isBuyNowLoading = true);
                              try {
                                final img = _images.isNotEmpty
                                    ? _images[0]
                                    : null;
                                final productPrice = (price is int)
                                    ? price.toDouble()
                                    : (price as num?)?.toDouble() ?? 0;
                                final productMrp = (mrp is int)
                                    ? mrp.toDouble()
                                    : (mrp as num?)?.toDouble();
                                final productStock = stock is int ? stock : 99;

                                if (!mounted) return;
                                context.push(
                                  '/buy-now',
                                  extra: {
                                    'productId': widget.productId,
                                    'productName': name,
                                    'productImage': img,
                                    'price': productPrice,
                                    'mrp': productMrp,
                                    'quantity': _quantity,
                                    'stock': productStock,
                                  },
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isBuyNowLoading = false);
                                }
                              }
                            }
                          : null,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: inStock && !_isBuyNowLoading
                              ? _blue
                              : _txtMuted,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: inStock
                              ? [
                                  BoxShadow(
                                    color: _blue.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _isBuyNowLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  l10n.productBuyNow,
                                  style: AppFonts.jakarta(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatus(dynamic stock, AppLocalizations l10n) {
    final stockCount = stock is int ? stock : 99;

    String label;
    Color color;

    if (stockCount <= 0) {
      label = l10n.commonOutOfStock;
      color = _red;
    } else {
      label = l10n.commonInStock;
      color = _green;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------
  // NEGOTIATE SHEET (native Flutter animation)
  // ------------------------------------------
  void _openNegotiateSheet(
    String productName,
    dynamic retailPrice,
    dynamic wsPrice,
    dynamic minQty,
    AppLocalizations l10n,
  ) {
    final rp = retailPrice != null
        ? (retailPrice is int
              ? retailPrice.toDouble()
              : (retailPrice as num).toDouble())
        : 0.0;
    final wp = wsPrice != null
        ? (wsPrice is int ? wsPrice.toDouble() : (wsPrice as num).toDouble())
        : rp * 0.85;
    final minQ = minQty is int ? minQty : 10;
    int step = 1;
    // Use quantity already selected on product page — don't ask twice.
    int qty = _quantity >= minQ ? _quantity : minQ;
    double target = wp;
    final qtyCtrl = TextEditingController(text: '$qty');
    final priceCtrl = TextEditingController(text: _fmt(target));
    final messageCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget content;
          if (step == 0) {
            content = _sheetStep1(
              qty,
              qtyCtrl,
              minQ,
              (q) => setSheet(() => qty = q),
              () => setSheet(() => step = 1),
              l10n,
            );
          } else if (step == 1) {
            content = _sheetStep2(
              qty,
              target,
              priceCtrl,
              messageCtrl,
              rp,
              (p) => setSheet(() => target = p),
              () => setSheet(() => step = 0),
              () => setSheet(() => step = 2),
              l10n,
            );
          } else {
            content = _sheetStep3(
              productName,
              qty,
              target,
              rp,
              () => setSheet(() => step = 1),
              () {
                Navigator.of(ctx).pop();
                _submitNegotiation(
                  qty,
                  target,
                  message: messageCtrl.text.trim(),
                );
              },
              l10n,
              message: messageCtrl.text.trim(),
            );
          }

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(ctx).padding.bottom + 20,
                ),
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
                          color: _border,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    _stepDots(step),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(key: ValueKey(step), child: content),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      qtyCtrl.dispose();
      priceCtrl.dispose();
      messageCtrl.dispose();
    });
  }

  Widget _stepDots(int cur) {
    return Row(
      children: List.generate(3, (i) {
        final done = i < cur;
        final active = i == cur;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(height: 2, color: done ? _blue : _border),
                ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active ? _blue : _bg,
                  border: Border.all(
                    color: done || active ? _blue : _border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '${i + 1}',
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : _txtMuted,
                          ),
                        ),
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(height: 2, color: done ? _blue : _border),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: _blue),
      ),
    );
  }

  // Step 1: Quantity
  Widget _sheetStep1(
    int qty,
    TextEditingController ctrl,
    int minQ,
    ValueChanged<int> onQty,
    VoidCallback onNext,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _violet.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_outlined, color: _violet, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.productHowManyUnits,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _txt,
                    ),
                  ),
                  Text(
                    l10n.productHowManyUnitsSubtitle,
                    style: AppFonts.jakarta(fontSize: 13, color: _txtSec),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.productQuickSelect,
          style: AppFonts.jakarta(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _txtSec,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [10, 25, 50, 100].map((q) {
            final sel = qty == q;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  onQty(q);
                  ctrl.text = '$q';
                },
                child: Container(
                  margin: EdgeInsets.only(right: q == 100 ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? _blue : _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? _blue : _border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$q',
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : _txt,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final p = int.tryParse(v);
              if (p != null) onQty(p);
            },
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _txt,
            ),
            decoration: InputDecoration(
              hintText: l10n.productCustomQuantity,
              hintStyle: AppFonts.jakarta(color: _txtMuted),
              prefixIcon: Icon(Icons.edit_outlined, color: _txtSec, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: qty >= 1 ? onNext : null,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: qty >= 1 ? _blue : _border,
              borderRadius: BorderRadius.circular(14),
              boxShadow: qty >= 1
                  ? [
                      BoxShadow(
                        color: _blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.productContinueToPricing,
                  style: AppFonts.jakarta(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: qty >= 1 ? Colors.white : _txtMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: qty >= 1 ? Colors.white : _txtMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Step 2: Price
  Widget _sheetStep2(
    int qty,
    double target,
    TextEditingController ctrl,
    TextEditingController messageCtrl,
    double rp,
    ValueChanged<double> onPrice,
    VoidCallback onBack,
    VoidCallback onNext,
    AppLocalizations l10n,
  ) {
    final savings = (rp - target) * qty;
    final pct = rp > 0 ? ((rp - target) / rp * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.payments_outlined, color: _blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.productYourExpectedPrice,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _txt,
                    ),
                  ),
                  Text(
                    l10n.productQtyRetailSummary(qty, _fmt(rp)),
                    style: AppFonts.jakarta(fontSize: 13, color: _txtSec),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          l10n.productTargetPricePerUnit,
          style: AppFonts.jakarta(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _txtSec,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final p = double.tryParse(v.replaceAll(',', ''));
              if (p != null) onPrice(p);
            },
            style: AppFonts.jakarta(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _txt,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: AppFonts.jakarta(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _blue,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.productRequirementMessageLabel,
          style: AppFonts.jakarta(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _txtSec,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: messageCtrl,
            maxLines: 3,
            minLines: 2,
            maxLength: _negotiationMessageMaxLength,
            textInputAction: TextInputAction.newline,
            style: AppFonts.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _txt,
            ),
            decoration: InputDecoration(
              hintText: l10n.productRequirementMessageHint,
              hintStyle: AppFonts.jakarta(fontSize: 13, color: _txtMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (target > 0 && target < rp) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.savings_outlined, color: _green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.productSaveAmount(_fmt(savings), '$pct', '$qty'),
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Center(
                    child: Text(
                      l10n.commonBack,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _txt,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: target > 0 ? onNext : null,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: target > 0 ? _blue : _border,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: target > 0
                        ? [
                            BoxShadow(
                              color: _blue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      l10n.productReviewRequirement,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: target > 0 ? Colors.white : _txtMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Step 3: Review
  Widget _sheetStep3(
    String productName,
    int qty,
    double target,
    double rp,
    VoidCallback onBack,
    VoidCallback onSubmit,
    AppLocalizations l10n, {
    String message = '',
  }) {
    final total = target * qty;
    final saved = (rp * qty) - total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.fact_check_outlined, color: _green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.productReviewRequirement,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _txt,
                    ),
                  ),
                  Text(
                    l10n.productConfirmBeforeSubmit,
                    style: AppFonts.jakarta(fontSize: 13, color: _txtSec),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _reviewLine(l10n.productReviewProduct, productName),
              _divider(),
              _reviewLine(l10n.commonQuantity, l10n.commonUnitsCount(qty)),
              _divider(),
              _reviewLine(
                l10n.productYourExpectedPrice,
                l10n.commonPricePerUnit(_fmt(target)),
              ),
              _divider(),
              _reviewLine(
                l10n.productRetailPrice,
                l10n.commonPricePerUnit(_fmt(rp)),
                muted: true,
              ),
              if (message.isNotEmpty) ...[
                _divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.productRequirementMessageReview,
                    style: AppFonts.jakarta(fontSize: 14, color: _txtSec),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    message,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _txt,
                    ),
                  ),
                ),
              ],
              _divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.commonTotal,
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _txt,
                    ),
                  ),
                  Text(
                    '₹${_fmt(total)}',
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (saved > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_down_rounded, color: _green, size: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.productYouSaveVsRetail(_fmt(saved)),
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _amber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _amber.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _amber, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.productBulkUpiNote,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Center(
                    child: Text(
                      l10n.commonEdit,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _txt,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onSubmit,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _violet.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.productSubmitQuote,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewLine(String label, String value, {bool muted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppFonts.jakarta(fontSize: 14, color: _txtSec)),
        Flexible(
          child: Text(
            value,
            style: AppFonts.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: muted ? _txtMuted : _txt,
              decoration: muted ? TextDecoration.lineThrough : null,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
    height: 1,
    color: _border.withOpacity(0.5),
    margin: const EdgeInsets.symmetric(vertical: 10),
  );

  /// Maximum length of the optional buyer message sent with a requirement.
  static const int _negotiationMessageMaxLength = 500;

  Future<void> _submitNegotiation(
    int qty,
    double pricePerUnit, {
    String message = '',
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final trimmedMessage = message.trim();
      final response = await apiClient.post(
        '/negotiations',
        data: {
          'productId': widget.productId,
          'quantity': qty,
          'pricePerUnit': pricePerUnit,
          if (trimmedMessage.isNotEmpty)
            'message': trimmedMessage.length > _negotiationMessageMaxLength
                ? trimmedMessage.substring(0, _negotiationMessageMaxLength)
                : trimmedMessage,
        },
      );

      if (response.data['success'] == true && mounted) {
        final negNumber = response.data['data']?['negotiationNumber'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.productQuotationSubmitted(qty, '$negNumber'),
                    style: AppFonts.jakarta(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: _green,
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
          e.response?.data?['message']?.toString() ??
          context.l10n.productNegotiationSubmitFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: AppFonts.jakarta(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: _red,
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
          content: Text(context.l10n.productSomethingWentWrongDetail('$e')),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _trustBadgesStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(height: 36, child: _ProductTrustBadgeMarquee()),
    );
  }
}

// ------------------------------------------
// FULLSCREEN VIDEO PAGE (overlay)
// ------------------------------------------
class _FullscreenVideoPage extends StatefulWidget {
  final String videoId;
  const _FullscreenVideoPage({required this.videoId});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        showLiveFullscreenButton: false,
        hideControls: false,
        forceHD: true,
      ),
    );
    // Lock to landscape for the fullscreen video page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller.dispose();
    // Restore portrait orientation and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFF0F766E),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFFFF0000),
                handleColor: Color(0xFFFF0000),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------
// TRUST BADGE MARQUEE for product detail
// ------------------------------------------
class _ProductTrustBadgeMarquee extends StatefulWidget {
  @override
  State<_ProductTrustBadgeMarquee> createState() =>
      _ProductTrustBadgeMarqueeState();
}

class _ProductTrustBadgeMarqueeState extends State<_ProductTrustBadgeMarquee> {
  late final ScrollController _sc;
  Timer? _timer;

  static const Color _blue = Color(0xFF0F766E);
  static const Color _txtSec = Color(0xFF64748B);

  static final List<(IconData, String Function(AppLocalizations))> _badgeSet = [
    (Icons.verified_user_rounded, (l10n) => l10n.productTrustVerifiedProducts),
    (Icons.star_rounded, (l10n) => l10n.productTrustReviews),
    (Icons.support_agent_rounded, (l10n) => l10n.productTrustSupport),
    (Icons.local_shipping_rounded, (l10n) => l10n.productTrustFastDelivery),
    (Icons.shield_rounded, (l10n) => l10n.productTrustSecurePayments),
    (Icons.autorenew_rounded, (l10n) => l10n.productTrustEasyReturns),
  ];
  // The strip repeats the set twice so the marquee can loop.
  static final List<(IconData, String Function(AppLocalizations))> _badges = [
    ..._badgeSet,
    ..._badgeSet,
  ];

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
  }

  void _startScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_sc.hasClients) return;
      final max = _sc.position.maxScrollExtent;
      final cur = _sc.offset;
      if (cur >= max) {
        _sc.jumpTo(0);
      } else {
        _sc.jumpTo(cur + 0.8);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _blue.withOpacity(0.04),
      child: ListView.builder(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _badges.length,
        itemBuilder: (_, i) {
          final item = _badges[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 16, color: _blue),
                const SizedBox(width: 6),
                Text(
                  item.$2(context.l10n),
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
