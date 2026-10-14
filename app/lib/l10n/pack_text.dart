import '../core/utils/number_formatter.dart';
import '../core/utils/packing.dart';
import 'l10n.dart';

/// "Packet", "Coil", "Bundle".
String packUnitLabel(AppLocalizations l10n, PackUnit unit) => switch (unit) {
  PackUnit.packet => l10n.productUnitPacket,
  PackUnit.coil => l10n.productUnitCoil,
  PackUnit.bundle => l10n.productUnitBundle,
};

/// "Piece", "Meter" — the unit prices of pack products are quoted in.
String contentUnitLabel(AppLocalizations l10n, ContentUnit unit) =>
    switch (unit) {
      ContentUnit.piece => l10n.productUnitPiece,
      ContentUnit.meter => l10n.productUnitMeter,
    };

/// "15 pieces", "1,000 m".
String contentsText(AppLocalizations l10n, ContentUnit unit, int amount) =>
    switch (unit) {
      ContentUnit.piece => l10n.productPiecesCount(amount),
      ContentUnit.meter => l10n.productMetersCount(
        NumberFormatter.formatPrice(amount),
      ),
    };

/// "1 Packet", "2 Coils", "3 Bundles".
String packsText(AppLocalizations l10n, PackUnit unit, int count) =>
    switch (unit) {
      PackUnit.packet => l10n.productPacketsCount(count),
      PackUnit.coil => l10n.productCoilsCount(count),
      PackUnit.bundle => l10n.productBundlesCount(count),
    };

/// "2 Bundles (1,000 m)" for [amount] pieces/meters of a pack product.
String packQuantityText(AppLocalizations l10n, PackInfo info, int amount) =>
    l10n.productPackWithContents(
      packsText(l10n, info.packUnit!, amount ~/ info.size),
      contentsText(l10n, info.contentUnit!, amount),
    );

/// "Bundle 500 m" and "₹26,000": one pack and its price, short enough for a
/// product card, from the per-meter / per-piece [unitPrice].
({String label, String price}) packCardParts(
  AppLocalizations l10n,
  PackInfo info,
  num unitPrice,
) => (
  label: l10n.productCardPack(
    packUnitLabel(l10n, info.packUnit!),
    info.contentUnit == ContentUnit.meter
        ? l10n.productMetersCount(NumberFormatter.formatPrice(info.size))
        : l10n.productPcsCount(info.size),
  ),
  price: '₹${NumberFormatter.formatPrice(unitPrice * info.size)}',
);

/// "1 Coil (500 m) = ₹37,500" from the per-meter / per-piece [unitPrice].
String packPriceText(AppLocalizations l10n, PackInfo info, num unitPrice) =>
    l10n.productPackPrice(
      packQuantityText(l10n, info, info.size),
      NumberFormatter.formatPrice(unitPrice * info.size),
    );
