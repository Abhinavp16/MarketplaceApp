import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:shimmer/shimmer.dart';
import '../core/config/api_config.dart';
import 'product_image_placeholder.dart';

class AppImage extends StatelessWidget {
  final String imageUrl;
  final String? blurHash;
  final String category;
  final String name;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Width (logical px) to decode the photo at, for an image whose laid-out
  /// size keeps changing (a Hero flight resizes it every frame).
  final double? decodeWidth;

  /// Decode the original photo, for a zoomable full-screen viewer.
  final bool fullResolution;

  /// While this copy loads, show the smaller one another AppImage already
  /// decoded for the same URL (a product card), so a Hero flight from that
  /// card never flashes the placeholder.
  final bool previewFromSmaller;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.blurHash,
    required this.category,
    required this.name,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.fullResolution = false,
    this.previewFromSmaller = false,
  });

  /// Last decode width (device px) per URL, newest last, for
  /// [previewFromSmaller].
  static final LinkedHashMap<String, int> _decodedWidths = LinkedHashMap();

  static void _remember(String url, int px) {
    _decodedWidths
      ..remove(url)
      ..[url] = px;
    if (_decodedWidths.length > 300) {
      _decodedWidths.remove(_decodedWidths.keys.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ApiConfig.normalizeMediaUrl(imageUrl);

    if (resolvedImageUrl.isEmpty) {
      return ProductImagePlaceholder(category: category, name: name);
    }
    if (fullResolution) return _network(resolvedImageUrl);

    // Decode at the size the photo is shown, not at the uploaded size.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (decodeWidth != null) {
      return _resized(resolvedImageUrl, _devicePx(decodeWidth!, dpr));
    }
    if (width != null || height != null) {
      return _sizedFor(resolvedImageUrl, width, height, dpr);
    }
    return LayoutBuilder(
      builder: (context, constraints) => _sizedFor(
        resolvedImageUrl,
        constraints.hasBoundedWidth ? constraints.maxWidth : null,
        constraints.hasBoundedHeight ? constraints.maxHeight : null,
        dpr,
      ),
    );
  }

  /// Decodes by width (keeps the aspect ratio). A covering photo is cropped,
  /// so it's decoded wide enough to fill the box's height as well, for
  /// photos up to 3:2.
  Widget _sizedFor(String url, double? w, double? h, double dpr) {
    if (w != null && w > 0) {
      final shown = fit == BoxFit.cover && h != null && h > 0
          ? math.max(w, h * 1.5)
          : w;
      return _resized(url, _devicePx(shown, dpr));
    }
    if (h != null && h > 0) {
      return _network(url, cacheHeight: _devicePx(h, dpr));
    }
    return _network(url);
  }

  /// Rounded up to 64 px steps so nearly equal sizes share one decode.
  static int _devicePx(double logical, double dpr) =>
      ((logical * dpr) / 64).ceil() * 64;

  Widget _resized(String url, int cacheWidth) {
    final smaller = previewFromSmaller ? _decodedWidths[url] : null;
    _remember(url, cacheWidth);
    final image = _network(url, cacheWidth: cacheWidth);
    if (smaller == null || smaller >= cacheWidth) return image;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        _network(url, cacheWidth: smaller),
        _network(url, cacheWidth: cacheWidth, overlay: true),
      ],
    );
  }

  /// [overlay]: drawn over a smaller copy, so nothing shows until it loads.
  Widget _network(
    String url, {
    int? cacheWidth,
    int? cacheHeight,
    bool overlay = false,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholderFadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) =>
          overlay ? const SizedBox.shrink() : _buildPlaceholder(),
      errorWidget: (context, url, error) => overlay
          ? const SizedBox.shrink()
          : ProductImagePlaceholder(category: category, name: name),
    );
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blurHash != null && blurHash!.isNotEmpty)
            BlurHash(hash: blurHash!, imageFit: fit)
          else
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
