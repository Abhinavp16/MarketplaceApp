// Products sold in packs but priced per piece or per meter.
//
//   Price Unit  Packing          Price is per  One pack is
//   Packet      "15", "15 pcs"   piece         15 pieces
//   Coil        "500 m", "500"   meter         500 m      (service wire)
//   Bundle      "500 m"          meter         500 m      (cables, roll pipes)
//
// A Bundle whose Packing isn't a length in meters ("3 bundles", "1") is a
// normal product priced per bundle, so a Bundle must say "m".
//
// Quantities and stock are always counted in pieces or meters. Wholesalers
// buy whole packs and their minimum (minWholesaleQuantity) is in packs.
// Customers buy loose pieces or cut lengths, at least minCustomerQuantity.
// Every other product has a pack size of 1, so nothing changes for it.
// Keep in sync with the mobile app's packing helper and the admin panel's pack-size helper.

const PIECE_COUNT = /^(\d+)\s*(pcs?|pieces?|nos?|units?)?\.?$/i;
const METER_LENGTH = /^(\d+)\s*(m|mtrs?|meters?|metres?)\.?$/i;
const PLAIN_NUMBER = /^(\d+)$/;

const normalizedUnit = (unit) => String(unit ?? '').trim().toLowerCase();

const isPacketUnit = (unit) => {
  const value = normalizedUnit(unit);
  return value.includes('packet') || value.includes('pack');
};
const isCoilUnit = (unit) => normalizedUnit(unit).includes('coil');
const isBundleUnit = (unit) => normalizedUnit(unit).includes('bundle');

const firstNumber = (pattern, text) => {
  const match = pattern.exec(String(text ?? '').trim());
  return match ? Number.parseInt(match[1], 10) : null;
};

const packingPieceCount = (packing) => firstNumber(PIECE_COUNT, packing);
const packingMeterLength = (packing) => firstNumber(METER_LENGTH, packing);

const NO_PACK = Object.freeze({ size: 1, packUnit: null, contentUnit: null });

// { size, packUnit: 'packet'|'coil'|'bundle'|null, contentUnit: 'piece'|'meter'|null }
const getPackInfo = (product = {}) => {
  const unit = product?.priceUnit;
  const packing = product?.packing;
  let size = null;
  let packUnit = null;
  let contentUnit = null;
  if (isPacketUnit(unit)) {
    size = packingPieceCount(packing);
    packUnit = 'packet';
    contentUnit = 'piece';
  } else if (isCoilUnit(unit)) {
    size = packingMeterLength(packing) ?? firstNumber(PLAIN_NUMBER, packing);
    packUnit = 'coil';
    contentUnit = 'meter';
  } else if (isBundleUnit(unit)) {
    size = packingMeterLength(packing);
    packUnit = 'bundle';
    contentUnit = 'meter';
  }
  return size && size > 1 ? { size, packUnit, contentUnit } : NO_PACK;
};

const getPackSize = (product = {}) => getPackInfo(product).size;

const positiveInteger = (value, fallback) => {
  const number = Number(value ?? fallback);
  return Number.isInteger(number) && number > 0 ? number : 1;
};

// Admin's wholesale minimum (in packs for pack products), at least 1.
const getMinimumWholesalePacks = (product = {}, fallback = 1) => (
  positiveInteger(product?.minWholesaleQuantity, fallback)
);

// Wholesaler minimum in pieces / meters.
const getMinimumWholesaleQuantity = (product = {}, fallback = 1) => (
  getMinimumWholesalePacks(product, fallback) * getPackSize(product)
);

// Customer minimum in pieces / meters (loose pieces, cut lengths).
const getMinimumCustomerQuantity = (product = {}) => (
  positiveInteger(product?.minCustomerQuantity, 1)
);

const isWholePacks = (product, quantity) => Number(quantity) % getPackSize(product) === 0;

// Smallest valid wholesaler quantity at or above `quantity`.
const roundUpToWholesaleQuantity = (product, quantity, fallback = 1) => {
  const packSize = getPackSize(product);
  const wholePacks = Math.ceil(Math.max(Number(quantity) || 0, 1) / packSize) * packSize;
  return Math.max(wholePacks, getMinimumWholesaleQuantity(product, fallback));
};

// "packets of 15 pieces", "coils of 500 m" (for error messages).
const describePack = (product = {}) => {
  const { size, packUnit, contentUnit } = getPackInfo(product);
  if (!packUnit) return 'whole units';
  return `${packUnit}s of ${size}${contentUnit === 'meter' ? ' m' : ' pieces'}`;
};

const formatAmount = (value) => new Intl.NumberFormat('en-IN', { maximumFractionDigits: 2 }).format(Number(value) || 0);
const PACK_LABELS = { packet: ['Packet', 'Packets'], coil: ['Coil', 'Coils'], bundle: ['Bundle', 'Bundles'] };

// "30 pcs" / "1,000 m" for an amount in pieces or meters; else the number.
const contentsShortText = (product = {}, amount = 0) => {
  const { contentUnit } = getPackInfo(product);
  if (contentUnit === 'meter') return `${formatAmount(amount)} m`;
  if (contentUnit === 'piece') return `${formatAmount(amount)} pcs`;
  return formatAmount(amount);
};

// "2 Packets (30 pieces)" / "1 Coil (500 m)" for pack products, else null.
const packQuantityText = (product = {}, amount = 0) => {
  const { size, packUnit, contentUnit } = getPackInfo(product);
  if (!packUnit) return null;
  const packs = Number(amount) / size;
  const label = PACK_LABELS[packUnit][packs === 1 ? 0 : 1];
  const contents = contentUnit === 'meter'
    ? `${formatAmount(amount)} m`
    : `${formatAmount(amount)} ${Number(amount) === 1 ? 'piece' : 'pieces'}`;
  return `${formatAmount(packs)} ${label} (${contents})`;
};

module.exports = {
  describePack,
  contentsShortText,
  packQuantityText,
  isPacketUnit,
  isCoilUnit,
  isBundleUnit,
  packingPieceCount,
  packingMeterLength,
  getPackInfo,
  getPackSize,
  getMinimumWholesalePacks,
  getMinimumWholesaleQuantity,
  getMinimumCustomerQuantity,
  isWholePacks,
  roundUpToWholesaleQuantity,
};
