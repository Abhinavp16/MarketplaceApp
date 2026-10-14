import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../widgets/pending_price_change_notice.dart';
import '../../widgets/verified_seller_badge.dart';
import '../../widgets/ui/ui.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/coming_soon.dart';
import '../../core/utils/packing.dart';
import '../../core/utils/product_share.dart';
import '../../l10n/api_error_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/pack_text.dart';
import 'pdp_widgets.dart';
import '../../widgets/coming_soon_badge.dart';
import '../../widgets/delivery_note.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? heroTag;

  /// Photo the tapped card showed. The loading layout shows it where the
  /// gallery will be, so the shared-photo flight has somewhere to land
  /// before the product has loaded.
  final String? heroImageUrl;
  final String? heroBlurHash;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.heroTag,
    this.heroImageUrl,
    this.heroBlurHash,
  });

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
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _cartSnackBar;
  int _quantity = 1;
  bool _descExpanded = false;
  // _isFav removed â€“ now using wishlistProvider
  bool _shippingOpen = false;
  bool _isBuyNowLoading = false;
  bool _isNotifyLoading = false;

  /// The product's database id. The page may be opened by slug (a shared
  /// link, `/product/<slug>`); once loaded, calls that need the id use it.
  String get _productId =>
      (_product?['_id'] ?? _product?['id'])?.toString() ?? widget.productId;
  YoutubePlayerController? _ytCtrl;
  bool _videoReady = false;
  Map<String, dynamic>? _product;
  List<dynamic> _relatedProducts = [];
  bool _isLoading = true;
  bool _isRelatedLoading = false;
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
              // The page was closed before this (e.g. related products or
              // tracking) request started: drop it.
              if (!mounted) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.cancel,
                  ),
                );
              }
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
    // The cart message belongs to this page; don't carry it to the next one.
    _cartSnackBar?.close();
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

  // Quantities are in pieces or meters. Wholesalers buy pack products
  // (packets, coils, bundles) in whole packs, so their quantity box counts
  // packs; customers buy loose pieces / cut lengths (see packing.dart).
  int _minimumQuantity([Map<String, dynamic>? product]) {
    if (!ref.read(effectiveIsWholesalerProvider)) {
      return customerMinimumOf(product ?? _product);
    }
    return wholesaleMinimumOf(product ?? _product);
  }

  int _quantityStep([Map<String, dynamic>? product]) {
    if (!ref.read(effectiveIsWholesalerProvider)) return 1;
    return packSizeOf(product ?? _product);
  }

  void _showQuantity(int pieces, [Map<String, dynamic>? product]) {
    _quantityController.text = '${pieces ~/ _quantityStep(product)}';
    _quantityController.selection = TextSelection.collapsed(
      offset: _quantityController.text.length,
    );
  }

  void _setQuantity(int value, dynamic stock) {
    final step = _quantityStep();
    final minimum = _minimumQuantity();
    final limit = math.max(minimum, _stockLimit(stock) ~/ step * step);
    final clamped = value.clamp(minimum, limit).toInt();
    final next = math.max(minimum, clamped ~/ step * step);
    setState(() => _quantity = next);
    _showQuantity(next);
  }

  void _commitQuantityInput(dynamic stock) {
    final parsed = int.tryParse(_quantityController.text.trim());
    _setQuantity(
      parsed == null ? _minimumQuantity() : parsed * _quantityStep(),
      stock,
    );
  }

  void _onQuantityTextChanged(String value, dynamic stock) {
    if (value.isEmpty) return;
    final parsed = int.tryParse(value);
    if (parsed == null) return;

    final pieces = parsed * _quantityStep();
    final minimum = _minimumQuantity();
    final limit = math.max(minimum, _stockLimit(stock));
    if (pieces > limit) {
      _setQuantity(limit, stock);
      return;
    }

    setState(() => _quantity = pieces < minimum ? minimum : pieces);
  }

  /// Quantity in words: "2 Bundles (1,000 m)" for pack products bought by
  /// wholesalers, "50 m" for cut lengths, otherwise "30 units".
  String _quantityText(int amount, AppLocalizations l10n) {
    if (_quantityStep() > 1) return packQuantityText(l10n, _pack, amount);
    if (isMeterProduct(_product)) {
      return contentsText(l10n, ContentUnit.meter, amount);
    }
    return l10n.commonUnitsCount(amount);
  }

  PackInfo get _pack => packInfoOf(_product);

  /// Unit the price is quoted in: pack products are priced per piece/meter.
  String _priceUnitLabel() => _pack.isPack
      ? contentUnitLabel(context.l10n, _pack.contentUnit!)
      : _quantityUnitLabel();

  String _quantityUnitLabel() {
    final l10n = context.l10n;
    if (_pack.isPack) {
      return _quantityStep() > 1
          ? packUnitLabel(l10n, _pack.packUnit!)
          : contentUnitLabel(l10n, _pack.contentUnit!);
    }
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

  /// "1 Coil (500 m) = ₹37,500" / "1 Packet (15 pieces) = ₹10,800" for pack
  /// products, from the per-meter / per-piece [price]. For a Packet whose
  /// Packing isn't a piece count, "1 Packet contains …". Null otherwise.
  String? _packetContentsLabel({dynamic price}) {
    final l10n = context.l10n;
    if (_pack.isPack) {
      return price is num
          ? packPriceText(l10n, _pack, price)
          : packQuantityText(l10n, _pack, _pack.size);
    }
    final unit =
        _product?['priceUnit'] ?? _product?['unit'] ?? _product?['uom'];
    if (!isPacketUnit(unit?.toString())) return null;
    final packing = (_product?['packing'] ?? '').toString().trim();
    if (packing.isEmpty) return null;
    final count = packingPieceCount(packing);
    return count != null
        ? l10n.productPacketContainsPieces(count)
        : l10n.productPacketContains(packing);
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

  /// Waits until this page's push transition has finished, so the shared
  /// photo lands on the loading layout before the real gallery replaces it.
  Future<void> _untilRouteSettled() async {
    if (!mounted || _heroLoadingPhoto == null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted || animation.isDismissed) {
      return;
    }
    final settled = Completer<void>();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (!settled.isCompleted) settled.complete();
      }
    }

    animation.addStatusListener(onStatus);
    await settled.future;
    animation.removeStatusListener(onStatus);
  }

  /// The card's photo for the loading layout, when a flight is expected.
  String? get _heroLoadingPhoto {
    final url = widget.heroImageUrl?.trim() ?? '';
    return widget.heroTag != null && url.isNotEmpty ? url : null;
  }

  /// A gallery page: the photo on white with a little breathing room. The
  /// loading layout uses the same widget so nothing moves when the product
  /// arrives.
  Widget _galleryPhoto({
    required String url,
    String? blurHash,
    String category = '',
    String name = '',
  }) {
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.all(12),
      child: AppImage(
        imageUrl: url,
        blurHash: blurHash,
        category: category,
        name: name,
        fit: BoxFit.contain,
        // A fixed decode size while the photo flies in from its card, with
        // the card's smaller copy shown until this sharper one is ready.
        decodeWidth: MediaQuery.sizeOf(context).width,
        previewFromSmaller: true,
      ),
    );
  }

  Future<void> _fetchProduct() async {
    try {
      final r = await _dio.get(
        '/products/${Uri.encodeComponent(widget.productId)}',
      );
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
        await _untilRouteSettled();
        if (!mounted) return;
        setState(() {
          _product = productData;
          _selectedVariantId = _resolveInitialVariantId(productData);
          _quantity = _minimumQuantity(productData);
          _showQuantity(_quantity, productData);
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
          '/products/$_productId/watch-time',
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
        '/products/$_productId/view',
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
        '/products/$_productId/event',
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

  /// Display amount with thousands separators (prices on screen only).
  String _money(dynamic value) => NumberFormatter.formatPrice(value);

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
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + media.padding.bottom),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                const SizedBox(height: 8),
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.productChooseVariantHint,
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: variants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final variantId = variant['id']?.toString();
                      final isSelected = variantId == selectedId;
                      final variantPrice =
                          variant['price'] ?? variant['retailPrice'];

                      return Pressable(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        color: isSelected
                            ? AppColors.primarySoft
                            : AppColors.surfaceLight,
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
                          duration: AppMotion.of(context, AppMotion.fast),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
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
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.primaryDeep
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      variantPrice != null
                                          ? '₹${_fmt(variantPrice)}'
                                          : l10n.productTapToSelect,
                                      style: AppText.price(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              HugeIcon(
                                icon: isSelected
                                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                                    : HugeIcons.strokeRoundedCircle,
                                size: 22,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.gray400,
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
    final bp = MediaQuery.paddingOf(context).bottom;
    final tp = MediaQuery.paddingOf(context).top;

    final String pageKey;
    final Widget page;
    if (_isLoading) {
      pageKey = 'loading';
      page = _buildLoadingPage(l10n, tp);
    } else if (_error != null || _product == null) {
      pageKey = 'error';
      page = _buildErrorPage(l10n);
    } else {
      pageKey = 'product';
      page = _buildProductPage(l10n, bp, tp);
    }
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.base),
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.exit,
      // While the loading layout fades out it still holds the shared photo,
      // so only the incoming page may join a hero flight. This builder is a
      // new closure every build, which makes the switcher re-run it for the
      // outgoing page too.
      transitionBuilder: (child, animation) => HeroMode(
        enabled: child.key == ValueKey(pageKey),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(pageKey), child: page),
    );
  }

  Widget _buildLoadingPage(AppLocalizations l10n, double tp) {
    final photo = _heroLoadingPhoto;
    // Same frame and position as the gallery in [_imageCarousel].
    final gallery = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: photo == null
          ? const AspectRatio(
              aspectRatio: 4 / 3,
              child: SkeletonShimmer(
                child: Skeleton(height: double.infinity, radius: AppRadius.lg),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Hero(
                  tag: widget.heroTag!,
                  transitionOnUserGestures: true,
                  child: _galleryPhoto(
                    url: photo,
                    blurHash: widget.heroBlurHash,
                  ),
                ),
              ),
            ),
    );
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          Semantics(
            label: l10n.productLoading,
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: tp + 60, bottom: 16),
              children: [
                gallery,
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AppCard(
                    child: SkeletonShimmer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 110, height: 12),
                          SizedBox(height: 14),
                          Skeleton(height: 20),
                          SizedBox(height: 8),
                          Skeleton(width: 180, height: 20),
                          SizedBox(height: 22),
                          Skeleton(width: 140, height: 28),
                          SizedBox(height: 10),
                          Skeleton(width: 200, height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AppCard(
                    child: SkeletonShimmer(
                      child: Column(
                        children: [
                          for (var i = 0; i < 4; i++)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Skeleton(height: 14),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Same bar as the product page, with the title still loading.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(10, tp + 6, 10, 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  AppBackButton(onPressed: () => context.pop()),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: SkeletonShimmer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 170, height: 14),
                          SizedBox(height: 6),
                          Skeleton(width: 70, height: 10),
                        ],
                      ),
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

  Widget _buildErrorPage(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: '', onBack: () => context.pop()),
      body: EmptyState(
        icon: HugeIcons.strokeRoundedAlert02,
        title: _error ?? l10n.productNotFound,
        actionLabel: l10n.commonRetry,
        tone: ChipTone.neutral,
        onAction: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _fetchProduct();
        },
      ),
    );
  }

  Widget _buildProductPage(AppLocalizations l10n, double bp, double tp) {
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
    // Room for the sticky bar at the bottom.
    final bottomContentInset = inStock ? 128.0 : 96.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _fetchProduct,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceLight,
              edgeOffset: tp + 60,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: tp + 60)),
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
      child: Container(
        padding: EdgeInsets.fromLTRB(10, tp + 6, 10, 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            AppBackButton(onPressed: () => context.pop()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  if (_isComingSoon)
                    Text(
                      l10n.comingSoonBadge,
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: comingSoonColor,
                      ),
                    )
                  else
                    _buildStockStatus(inStock ? 1 : 0, l10n, dense: true),
                ],
              ),
            ),
            const SizedBox(width: 6),
            HeaderIconButton(
              icon: HugeIcons.strokeRoundedShare08,
              tooltip: l10n.commonShare,
              onPressed: () {
                final p = _product;
                if (p == null) return;
                final pName = localizedName(
                  context,
                  p,
                  fallback: l10n.productPlaceholderProduct,
                );
                // Retail price only, and the link that opens the app.
                final shareText = productShareMessage(l10n, p, name: pName);
                SharePlus.instance.share(ShareParams(text: shareText));
              },
            ),
            const SizedBox(width: 6),
            Builder(
              builder: (ctx) {
                final isCustomerPreview = ref.watch(guestModeProvider);
                final isFav =
                    !isCustomerPreview &&
                    ref.watch(wishlistProvider).contains(_productId);
                return HeaderIconButton(
                  icon: isFav
                      ? Icons.favorite_rounded
                      : HugeIcons.strokeRoundedFavourite,
                  color: isFav ? AppColors.error : AppColors.textPrimary,
                  tooltip: isFav
                      ? l10n.uiRemoveFromWishlist
                      : l10n.uiAddToWishlist,
                  onPressed: () {
                    if (isCustomerPreview) {
                      _showGuestModePopup(l10n.productWishlistDisabledPreview);
                      return;
                    }
                    final p = _product;
                    if (p == null) return;
                    HapticFeedback.selectionClick();
                    final item = WishlistItem(
                      productId: _productId,
                      name: p['name']?.toString() ?? '',
                      image: _images.isNotEmpty ? _images.first : null,
                      price: (p['retailPrice'] ?? p['price'] ?? 0).toDouble(),
                      mrp: p['mrp'] != null
                          ? (p['mrp'] as num).toDouble()
                          : null,
                      category: p['category']?.toString(),
                      nameHindi: p['nameHindi']?.toString(),
                    );
                    ref.read(wishlistProvider.notifier).toggle(item);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── IMAGE GALLERY ──
  Future<void> _openImageViewer(String name, int index) async {
    final images = _imagesData;
    if (images.isEmpty) return;
    HapticFeedback.selectionClick();
    final shown = await Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        transitionDuration: AppMotion.of(context, AppMotion.base),
        reverseTransitionDuration: AppMotion.of(context, AppMotion.fast),
        pageBuilder: (_, _, _) => PdpImageViewer(
          images: images,
          initialIndex: index,
          category: _product?['category']?.toString() ?? '',
          name: name,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.standard),
          child: child,
        ),
      ),
    );
    // Keep the page on the photo the shopper ended on.
    if (!mounted || shown == null || shown == _imgIndex) return;
    if (_imgCtrl.hasClients) _imgCtrl.jumpToPage(shown);
  }

  Widget _imageCarousel(String name) {
    final l10n = context.l10n;
    if (_images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 48,
                color: AppColors.gray400,
              ),
            ),
          ),
        ),
      );
    }
    final images = _imagesData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _imgCtrl,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _imgIndex = i),
                    itemBuilder: (_, i) {
                      final data = images[i];
                      Widget page = _galleryPhoto(
                        url: data['url']!,
                        blurHash: data['blurHash'],
                        category: _product?['category']?.toString() ?? '',
                        name: name,
                      );
                      if (i == 0 && widget.heroTag != null) {
                        page = Hero(
                          tag: widget.heroTag!,
                          transitionOnUserGestures: true,
                          child: page,
                        );
                      }
                      return Semantics(
                        button: true,
                        label: l10n.pdpViewFullScreen,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openImageViewer(name, i),
                          child: page,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Semantics(
                      button: true,
                      label: l10n.pdpViewFullScreen,
                      child: Material(
                        color: AppColors.surfaceLight.withValues(alpha: 0.92),
                        shape: const StadiumBorder(
                          side: BorderSide(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openImageViewer(name, _imgIndex),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedMaximize01,
                                  size: 15,
                                  color: AppColors.textPrimary,
                                ),
                                if (images.length > 1) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_imgIndex + 1}/${images.length}',
                                    style: AppText.price(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (images.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PdpPageDots(count: images.length, index: _imgIndex),
              ),
          ],
        ),
      ),
    );
  }

  // ── PRODUCT INFO ──

  /// Up to three short "key: value" specs for the title block.
  List<String> get _titleSpecChips => pdpKeySpecs(
    _specs,
    max: 3,
    maxValueLength: 24,
  ).map((spec) => '${spec.key}: ${spec.value}').toList();

  /// "Special Price: " -> "SPECIAL PRICE" for the eyebrow above the price.
  String _eyebrow(String label) =>
      label.replaceAll(RegExp(r'[:：]\s*$'), '').trim().toUpperCase();

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
    final specChips = _titleSpecChips;
    // Dealer prices, and pack products' per-piece / per-meter prices, carry
    // their unit.
    final unitLabel = isWholesaler || _pack.isPack ? _priceUnitLabel() : null;
    final shownPrice = isWholesaler ? (wsPrice ?? price) : price;
    final packetLabel = _packetContentsLabel(price: price);
    final savings = disc > 0 ? mrpNum - priceNum : 0.0;
    String withUnit(String amount) =>
        unitLabel != null ? '$amount/$unitLabel' : amount;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedStore01,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.productBrandValue(brandDetails),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const VerifiedSellerBadge(compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: AppFonts.jakarta(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.star,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ratingCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($ratingCount)',
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
              Text(
                l10n.productSkuValue(sku.isNotEmpty ? sku : 'MILL-001'),
                style: AppFonts.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (specChips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in specChips)
                  StatusChip(label: chip, tone: ChipTone.neutral),
              ],
            ),
          ],
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

                return Pressable(
                  onTap: () => _openVariantSelectorSheet(
                    variantOptions,
                    selectedId,
                    l10n,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppColors.surfaceLight,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.productSelectVariant.toUpperCase(),
                                style: AppText.eyebrow(),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _variantLabel(selectedVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),

          // Coming Soon: badge + expected date; the price may be hidden.
          if (_isComingSoon) ...[
            Row(
              children: [
                const ComingSoonBadge(fontSize: 11, uppercase: false),
                if (_expectedLaunchLabel != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.comingSoonExpected(_expectedLaunchLabel!),
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: comingSoonColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (isPriceHidden(_product))
            Text(
              l10n.comingSoonPrice,
              style: AppText.price(fontSize: 22, color: comingSoonColor),
            )
          else ...[

          // Price block
          if (price != null) ...[
            Text(
              _eyebrow(
                isWholesaler
                    ? l10n.productYourDealerPriceLabel
                    : l10n.productSpecialPriceLabel,
              ),
              style: AppText.eyebrow(
                color: isWholesaler
                    ? AppColors.primaryDeep
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '₹${_money(shownPrice)}',
                          style: AppText.price(fontSize: 28),
                        ),
                        if (unitLabel != null)
                          TextSpan(
                            text: ' /$unitLabel',
                            style: AppFonts.jakarta(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (disc > 0) ...[
                  const SizedBox(width: 10),
                  StatusChip(
                    label: l10n.commonPercentOff('$disc'),
                    tone: ChipTone.accent,
                    icon: HugeIcons.strokeRoundedDiscount,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.productMrpLabel,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    TextSpan(
                      text: mrp != null
                          ? '₹${_money(mrp)}'
                          : (price != null ? '₹${_money(price)}' : 'N/A'),
                      style: AppText.mrp(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (price != null && savings > 0)
                Text(
                  l10n.pdpYouSave(withUnit('₹${_money(savings)}')),
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          // For wholesalers, the price their customers usually pay.
          if (price != null && isWholesaler) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.productSuggestedSellingPriceLabel,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: '₹${_money(customerPrice)}',
                    style:
                        AppText.price(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
          if (packetLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedPackage,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      packetLabel,
                      style: AppText.price(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (price != null)
            PendingPriceChangeNotice(
              pendingPriceChange: pendingPriceChange is Map<String, dynamic>
                  ? pendingPriceChange
                  : null,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
          // Live purchase counter
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
              final productIdHash = _productId.hashCode.abs();
              final seed = productIdHash + dayOfYear;
              final range = effectiveMax - pMin;
              final count = range > 0 ? pMin + (seed % (range + 1)) : pMin;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _factRow(
                  icon: HugeIcons.strokeRoundedFire,
                  iconColor: AppColors.accent,
                  text: l10n.productSoldLast24h(count),
                  textColor: AppColors.textPrimary,
                  weight: FontWeight.w700,
                ),
              );
            },
          ),
          _factRow(
            icon: HugeIcons.strokeRoundedTruckDelivery,
            text: l10n.productDeliveryWithin5Days,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _factRow(
                  icon: _isComingSoon
                      ? HugeIcons.strokeRoundedClock01
                      : inStock
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedCancelCircle,
                  iconColor: _isComingSoon
                      ? comingSoonColor
                      : inStock
                      ? AppColors.primary
                      : AppColors.error,
                  text: _isComingSoon
                      ? l10n.comingSoonBadge
                      : inStock
                      ? l10n.commonInStock
                      : l10n.commonOutOfStock,
                  textColor: _isComingSoon
                      ? comingSoonColor
                      : inStock
                      ? AppColors.primary
                      : AppColors.error,
                  weight: FontWeight.w700,
                ),
              ),
              if (!isPriceHidden(_product)) ...[
                Text(
                  l10n.productInclTaxes,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _factRow({
    required IconData icon,
    required String text,
    Color iconColor = AppColors.textSecondary,
    Color textColor = AppColors.textSecondary,
    FontWeight weight = FontWeight.w500,
  }) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppFonts.jakarta(
              fontSize: 13,
              fontWeight: weight,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  // ── PRODUCT LABELS ──
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
    final gap = labelCount >= 4 ? 6.0 : 8.0;
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      1.6,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: displayLabels.asMap().entries.map((entry) {
          final isLast = entry.key == labelCount - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : gap),
              child: SizedBox(
                height: 58 + 28 * textScale,
                child: _buildProductLabelCard(entry.value),
              ),
            ),
          );
        }).toList(),
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: sourceType == 'image' && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => _labelVisualSkeleton(),
                    errorWidget: (_, _, _) => Icon(
                      _productLabelIcon(iconName, title),
                      size: 26,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    _productLabelIcon(iconName, title),
                    size: 26,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.jakarta(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelVisualSkeleton() {
    return const Skeleton(height: 30, width: 30, radius: AppRadius.sm);
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

  // ── SPECIFICATIONS ──
  Widget _sectionTitle(String title, {String? count}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (count != null)
          StatusChip(label: count, tone: ChipTone.neutral, dense: true),
      ],
    );
  }

  Widget _specsSection(AppLocalizations l10n) {
    final hasMore = _specs.length > 4;
    final keySpecs = pdpKeySpecs(_specs);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            l10n.productSpecifications,
            count: l10n.commonItemsCount(_specs.length),
          ),
          if (keySpecs.length > 1) ...[
            const SizedBox(height: 14),
            Text(l10n.pdpKeySpecs.toUpperCase(), style: AppText.eyebrow()),
            const SizedBox(height: 8),
            PdpKeySpecStrip(specs: keySpecs),
          ],
          const SizedBox(height: 14),
          PdpSpecTable(
            specs: _specs,
            featuresLabel: l10n.pdpFeatures,
            limit: 4,
          ),
          if (hasMore) ...[
            const SizedBox(height: 6),
            AppButton(
              label: l10n.productViewAllSpecifications,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.medium,
              trailingIcon: HugeIcons.strokeRoundedArrowRight01,
              onPressed: () => _openSpecsSheet(l10n),
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
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: _sectionTitle(
                l10n.productSpecifications,
                count: l10n.commonItemsCount(_specs.length),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  24 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: PdpSpecTable(
                  specs: _specs,
                  featuresLabel: l10n.pdpFeatures,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DESCRIPTION ──
  Widget _descSection(String description, AppLocalizations l10n) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedSize(
        duration: AppMotion.of(context, AppMotion.base),
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(l10n.productDescription),
            const SizedBox(height: 10),
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
                fontWeight: FontWeight.w400,
                color: description.isNotEmpty
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
                height: 1.6,
                fontStyle: description.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
            if (_bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...(_descExpanded ? _bullets : _bullets.take(3)).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
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
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (description.length > 200 || _bullets.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _descExpanded = !_descExpanded),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    minimumSize: const Size(44, 40),
                  ),
                  child: Text(
                    _descExpanded ? l10n.productShowLess : l10n.productReadMore,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
        child: Semantics(
          button: true,
          label: l10n.productDemoVideo,
          child: PressScale(
            child: GestureDetector(
              onTap: () {
                _initYoutube();
                setState(() => _videoReady = true);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: 'https://img.youtube.com/vi/$vid/hqdefault.jpg',
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(height: 200, color: AppColors.gray100),
                      errorWidget: (_, _, _) => Container(
                        height: 200,
                        color: AppColors.gray100,
                        child: const Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedPlayCircle,
                            size: 48,
                            color: AppColors.gray400,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedPlayCircle,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.productDemoVideo,
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
        ),
      );
    }
    if (_ytCtrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: YoutubePlayer(
              controller: _ytCtrl!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: AppColors.primary,
              progressColors: const ProgressBarColors(
                playedColor: AppColors.primary,
                handleColor: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: l10n.pdpViewFullScreen,
              onPressed: _openFullscreenVideo,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                fixedSize: const Size(44, 44),
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedFullScreen,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchRelatedProducts() async {
    try {
      debugPrint('Fetching related products for: $_productId');
      setState(() => _isRelatedLoading = true);
      final r = await _dio.get('/products/$_productId/related');
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


  // ── RELATED PRODUCTS ──

  /// Width and height of a related-product card in the rail.
  ({double width, double height}) _relatedCardSize(double maxWidth) {
    // About two and a bit cards on a phone, so the rail reads as scrollable.
    final width = ((maxWidth - 32 - 12) / 2.3).clamp(140.0, 184.0);
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      1.6,
    );
    // Square image, card padding, Add button, then brand, name (2 lines),
    // rating and price.
    final height =
        (width - 12) + 12 + 10 + 42 + (16 + 34 + 20 + 38 + 12) * textScale;
    return (width: width, height: height);
  }

  Widget _relatedProductsSection(AppLocalizations l10n) {
    if (!_isRelatedLoading && _relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.productRelatedProducts),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = _relatedCardSize(constraints.maxWidth);
              return SizedBox(
                height: size.height,
                child: AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.base),
                  child: _isRelatedLoading
                      ? ListView.separated(
                          key: const ValueKey('loading'),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 3,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, _) => SizedBox(
                            width: size.width,
                            child: const SkeletonProductCard(),
                          ),
                        )
                      : ListView.separated(
                          key: const ValueKey('list'),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _relatedProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) => SizedBox(
                            width: size.width,
                            child: _buildRelatedCard(
                              Map<String, dynamic>.from(
                                _relatedProducts[index] as Map,
                              ),
                              l10n,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedCard(Map<String, dynamic> item, AppLocalizations l10n) {
    final pid = item['id']?.toString() ?? item['_id']?.toString() ?? '';
    final images = item['images'];
    final firstImage = images is List && images.isNotEmpty
        ? images.first
        : null;
    final image =
        (item['primaryImage'] ??
                item['image'] ??
                item['imageUrl'] ??
                (firstImage is Map ? firstImage['url'] : firstImage) ??
                '')
            .toString();
    final nameHindi = item['nameHindi']?.toString() ?? '';
    final nameEnglish = item['name']?.toString() ?? '';
    final displayName = localizedName(context, item);
    final brand = (item['brand'] ?? item['category'] ?? '').toString();
    final price = catalogPriceForAudience(
      item,
      isCustomerPreview: ref.read(guestModeProvider),
    );
    final mrp = item['mrp'] ?? item['originalPrice'] ?? 0;
    final hasMrp = mrp is num && price is num && mrp > 0 && mrp != price;
    final discount = hasMrp ? (((mrp - price) / mrp) * 100).round() : 0;
    final stock = item['stock'] ?? 0;
    final inStock = stock is num && stock > 0;
    final rating = item['averageRating'] ?? item['rating'] ?? 4.5;
    final reviewCount =
        item['ratingCount'] ?? item['reviewCount'] ?? item['reviews'] ?? 0;
    final isWishlisted = ref.watch(wishlistProvider).contains(pid);
    final priceValue = price is num
        ? price
        : num.tryParse(price?.toString() ?? '') ?? 0;

    String? badgeLabel;
    var badgeTone = ChipTone.brand;
    if (item['isHot'] == true ||
        item['badge']?.toString().contains('HOT') == true) {
      badgeLabel = l10n.productBadgeHot;
      badgeTone = ChipTone.error;
    } else if (discount > 0) {
      // No badge: the card tags the photo with the discount ("16% OFF").
    } else if (item['isNew'] == true) {
      badgeLabel = l10n.productBadgeNew;
      badgeTone = ChipTone.info;
    }

    return ProductCard(
      name: displayName,
      price: priceValue,
      mrp: hasMrp ? mrp : null,
      offLabel: (percent) => l10n.commonPercentOff('$percent'),
      comingSoon: isComingSoonProduct(item),
      comingSoonPrice: isPriceHidden(item) ? l10n.comingSoonPrice : null,
      imageUrl: image,
      category: item['category']?.toString() ?? '',
      brand: brand.isEmpty ? l10n.productBrandFallback : brand,
      rating: rating is num
          ? rating.toDouble()
          : double.tryParse(rating.toString()),
      reviewCount: reviewCount is num
          ? reviewCount.toInt()
          : int.tryParse(reviewCount.toString()),
      badge: badgeLabel,
      badgeTone: badgeTone,
      inStock: inStock,
      soldOutLabel: l10n.commonOutOfStock,
      wishlisted: isWishlisted,
      wishlistLabel: isWishlisted
          ? l10n.uiRemoveFromWishlist
          : l10n.uiAddToWishlist,
      onWishlist: () {
        if (ref.read(guestModeProvider)) {
          _showGuestModePopup(l10n.productWishlistDisabledPreview);
          return;
        }
        ref
            .read(wishlistProvider.notifier)
            .toggle(
              WishlistItem(
                productId: pid,
                name: nameEnglish,
                image: image,
                price: price is num ? price.toDouble() : 0,
                mrp: hasMrp ? mrp.toDouble() : null,
                category: item['category']?.toString(),
                nameHindi: nameHindi,
                blurHash: (item['primaryBlurHash'] ?? item['blurHash'])
                    ?.toString(),
              ),
            );
      },
      onTap: () => context.push('/product/$pid'),
      // Each tap adds the minimum quantity, as before.
      action: QuantityStepper(
        quantity: 0,
        addLabel: l10n.productAddShort,
        compact: true,
        expand: true,
        enabled: inStock,
        onChanged: (_) {
          if (ref.read(guestModeProvider)) {
            _showGuestModePopup(l10n.productAddToCartDisabledPreview);
            return;
          }
          final minimumQuantity = _minimumQuantity(item);
          _trackEvent('related_add_to_cart_$pid');
          ref
              .read(cartProvider.notifier)
              .addItem(
                productId: pid,
                name: nameEnglish,
                nameHindi: item['nameHindi']?.toString(),
                brand: item['brand']?.toString(),
                category: item['category']?.toString(),
                minWholesaleQuantity:
                    int.tryParse('${item['minWholesaleQuantity'] ?? ''}') ?? 1,
                minCustomerQuantity: customerMinimumOf(item),
                priceUnit: item['priceUnit']?.toString(),
                packing: item['packing']?.toString(),
                price: price is num ? price.toDouble() : 0,
                image: image,
                quantity: minimumQuantity,
                stock: stock is num ? stock.toInt() : 0,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.productAddedToCart),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              margin: _snackBarMarginAboveBottomBar(),
            ),
          );
        },
      ),
    );
  }

  Widget _shippingSection(AppLocalizations l10n) {
    final terms =
        _product?['shippingTerms']?.toString() ??
        l10n.productShippingTermsDefault;
    final duration = AppMotion.of(context, AppMotion.base);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Pressable(
        onTap: () => setState(() => _shippingOpen = !_shippingOpen),
        scale: 0.99,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.surfaceLight,
        semanticLabel: l10n.productShippingReturns,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: AnimatedSize(
            duration: duration,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedDeliveryTruck01,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.productShippingReturns,
                          style: AppFonts.jakarta(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _shippingOpen ? 0.25 : 0,
                        duration: duration,
                        curve: AppMotion.standard,
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_shippingOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      terms,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.6,
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

  // Adds the current product (with the selected quantity) to the cart.
  Future<void> _addToCart(
    String name,
    dynamic price,
    dynamic mrp,
    dynamic stock,
    dynamic minQty,
    AppLocalizations l10n,
  ) async {
    if (ref.read(guestModeProvider)) {
      _showGuestModePopup(l10n.productAddToCartDisabledPreview);
      return;
    }

    final isWholesaler = ref.read(effectiveIsWholesalerProvider);
    final img = _images.isNotEmpty ? _images[0] : null;
    setState(() => _addedToCart = true);
    final error = await ref
        .read(cartProvider.notifier)
        .addItem(
          productId: _productId,
          name: _product?['name']?.toString() ?? name,
          nameHindi: _product?['nameHindi']?.toString(),
          image: img,
          price: (price as num?)?.toDouble() ?? 0,
          mrp: (mrp as num?)?.toDouble(),
          // Admin's minimum as configured (packets for packet products).
          minWholesaleQuantity:
              int.tryParse('${_product?['minWholesaleQuantity'] ?? ''}') ?? 1,
          minCustomerQuantity: customerMinimumOf(_product),
          priceUnit: _product?['priceUnit']?.toString(),
          packing: _product?['packing']?.toString(),
          quantity: _quantity,
          stock: stock is int ? stock : 99,
        );
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (error != null) {
      setState(() => _addedToCart = false);
      _showCartSnackBar(
        messenger,
        SnackBar(
          content: Text(apiErrorText(context, error)),
          behavior: SnackBarBehavior.floating,
          margin: _snackBarMarginAboveBottomBar(),
        ),
      );
      return;
    }

    _trackEvent('cart_add');
    _cartBounce.forward().then((_) => _cartBounce.reverse());
    // Wholesalers have no Cart tab, so offer a direct link to the cart.
    if (isWholesaler) {
      _showCartSnackBar(
        messenger,
        SnackBar(
          content: Text(l10n.productAddedToCart),
          duration: const Duration(seconds: 3),
          persist: false,
          behavior: SnackBarBehavior.floating,
          margin: _snackBarMarginAboveBottomBar(),
          action: SnackBarAction(
            label: l10n.productViewCart,
            onPressed: () => context.push('/cart'),
          ),
        ),
      );
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _addedToCart = false);
      }
    });
  }

  void _showCartSnackBar(ScaffoldMessengerState messenger, SnackBar snackBar) {
    final controller = messenger.showSnackBar(snackBar);
    _cartSnackBar = controller;
    controller.closed.then((_) {
      if (identical(_cartSnackBar, controller)) _cartSnackBar = null;
    });
  }

  // Keeps snack bars clear of the quantity selector and action buttons.
  EdgeInsets _snackBarMarginAboveBottomBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return EdgeInsets.fromLTRB(16, 0, 16, 120 + bottomInset);
  }

  // -- COMING SOON --
  bool get _isComingSoon => isComingSoonProduct(_product);

  String? get _expectedLaunchLabel => expectedLaunchText(
    _product,
    Localizations.localeOf(context).languageCode,
  );

  bool get _notifyMe => _product?['notifyMe'] == true;

  Future<void> _toggleNotifyMe(AppLocalizations l10n) async {
    if (_isNotifyLoading) return;
    if (ref.read(guestModeProvider)) {
      _showGuestModePopup(l10n.comingSoonNotifyMe);
      return;
    }
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    SnackBar snack(String text) => SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: _snackBarMarginAboveBottomBar(),
    );
    if (!ref.read(authProvider).isAuthenticated) {
      _showCartSnackBar(messenger, snack(l10n.comingSoonLoginToNotify));
      return;
    }
    final turnOn = !_notifyMe;
    setState(() => _isNotifyLoading = true);
    try {
      final path = '/products/$_productId/notify-me';
      if (turnOn) {
        await _dio.post(path);
      } else {
        await _dio.delete(path);
      }
      if (!mounted) return;
      setState(() => _product?['notifyMe'] = turnOn);
      _showCartSnackBar(
        messenger,
        snack(turnOn ? l10n.comingSoonNotifyOn : l10n.comingSoonNotifyOff),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      _showCartSnackBar(messenger, snack(apiErrorText(context, error)));
      // It may have just gone live: reload so the buy buttons come back.
      if (error.response?.data is Map &&
          (error.response!.data['error'] is Map) &&
          error.response!.data['error']['code'] == 'PRODUCT_NOT_COMING_SOON') {
        _fetchProduct();
      }
    } finally {
      if (mounted) setState(() => _isNotifyLoading = false);
    }
  }

  // Coming Soon products can't be bought yet: one "Notify me" button.
  Widget _comingSoonBar(double bp, AppLocalizations l10n) {
    final on = _notifyMe;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bp + 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
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
            if (_expectedLaunchLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.comingSoonExpected(_expectedLaunchLabel!),
                  textAlign: TextAlign.center,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: comingSoonColor,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const ValueKey('coming-soon-notify-button'),
                onPressed: _isNotifyLoading
                    ? null
                    : () => _toggleNotifyMe(l10n),
                style: ElevatedButton.styleFrom(
                  backgroundColor: on
                      ? AppColors.surfaceLight
                      : comingSoonColor,
                  foregroundColor: on ? comingSoonColor : Colors.white,
                  elevation: 0,
                  side: on
                      ? const BorderSide(color: comingSoonColor, width: 1.5)
                      : null,
                  shape: const StadiumBorder(),
                ),
                icon: _isNotifyLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        on
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        size: 20,
                      ),
                label: Text(
                  on
                      ? '${l10n.comingSoonNotifying} ✓'
                      : l10n.comingSoonNotifyMe,
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
    if (_isComingSoon) return _comingSoonBar(bp, l10n);
    final unitLabel = _quantityUnitLabel();
    final isWholesaler = ref.watch(effectiveIsWholesalerProvider);
    final minimumQuantity = minQty is num
        ? minQty.toInt()
        : int.tryParse(minQty?.toString() ?? '') ?? 1;
    final packetLabel = _packetContentsLabel(price: price);
    final quantityStep = _quantityStep();
    final minimumText = quantityStep > 1
        ? packQuantityText(l10n, _pack, minimumQuantity)
        : '$minimumQuantity';
    final showMinimum = quantityStep > 1
        ? minimumQuantity > quantityStep
        : (packetLabel == null || minimumQuantity > 1);
    // Customers: smallest cut length / number of pieces, when the admin set one.
    final customerMinimumText = !isWholesaler && minimumQuantity > 1
        ? l10n.productMinOrderQuantity(_quantityText(minimumQuantity, l10n))
        : null;

    // Buying notes in one compact line above the buttons. With a packet size
    // shown, the minimum is only worth showing when it is more than 1.
    final notes = <String>[
      if (inStock && packetLabel != null) packetLabel,
      if (inStock && customerMinimumText != null) customerMinimumText,
      if (isWholesaler && inStock && showMinimum)
        l10n.productMinWholesaleQuantity(minimumText),
      if (isWholesaler) l10n.productOnlyPlatformCanConfirm,
    ];
    final showNotes = (inStock && stock != null) || notes.isNotEmpty;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, bp + 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: AppShadows.bar,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showNotes)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                child: Row(
                  children: [
                    if (inStock && stock != null) ...[
                      _buildStockStatus(stock, l10n),
                      if (notes.isNotEmpty) const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        notes.join('  ·  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (inStock) ...[
                  _quantityControl(stock, unitLabel, l10n),
                  const SizedBox(width: 10),
                ],
                if (isWholesaler) ...[
                  _BarButton(
                    width: 64,
                    stacked: true,
                    label: l10n.productCartShort,
                    icon: _addedToCart
                        ? HugeIcons.strokeRoundedTick02
                        : HugeIcons.strokeRoundedShoppingCart01,
                    enabled: inStock,
                    onPressed: inStock && !_addedToCart
                        ? () =>
                              _addToCart(name, price, mrp, stock, minQty, l10n)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BarButton(
                      primary: true,
                      label: l10n.productSendRequirement,
                      icon: HugeIcons.strokeRoundedSent,
                      enabled: inStock,
                      onPressed: inStock
                          ? () => _openNegotiateSheet(
                              name,
                              price,
                              wsPrice,
                              minQty,
                              l10n,
                            )
                          : null,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _BarButton(
                      label: l10n.productAddToCart,
                      icon: _addedToCart
                          ? HugeIcons.strokeRoundedTick02
                          : null,
                      enabled: inStock,
                      onPressed: inStock && !_addedToCart
                          ? () =>
                                _addToCart(name, price, mrp, stock, minQty, l10n)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BarButton(
                      primary: true,
                      label: l10n.productBuyNow,
                      loading: _isBuyNowLoading,
                      enabled: inStock && !_isBuyNowLoading,
                      onPressed: inStock && !_isBuyNowLoading
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
                                    'productId': _productId,
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
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// − [quantity] + with the unit under the number. The number can be typed.
  Widget _quantityControl(
    dynamic stock,
    String unitLabel,
    AppLocalizations l10n,
  ) {
    return Semantics(
      label: l10n.productSelectQuantity,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: ShapeDecoration(
          color: AppColors.surfaceLight,
          shape: AppShapes.squircle(
            AppRadius.md,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _qtyBtn(
              HugeIcons.strokeRoundedMinusSign,
              () => _setQuantity(_quantity - _quantityStep(), stock),
              l10n.uiDecreaseQuantity,
            ),
            SizedBox(
              width: 50,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
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
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: AppText.price(fontSize: 16),
                    onChanged: (value) => _onQuantityTextChanged(value, stock),
                    onSubmitted: (_) => _commitQuantityInput(stock),
                    onTapOutside: (_) => _quantityFocusNode.unfocus(),
                  ),
                  Text(
                    unitLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            _qtyBtn(
              HugeIcons.strokeRoundedPlusSign,
              () => _setQuantity(_quantity + _quantityStep(), stock),
              l10n.uiIncreaseQuantity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, String label) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 44,
          height: 48,
          child: Center(
            child: HugeIcon(icon: icon, size: 18, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildStockStatus(
    dynamic stock,
    AppLocalizations l10n, {
    bool dense = false,
  }) {
    final stockCount = stock is int ? stock : 99;

    String label;
    Color color;

    if (stockCount <= 0) {
      label = l10n.commonOutOfStock;
      color = AppColors.error;
    } else {
      label = l10n.commonInStock;
      color = AppColors.primary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppFonts.jakarta(
            fontSize: dense ? 11.5 : 12,
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
                _submitNegotiation(qty, target);
              },
              l10n,
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
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.of(ctx).padding.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 12),
                    _stepDots(step),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: AppMotion.of(ctx, AppMotion.base),
                      switchInCurve: AppMotion.standard,
                      switchOutCurve: AppMotion.exit,
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
    });
  }

  Widget _stepDots(int cur) {
    final duration = AppMotion.of(context, AppMotion.base);
    return Row(
      children: List.generate(3, (i) {
        final done = i < cur;
        final active = i == cur;
        Widget line(bool filled) => Expanded(
          child: AnimatedContainer(
            duration: duration,
            height: 2,
            color: filled ? AppColors.primary : AppColors.border,
          ),
        );
        return Expanded(
          child: Row(
            children: [
              if (i > 0) line(done || active),
              AnimatedContainer(
                duration: duration,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active
                      ? AppColors.primary
                      : AppColors.surfaceLight,
                  border: Border.all(
                    color: done || active
                        ? AppColors.primary
                        : AppColors.borderStrong,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: done
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          color: Colors.white,
                          size: 15,
                        )
                      : Text(
                          '${i + 1}',
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active
                                ? Colors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
              if (i < 2) line(done),
            ],
          ),
        );
      }),
    );
  }

  Widget _sheetTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: HugeIcon(icon: icon, color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.jakarta(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: AppFonts.jakarta(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: child,
    );
  }

  static const _bareInput = InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  /// Quick-pick quantities for a quote, in pieces / meters. Pack products go
  /// in whole packs from the wholesale minimum (1×, 2×, 5×, 10×); others in
  /// multiples of their minimum, or 10 / 25 / 50 / 100 without one.
  List<int> _quotePresets(int minQ, int packSize) {
    const multiples = [1, 2, 5, 10];
    if (packSize > 1) {
      final minPacks = math.max(1, (minQ / packSize).ceil());
      return [for (final m in multiples) minPacks * m * packSize];
    }
    if (minQ > 1) return [for (final m in multiples) minQ * m];
    return const [10, 25, 50, 100];
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
    final packSize = _quantityStep();
    final inPacks = packSize > 1 && _pack.isPack;
    final presets = _quotePresets(minQ, packSize);
    final fieldUnit = _pack.isPack
        ? contentUnitLabel(l10n, _pack.contentUnit!)
        : _quantityUnitLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(
          icon: HugeIcons.strokeRoundedPackage,
          title: l10n.productHowManyUnits,
          subtitle: l10n.productHowManyUnitsSubtitle,
        ),
        const SizedBox(height: 20),
        Text(l10n.productQuickSelect, style: AppText.eyebrow()),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < presets.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _quickPick(
                  presets[i],
                  selected: qty == presets[i],
                  inPacks: inPacks,
                  packSize: packSize,
                  l10n: l10n,
                  onTap: () {
                    onQty(presets[i]);
                    ctrl.text = '${presets[i]}';
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _sheetField(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final p = int.tryParse(v);
              if (p != null) onQty(p);
            },
            style: AppText.price(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: _bareInput.copyWith(
              hintText: l10n.productCustomQuantity,
              hintStyle: AppFonts.jakarta(color: AppColors.textTertiary),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 10),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPencilEdit01,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixText: fieldUnit,
              suffixStyle: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
        // Pack products: what the typed amount is in packs.
        if (inPacks && qty > 0 && qty % packSize == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              packQuantityText(l10n, _pack, qty),
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 20),
        AppButton(
          label: l10n.productContinueToPricing,
          trailingIcon: HugeIcons.strokeRoundedArrowRight01,
          onPressed: qty >= 1 ? onNext : null,
        ),
      ],
    );
  }

  Widget _quickPick(
    int quantity, {
    required bool selected,
    required bool inPacks,
    required int packSize,
    required AppLocalizations l10n,
    required VoidCallback onTap,
  }) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    return Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.md),
      shape: AppShapes.squircle(AppRadius.md),
      color: selected ? AppColors.primary : AppColors.surfaceLight,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        height: inPacks ? 58 : 48,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: ShapeDecoration(
          shape: AppShapes.squircle(
            AppRadius.md,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.borderStrong,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                inPacks
                    ? packsText(l10n, _pack.packUnit!, quantity ~/ packSize)
                    : NumberFormatter.formatQuantity(quantity),
                maxLines: 1,
                style: AppText.price(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
            if (inPacks)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  contentsText(l10n, _pack.contentUnit!, quantity),
                  maxLines: 1,
                  style: AppFonts.jakarta(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Step 2: Price
  Widget _sheetStep2(
    int qty,
    double target,
    TextEditingController ctrl,
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
        _sheetTitle(
          icon: HugeIcons.strokeRoundedMoney01,
          title: l10n.productYourExpectedPrice,
          subtitle: l10n.productQtyRetailSummary(qty, _fmt(rp)),
        ),
        const SizedBox(height: 18),
        Text(l10n.productTargetPricePerUnit, style: AppText.eyebrow()),
        const SizedBox(height: 8),
        _sheetField(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final p = double.tryParse(v.replaceAll(',', ''));
              if (p != null) onPrice(p);
            },
            style: AppText.price(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: _bareInput.copyWith(
              prefixText: '₹ ',
              prefixStyle: AppText.price(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        if (target > 0 && target < rp) ...[
          const SizedBox(height: 14),
          _noteBox(
            icon: HugeIcons.strokeRoundedMoneySavingJar,
            text: l10n.productSaveAmount(_fmt(savings), '$pct', '$qty'),
            background: AppColors.accentSoft,
            foreground: AppColors.accent,
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonBack,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppButton(
                label: l10n.productReviewRequirement,
                size: AppButtonSize.medium,
                onPressed: target > 0 ? onNext : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _noteBox({
    required IconData icon,
    required String text,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
    AppLocalizations l10n,
  ) {
    final total = target * qty;
    final saved = (rp * qty) - total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(
          icon: HugeIcons.strokeRoundedFileValidation,
          title: l10n.productReviewRequirement,
          subtitle: l10n.productConfirmBeforeSubmit,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _reviewLine(l10n.productReviewProduct, productName),
              _divider(),
              _reviewLine(l10n.commonQuantity, _quantityText(qty, l10n)),
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
              _divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.commonTotal,
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '₹${_money(total)}',
                    style: AppText.price(fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const DeliveryNote(),
            ],
          ),
        ),
        if (saved > 0) ...[
          const SizedBox(height: 12),
          _noteBox(
            icon: HugeIcons.strokeRoundedMoneySavingJar,
            text: l10n.productYouSaveVsRetail(_fmt(saved)),
            background: AppColors.accentSoft,
            foreground: AppColors.accent,
          ),
        ],
        const SizedBox(height: 12),
        _noteBox(
          icon: HugeIcons.strokeRoundedInformationCircle,
          text: l10n.productBulkUpiNote,
          background: AppColors.warningSoft,
          foreground: AppColors.warning,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonEdit,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppButton(
                label: l10n.productSubmitQuote,
                icon: HugeIcons.strokeRoundedSent,
                size: AppButtonSize.medium,
                onPressed: onSubmit,
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
        Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: AppFonts.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.textTertiary : AppColors.textPrimary,
              decoration: muted ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.textTertiary,
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
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(vertical: 10),
  );

  Future<void> _submitNegotiation(int qty, double pricePerUnit) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/negotiations',
        data: {
          'productId': _productId,
          'quantity': qty,
          'pricePerUnit': pricePerUnit,
        },
      );

      if (response.data['success'] == true && mounted) {
        final negNumber = response.data['data']?['negotiationNumber'] ?? '';
        showAppSnack(
          context,
          context.l10n.productQuotationSubmitted(qty, '$negNumber'),
          tone: SnackTone.success,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg =
          e.response?.data?['message']?.toString() ??
          context.l10n.productNegotiationSubmitFailed;
      showAppSnack(context, msg, tone: SnackTone.error);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        context.l10n.productSomethingWentWrongDetail('$e'),
        tone: SnackTone.error,
      );
    }
  }

  Widget _trustBadgesStrip() {
    return const AppCard(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: EdgeInsets.fromLTRB(8, 16, 8, 16),
      child: PdpTrustBadges(),
    );
  }
}

/// A button in the sticky bottom bar. Labels shrink to fit narrow screens
/// instead of being cut off.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.onPressed,
    required this.enabled,
    this.icon,
    this.primary = false,
    this.loading = false,
    this.stacked = false,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Drawn as available; it can still ignore taps for a moment (e.g. right
  /// after adding to the cart).
  final bool enabled;
  final IconData? icon;
  final bool primary;
  final bool loading;

  /// Icon above a small label (the wholesaler's Cart button).
  final bool stacked;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    BorderSide side = BorderSide.none;
    if (primary) {
      background = enabled || loading ? AppColors.primary : AppColors.gray300;
      foreground = Colors.white;
    } else {
      background = AppColors.surfaceLight;
      foreground = enabled ? AppColors.textPrimary : AppColors.textDisabled;
      side = const BorderSide(color: AppColors.borderStrong);
    }
    final radius = BorderRadius.circular(AppRadius.md);
    final duration = AppMotion.of(context, AppMotion.fast);

    Widget iconWidget(double size) => AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: HugeIcon(
        key: ValueKey(icon),
        icon: icon!,
        size: size,
        color: foreground,
      ),
    );

    final Widget content;
    if (loading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
      );
    } else if (stacked) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) iconWidget(20),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppFonts.jakarta(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      );
    } else {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[iconWidget(18), const SizedBox(width: 6)],
            Text(
              label,
              maxLines: 1,
              style: AppFonts.jakarta(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        enabled: onPressed != null,
        child: SizedBox(
          width: width,
          height: 48,
          child: Material(
            color: background,
            shape: RoundedSuperellipseBorder(borderRadius: radius, side: side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: stacked ? 4 : 10),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
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
              progressIndicatorColor: AppColors.primary,
              progressColors: const ProgressBarColors(
                playedColor: AppColors.primary,
                handleColor: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              tooltip: context.l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                fixedSize: const Size(44, 44),
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
