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

  const AppImage({
    super.key,
    required this.imageUrl,
    this.blurHash,
    required this.category,
    required this.name,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ApiConfig.normalizeMediaUrl(imageUrl);

    if (resolvedImageUrl.isEmpty) {
      return ProductImagePlaceholder(category: category, name: name);
    }

    return CachedNetworkImage(
      imageUrl: resolvedImageUrl,
      width: width,
      height: height,
      fit: fit,
      // Memory management: Lazy load appropriate resolutions
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      // Smooth transitions
      fadeInDuration: const Duration(milliseconds: 500),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholderFadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) =>
          ProductImagePlaceholder(category: category, name: name),
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
