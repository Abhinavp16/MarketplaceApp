const { USER_ROLES } = require('./constants');
const { applyMrpDiscount } = require('./productDiscount');

const normalizeObjectIdLike = (value) => {
  if (value === null || value === undefined) return null;
  const normalized = String(value).trim();
  return normalized || null;
};

const toPositiveNumber = (value, fallback = 0) => {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : fallback;
};

const sortVariants = () => [];

const hasRealVariants = () => false;

const getActiveVariants = (product = {}) => {
  return [];
};

const getAnyVariant = (product = {}) => {
  return null;
};

const getDefaultVariant = (product = {}) => {
  return getLegacyVariant(product);
};

const getLegacyVariant = (product = {}) => ({
  _id: null,
  name: product?.name || 'Default',
  sku: product?.sku || '',
  attributes: [],
  mrp: toPositiveNumber(product?.mrp),
  retailPrice: toPositiveNumber(product?.retailPrice),
  wholesalePrice: toPositiveNumber(product?.wholesalePrice),
  stock: toPositiveNumber(product?.stock),
  lowStockThreshold: toPositiveNumber(product?.lowStockThreshold, 5),
  minOrderQuantity: toPositiveNumber(product?.minWholesaleQuantity, 1),
  priceUnit: product?.priceUnit || '',
  packing: product?.packing || '',
  isActive: true,
  order: 0,
});

const getVariantById = (product = {}, variantId) => {
  const normalizedVariantId = normalizeObjectIdLike(variantId);

  return {
    variant: getLegacyVariant(product),
    variantId: null,
    isLegacy: true,
  };
};

// Returns the brand/category discount that actually applies for the role
// (a discount needs an MRP to be taken off).
const getActiveRoleDiscount = (variant, discounts, isWholesaler) => {
  const discount = isWholesaler ? discounts?.wholesaler : discounts?.buyer;
  if (!discount || !(toPositiveNumber(variant?.mrp) > 0)) return null;
  return discount;
};

const getPriceForUser = (product = {}, userRole = USER_ROLES.BUYER, variantInput = null, discounts = null) => {
  const variant = variantInput || getDefaultVariant(product) || getLegacyVariant(product);
  const isWholesaler = userRole === USER_ROLES.WHOLESALER;
  const mrp = toPositiveNumber(variant?.mrp);

  const baseRetailPrice = toPositiveNumber(variant?.retailPrice);
  const baseWholesalePrice = toPositiveNumber(variant?.wholesalePrice);
  const buyerDiscount = getActiveRoleDiscount(variant, discounts, false);
  const wholesalerDiscount = getActiveRoleDiscount(variant, discounts, true);

  // A discount always replaces the stored price for that role.
  const retailPrice = buyerDiscount ? applyMrpDiscount(mrp, buyerDiscount.percent) : baseRetailPrice;
  const wholesalePrice = wholesalerDiscount ? applyMrpDiscount(mrp, wholesalerDiscount.percent) : baseWholesalePrice;
  const roleDiscount = isWholesaler ? wholesalerDiscount : buyerDiscount;

  return {
    price: isWholesaler ? wholesalePrice : retailPrice,
    basePrice: isWholesaler ? baseWholesalePrice : baseRetailPrice,
    mrp,
    retailPrice,
    wholesalePrice,
    discountPercent: roleDiscount ? roleDiscount.percent : null,
    discountSource: roleDiscount ? roleDiscount.source : null,
    discountSourceName: roleDiscount ? roleDiscount.sourceName : null,
    minWholesaleQuantity: toPositiveNumber(product?.minWholesaleQuantity, 1),
    negotiationEnabled: Boolean(product?.negotiationEnabled),
    canNegotiate: isWholesaler && Boolean(product?.negotiationEnabled),
  };
};

// Buyer and wholesaler pricing side by side, for admin/staff screens.
const getEffectivePricing = (product = {}, discounts = null) => {
  const pick = (pricing) => ({
    price: pricing.price,
    basePrice: pricing.basePrice,
    discountPercent: pricing.discountPercent,
    discountSource: pricing.discountSource,
    discountSourceName: pricing.discountSourceName,
  });
  return {
    buyer: pick(getPriceForUser(product, USER_ROLES.BUYER, null, discounts)),
    wholesaler: pick(getPriceForUser(product, USER_ROLES.WHOLESALER, null, discounts)),
  };
};

const getPendingPriceChangeForUser = (product = {}, userRole = USER_ROLES.BUYER, variantInput = null, discounts = null) => {
  const variant = variantInput || getDefaultVariant(product) || getLegacyVariant(product);
  const isWholesaler = userRole === USER_ROLES.WHOLESALER;
  // A brand/category discount sets the price from MRP, so a scheduled
  // retail/wholesale change has no effect for this role.
  if (getActiveRoleDiscount(variant, discounts, isWholesaler)) {
    return null;
  }
  const currentPrice = isWholesaler
    ? toPositiveNumber(variant?.wholesalePrice)
    : toPositiveNumber(variant?.retailPrice);
  const pendingPrice = isWholesaler
    ? (variant?.pendingWholesalePrice ?? product?.pendingWholesalePrice)
    : (variant?.pendingRetailPrice ?? product?.pendingRetailPrice);
  const effectiveAt = variant?.priceChangeEffectiveAt || product?.priceChangeEffectiveAt || null;
  const scheduledAt = variant?.priceChangeScheduledAt || product?.priceChangeScheduledAt || null;

  if (pendingPrice === null || pendingPrice === undefined || !effectiveAt) {
    return null;
  }

  const nextPrice = toPositiveNumber(pendingPrice);
  if (nextPrice === currentPrice) {
    return null;
  }

  return {
    currentPrice,
    newPrice: nextPrice,
    scheduledAt,
    effectiveAt,
    scope: 'product',
    targetRole: isWholesaler ? USER_ROLES.WHOLESALER : USER_ROLES.BUYER,
  };
};

const getVariantStock = (variant = {}) => toPositiveNumber(variant?.stock);

const getProductStockTotal = (product = {}) => {
  return toPositiveNumber(product?.stock);
};

const buildVariantAttributes = (attributes = []) => {
  if (!Array.isArray(attributes)) return [];

  return attributes
    .map((item) => ({
      key: String(item?.key || '').trim(),
      value: String(item?.value || '').trim(),
    }))
    .filter((item) => item.key && item.value);
};

const getVariantDisplayName = (product = {}, variant = {}) => {
  const baseName = String(product?.name || '').trim();
  const variantName = String(variant?.name || '').trim();

  if (!variantName || variantName.toLowerCase() === baseName.toLowerCase()) {
    return baseName || variantName;
  }

  return baseName ? `${baseName} - ${variantName}` : variantName;
};

const serializeVariantForUser = (product = {}, variant = {}, userRole = USER_ROLES.BUYER) => {
  const pricing = getPriceForUser(product, userRole, variant);
  const stock = getVariantStock(variant);
  const variantId = normalizeObjectIdLike(variant?._id);

  return {
    id: variantId,
    name: String(variant?.name || '').trim(),
    displayName: getVariantDisplayName(product, variant),
    sku: String(variant?.sku || '').trim(),
    attributes: buildVariantAttributes(variant?.attributes),
    mrp: pricing.mrp,
    price: pricing.price,
    retailPrice: pricing.retailPrice,
    wholesalePrice: pricing.wholesalePrice,
    stock,
    inStock: stock > 0,
    lowStockThreshold: toPositiveNumber(variant?.lowStockThreshold, 5),
    minOrderQuantity: toPositiveNumber(variant?.minOrderQuantity, 1),
    priceUnit: String(variant?.priceUnit || '').trim(),
    packing: String(variant?.packing || '').trim(),
    isActive: variant?.isActive !== false,
    order: Number(variant?.order || 0),
    pendingPriceChange: getPendingPriceChangeForUser(product, userRole, variant),
  };
};

const buildVariantSnapshot = (product = {}, variant = {}) => ({
  name: '',
  displayName: '',
  sku: '',
  attributes: [],
  packing: String(product?.packing || '').trim(),
  priceUnit: String(product?.priceUnit || '').trim(),
});

const normalizeVariantsForPersistence = (variants = [], product = {}) => {
  return [];
};

const applyVariantSummaryToProduct = (product = {}) => {
  return product;
};

module.exports = {
  normalizeObjectIdLike,
  hasRealVariants,
  getActiveVariants,
  getDefaultVariant,
  getLegacyVariant,
  getVariantById,
  getPriceForUser,
  getEffectivePricing,
  getPendingPriceChangeForUser,
  getVariantStock,
  getProductStockTotal,
  serializeVariantForUser,
  buildVariantSnapshot,
  normalizeVariantsForPersistence,
  applyVariantSummaryToProduct,
  getVariantDisplayName,
};
