import '../../core/utils/packing.dart';
import '../../l10n/l10n.dart';
import '../../l10n/pack_text.dart';

/// Price suffix for a catalog card, e.g. "/m" or "/pc".
///
/// Pack products (coils, bundles, packets) are priced per meter or piece, so
/// the suffix is the content unit. Other products use their own price unit.
/// Returns null when the product has no unit.
String? catalogUnitSuffix(AppLocalizations l10n, Map<dynamic, dynamic> product) {
  final pack = packInfoOf(product);
  if (pack.isPack) {
    return pack.contentUnit == ContentUnit.meter
        ? l10n.catPerMeterShort
        : l10n.catPerPieceShort;
  }
  final raw =
      (product['priceUnit'] ?? product['unit'] ?? product['uom'] ?? '')
          .toString()
          .trim();
  if (raw.isEmpty) return null;
  if (isMeterUnit(raw)) return l10n.catPerMeterShort;
  final normalized = raw.toLowerCase().replaceAll('.', '');
  if (normalized.contains('piece') ||
      normalized.contains('pcs') ||
      normalized == 'pc' ||
      normalized.contains('nos') ||
      normalized == 'unit' ||
      normalized == 'units') {
    return l10n.catPerPieceShort;
  }
  if (isPacketUnit(raw)) return '/${l10n.productUnitPacket}';
  if (normalized.contains('coil')) return '/${l10n.productUnitCoil}';
  if (normalized.contains('bundle')) return '/${l10n.productUnitBundle}';
  return '/$raw';
}

/// "Bundle 500 m" and "₹26,000" for a pack product's card, from the
/// per-meter / per-piece [price]; null for everything else.
({String label, String price})? catalogPackParts(
  AppLocalizations l10n,
  Map<dynamic, dynamic> product,
  num price,
) {
  final pack = packInfoOf(product);
  if (!pack.isPack || price <= 0) return null;
  return packCardParts(l10n, pack, price);
}
