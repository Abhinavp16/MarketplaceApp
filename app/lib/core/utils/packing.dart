// Products sold in packs but priced per piece or per meter.
//
//   Price Unit  Packing          Price is per  One pack is
//   Packet      "15", "15 pcs"   piece         15 pieces
//   Coil        "500 m", "500"   meter         500 m      (service wire)
//   Bundle      "500 m"          meter         500 m      (cables, roll pipes)
//
// A Bundle whose Packing isn't a length in meters is a normal product priced
// per bundle. Quantities and stock are always in pieces or meters.
// Wholesalers buy whole packs (their minimum is in packs); customers buy loose
// pieces or cut lengths (at least minCustomerQuantity).
// Keep in sync with backend/src/utils/packSize.js.

enum PackUnit { packet, coil, bundle }

enum ContentUnit { piece, meter }

class PackInfo {
  const PackInfo(this.size, this.packUnit, this.contentUnit);

  static const none = PackInfo(1, null, null);

  /// Pieces or meters in one pack; 1 when not sold in packs.
  final int size;
  final PackUnit? packUnit;
  final ContentUnit? contentUnit;

  bool get isPack => size > 1 && packUnit != null;
}

final _pieceCount = RegExp(
  r'^(\d+)\s*(pcs?|pieces?|nos?|units?)?\.?$',
  caseSensitive: false,
);
final _meterLength = RegExp(
  r'^(\d+)\s*(m|mtrs?|meters?|metres?)\.?$',
  caseSensitive: false,
);
final _plainNumber = RegExp(r'^(\d+)$');

int? _firstNumber(RegExp pattern, String? text) {
  final match = pattern.firstMatch((text ?? '').trim());
  return match == null ? null : int.parse(match.group(1)!);
}

/// Pieces per packet from a product's Packing field: "15", "15 pcs",
/// "15 pieces", "15 nos". Returns null for anything else (e.g. "Box of 10").
int? packingPieceCount(String? packing) => _firstNumber(_pieceCount, packing);

/// Meters per coil/bundle: "500 m", "500 mtr", "500 meters".
int? packingMeterLength(String? packing) => _firstNumber(_meterLength, packing);

String _unit(String? unit) => (unit ?? '').trim().toLowerCase();

/// Whether a price unit means the product is sold by the packet.
bool isPacketUnit(String? unit) {
  final value = _unit(unit);
  return value.contains('packet') || value.contains('pack');
}

bool isMeterUnit(String? unit) {
  final value = _unit(unit).replaceAll('.', '');
  return const {
    'm',
    'mtr',
    'mtrs',
    'meter',
    'meters',
    'metre',
    'metres',
  }.contains(value);
}

PackInfo packInfoFor(String? unit, String? packing) {
  final value = _unit(unit);
  int? size;
  PackUnit? packUnit;
  ContentUnit? contentUnit;
  if (isPacketUnit(value)) {
    size = packingPieceCount(packing);
    packUnit = PackUnit.packet;
    contentUnit = ContentUnit.piece;
  } else if (value.contains('coil')) {
    size = packingMeterLength(packing) ?? _firstNumber(_plainNumber, packing);
    packUnit = PackUnit.coil;
    contentUnit = ContentUnit.meter;
  } else if (value.contains('bundle')) {
    size = packingMeterLength(packing);
    packUnit = PackUnit.bundle;
    contentUnit = ContentUnit.meter;
  }
  return size != null && size > 1
      ? PackInfo(size, packUnit, contentUnit)
      : PackInfo.none;
}

dynamic _unitOf(Map<dynamic, dynamic> product) =>
    product['priceUnit'] ?? product['unit'] ?? product['uom'];

/// [packInfoFor] for a product map from the API.
PackInfo packInfoOf(Map<dynamic, dynamic>? product) {
  if (product == null) return PackInfo.none;
  return packInfoFor(
    _unitOf(product)?.toString(),
    product['packing']?.toString(),
  );
}

/// Pieces/meters in one pack (server value first); 1 when not sold in packs.
int packSizeFor(String? unit, String? packing) =>
    packInfoFor(unit, packing).size;

int packSizeOf(Map<dynamic, dynamic>? product) {
  if (product == null) return 1;
  final serverValue = product['packSize'];
  if (serverValue is num && serverValue >= 1) return serverValue.toInt();
  return packInfoOf(product).size;
}

/// Whether quantities of this product are meters (cut lengths).
bool isMeterProduct(Map<dynamic, dynamic>? product) {
  if (product == null) return false;
  final info = packInfoOf(product);
  if (info.isPack) return info.contentUnit == ContentUnit.meter;
  return isMeterUnit(_unitOf(product)?.toString());
}

int _positive(dynamic value) {
  final number = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 1;
  return number > 0 ? number : 1;
}

/// Wholesaler minimum in pieces/meters: the admin's minimum is in packs for
/// pack products.
int wholesaleMinimumOf(Map<dynamic, dynamic>? product) =>
    _positive(product?['minWholesaleQuantity']) * packSizeOf(product);

/// Customer minimum in pieces/meters (loose pieces, cut lengths).
int customerMinimumOf(Map<dynamic, dynamic>? product) =>
    _positive(product?['minCustomerQuantity']);
