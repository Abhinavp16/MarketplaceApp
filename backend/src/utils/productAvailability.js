// "Coming Soon" products: listed with a badge but not yet for sale.
// A product stops being coming soon when the admin turns it off, or by itself
// on its expected date when auto-launch is on (so it works even if no timer
// runs on the server).
const { BadRequestError, ConflictError } = require('./errors');

// A missing status (old records read without defaults) counts as active.
const isActiveStatus = (product) => !product?.status || product.status === 'active';

const PRICE_FIELDS = ['price', 'basePrice', 'mrp', 'retailPrice', 'wholesalePrice', 'discountPercent'];

function isComingSoon(product = {}, now = new Date()) {
  const comingSoon = product?.comingSoon;
  if (!comingSoon?.enabled) return false;
  if (comingSoon.autoLaunch && comingSoon.expectedDate) {
    return new Date(comingSoon.expectedDate).getTime() > new Date(now).getTime();
  }
  return true;
}

// Fields added to product API responses.
function comingSoonPayload(product = {}, now = new Date()) {
  const comingSoon = isComingSoon(product, now);
  return {
    comingSoon,
    expectedDate: comingSoon ? product.comingSoon?.expectedDate || null : null,
    priceHidden: comingSoon && product.comingSoon?.showPrice === false,
  };
}

// Prices are never sent for coming-soon products whose price is hidden.
function hidePriceIfNeeded(payload) {
  if (!payload?.priceHidden) return payload;
  const copy = { ...payload };
  for (const field of PRICE_FIELDS) {
    if (field in copy) copy[field] = null;
  }
  copy.pendingPriceChange = null;
  return copy;
}

// Throws when a product can't be added to a cart, ordered or requested.
function assertPurchasable(product, now = new Date()) {
  if (!product || !isActiveStatus(product)) {
    throw new BadRequestError(
      `${product?.name || 'This product'} is not available`,
      'PRODUCT_UNAVAILABLE',
    );
  }
  if (isComingSoon(product, now)) {
    throw new ConflictError(
      `${product.name} is coming soon and can't be ordered yet`,
      'PRODUCT_COMING_SOON',
    );
  }
}

// Same check without throwing: null when purchasable, otherwise the code.
function purchaseBlockCode(product, now = new Date()) {
  if (!product || !isActiveStatus(product)) return 'PRODUCT_UNAVAILABLE';
  if (isComingSoon(product, now)) return 'PRODUCT_COMING_SOON';
  return null;
}

module.exports = {
  isComingSoon,
  comingSoonPayload,
  hidePriceIfNeeded,
  assertPurchasable,
  purchaseBlockCode,
};
