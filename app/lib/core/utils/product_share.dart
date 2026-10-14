import '../../l10n/generated/app_localizations.dart';
import '../config/public_business_config.dart';
import 'coming_soon.dart';

/// Text shared from a product page: name, the customer (retail) price and
/// the product's website link, which opens the app when it's installed.
///
/// Always the retail price: a wholesaler's response also carries their
/// wholesale `price`, which must never leave the app. No price while it is
/// hidden for a Coming Soon product.
String productShareMessage(
  AppLocalizations l10n,
  Map<dynamic, dynamic> product, {
  required String name,
}) {
  final url = PublicBusinessConfig.productUrl(product['slug']?.toString());
  final raw = product['retailPrice'] ?? product['price'];
  final price = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
  if (price == null || price <= 0 || isPriceHidden(product)) {
    return l10n.productShareText(name, url);
  }
  return l10n.productShareTextWithPrice(
    name,
    price.toStringAsFixed(0),
    url,
  );
}
