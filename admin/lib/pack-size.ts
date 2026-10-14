// Products sold in packs but priced per piece or per meter.
//
//   Price Unit  Packing          Price is per  One pack is
//   Packet      "15", "15 pcs"   piece         15 pieces
//   Coil        "500 m", "500"   meter         500 m      (service wire)
//   Bundle      "500 m"          meter         500 m      (cables, roll pipes)
//
// A Bundle whose Packing isn't a length in meters is a normal product priced
// per bundle. Quantities and stock are stored in pieces or meters;
// Min Wholesale Qty is in packs, Min Customer Qty in pieces or meters.
// Keep in sync with the backend pack-size helper.

export type PackUnit = "packet" | "coil" | "bundle";
export type ContentUnit = "piece" | "meter";

export interface PackInfo {
  size: number;
  packUnit: PackUnit | null;
  contentUnit: ContentUnit | null;
}

export const NO_PACK: PackInfo = { size: 1, packUnit: null, contentUnit: null };

const PIECE_COUNT = /^(\d+)\s*(pcs?|pieces?|nos?|units?)?\.?$/i;
const METER_LENGTH = /^(\d+)\s*(m|mtrs?|meters?|metres?)\.?$/i;
const PLAIN_NUMBER = /^(\d+)$/;

const firstNumber = (pattern: RegExp, text?: string | null) => {
  const match = pattern.exec(String(text ?? "").trim());
  return match ? Number.parseInt(match[1], 10) : null;
};

const unitOf = (unit?: string | null) => String(unit ?? "").trim().toLowerCase();

export const isPacketUnit = (unit?: string | null) => {
  const value = unitOf(unit);
  return value.includes("packet") || value.includes("pack");
};
export const isCoilUnit = (unit?: string | null) => unitOf(unit).includes("coil");
export const isBundleUnit = (unit?: string | null) => unitOf(unit).includes("bundle");

export function getPackInfo(unit?: string | null, packing?: string | null): PackInfo {
  let size: number | null = null;
  let packUnit: PackUnit | null = null;
  let contentUnit: ContentUnit | null = null;
  if (isPacketUnit(unit)) {
    size = firstNumber(PIECE_COUNT, packing);
    packUnit = "packet";
    contentUnit = "piece";
  } else if (isCoilUnit(unit)) {
    size = firstNumber(METER_LENGTH, packing) ?? firstNumber(PLAIN_NUMBER, packing);
    packUnit = "coil";
    contentUnit = "meter";
  } else if (isBundleUnit(unit)) {
    size = firstNumber(METER_LENGTH, packing);
    packUnit = "bundle";
    contentUnit = "meter";
  }
  return size && size > 1 ? { size, packUnit, contentUnit } : NO_PACK;
}

export const packInfoOfProduct = (product?: { priceUnit?: string | null; packing?: string | null } | null) =>
  getPackInfo(product?.priceUnit, product?.packing);

const PACK_LABELS: Record<PackUnit, [string, string]> = {
  packet: ["Packet", "Packets"],
  coil: ["Coil", "Coils"],
  bundle: ["Bundle", "Bundles"],
};

export const packLabel = (unit: PackUnit, count = 1) => PACK_LABELS[unit][count === 1 ? 0 : 1];

export const contentLabel = (unit: ContentUnit) => (unit === "meter" ? "Meter" : "Piece");

const formatNumber = (value: number) =>
  new Intl.NumberFormat("en-IN", { maximumFractionDigits: 2 }).format(value);

// "15 pieces", "1,000 m"
export const contentsText = (unit: ContentUnit, amount: number) =>
  unit === "meter" ? `${formatNumber(amount)} m` : `${formatNumber(amount)} ${amount === 1 ? "piece" : "pieces"}`;

// "2 Bundles (1,000 m)" for an amount in pieces / meters.
export function packQuantityText(info: PackInfo, amount: number) {
  if (!info.packUnit || !info.contentUnit) return formatNumber(amount);
  const packs = amount / info.size;
  return `${formatNumber(packs)} ${packLabel(info.packUnit, packs)} (${contentsText(info.contentUnit, amount)})`;
}

// Quantity next to an order / deal line: "2 Bundles (1,000 m)", else the number.
export const quantityWithPacks = (
  product: { priceUnit?: string | null; packing?: string | null } | null | undefined,
  quantity: number,
) => {
  const info = packInfoOfProduct(product);
  return info.packUnit ? packQuantityText(info, quantity) : formatNumber(quantity);
};

export { formatNumber as formatPackNumber };

// Stock line for product cards: "50,000 m (100 Coils)" for pack products,
// otherwise the number and unit as typed ("100 Set").
export const stockText = (
  product: { priceUnit?: string | null; packing?: string | null },
  stock: number,
) => {
  const info = packInfoOfProduct(product);
  if (info.packUnit && info.contentUnit) {
    const packs = stock / info.size;
    return `${contentsText(info.contentUnit, stock)} (${formatNumber(packs)} ${packLabel(info.packUnit, packs)})`;
  }
  return `${formatNumber(stock)}${product.priceUnit ? ` ${product.priceUnit}` : ""}`;
};
