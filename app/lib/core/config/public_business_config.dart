import 'brand_config.dart';

/// Public business links used by share / help screens.
///
/// Demo build: everything points at the generic placeholder website and there
/// is no WhatsApp channel.
class PublicBusinessConfig {
  const PublicBusinessConfig._();

  static const String websiteOrigin = BrandConfig.websiteOrigin;

  static String productUrl(String? slug) {
    final normalizedSlug = slug?.trim() ?? '';
    return normalizedSlug.isEmpty
        ? '$websiteOrigin/products'
        : '$websiteOrigin/products/${Uri.encodeComponent(normalizedSlug)}';
  }
}
