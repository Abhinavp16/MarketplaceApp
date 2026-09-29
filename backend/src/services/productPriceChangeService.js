const { PriceChangeAudit } = require('../models');
const { BadRequestError } = require('../utils/errors');

const PRICE_CHANGE_MODE_IMMEDIATE = 'immediate';
const PRICE_CHANGE_MODE_24H = 'schedule_24h';
const PRICE_CHANGE_MODE_48H = 'schedule_48h';
const PRICE_CHANGE_MODE_CUSTOM = 'custom';

const PRICE_CHANGE_MODES = [
  PRICE_CHANGE_MODE_IMMEDIATE,
  PRICE_CHANGE_MODE_24H,
  PRICE_CHANGE_MODE_48H,
  PRICE_CHANGE_MODE_CUSTOM,
];

function clearPendingPriceFields(target) {
  target.pendingRetailPrice = null;
  target.pendingWholesalePrice = null;
  target.priceChangeScheduledAt = null;
  target.priceChangeEffectiveAt = null;
  target.pendingPriceChangeAudit = null;
}

function normalizeOptionalPrice(value, fieldName) {
  if (value === undefined || value === null || value === '') {
    return undefined;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new BadRequestError(`${fieldName} must be a non-negative number`, 'INVALID_PRICE');
  }

  return parsed;
}

function resolveEffectiveAt(mode, customEffectiveAt, scheduledAt) {
  if (!PRICE_CHANGE_MODES.includes(mode)) {
    throw new BadRequestError('Invalid price change mode', 'INVALID_PRICE_CHANGE_MODE');
  }

  if (mode === PRICE_CHANGE_MODE_IMMEDIATE) {
    return scheduledAt;
  }

  if (mode === PRICE_CHANGE_MODE_24H) {
    return new Date(scheduledAt.getTime() + 24 * 60 * 60 * 1000);
  }

  if (mode === PRICE_CHANGE_MODE_48H) {
    return new Date(scheduledAt.getTime() + 48 * 60 * 60 * 1000);
  }

  const effectiveAt = new Date(customEffectiveAt);
  if (Number.isNaN(effectiveAt.getTime()) || effectiveAt <= scheduledAt) {
    throw new BadRequestError('Custom effective time must be in the future', 'INVALID_EFFECTIVE_AT');
  }

  return effectiveAt;
}

async function supersedePendingAudit(product, supersededBy) {
  if (!product.pendingPriceChangeAudit) {
    return;
  }

  await PriceChangeAudit.updateOne(
    { _id: product.pendingPriceChangeAudit, status: 'scheduled' },
    {
      $set: {
        status: 'superseded',
        supersededAt: new Date(),
        supersededBy,
      },
    }
  );
}

async function applyProductPriceChange({
  product,
  performedBy,
  retailPrice,
  wholesalePrice,
  mode,
  customEffectiveAt,
  scheduledAt = new Date(),
}) {
  const nextRetailPrice = normalizeOptionalPrice(retailPrice, 'Customer price');
  const nextWholesalePrice = normalizeOptionalPrice(wholesalePrice, 'Wholesale price');
  const retailChanged = nextRetailPrice !== undefined && nextRetailPrice !== Number(product.retailPrice);
  const wholesaleChanged = nextWholesalePrice !== undefined && nextWholesalePrice !== Number(product.wholesalePrice);

  if (!retailChanged && !wholesaleChanged) {
    throw new BadRequestError('Enter at least one price that differs from the current price', 'NO_PRICE_CHANGE');
  }

  const effectiveAt = resolveEffectiveAt(mode, customEffectiveAt, scheduledAt);
  const isImmediate = mode === PRICE_CHANGE_MODE_IMMEDIATE;
  const audit = await PriceChangeAudit.create({
    product: product._id,
    productName: String(product.name || '').trim(),
    productSku: String(product.sku || '').trim(),
    category: String(product.category || '').trim(),
    performedBy: performedBy?._id || performedBy || null,
    performedByName: String(performedBy?.name || '').trim(),
    previousRetailPrice: Number(product.retailPrice),
    newRetailPrice: retailChanged ? nextRetailPrice : null,
    previousWholesalePrice: Number(product.wholesalePrice),
    newWholesalePrice: wholesaleChanged ? nextWholesalePrice : null,
    scheduleType: mode,
    scheduledAt,
    effectiveAt,
    status: isImmediate ? 'applied' : 'scheduled',
    appliedAt: isImmediate ? scheduledAt : null,
  });

  await supersedePendingAudit(product, audit._id);

  if (isImmediate) {
    if (retailChanged) product.retailPrice = nextRetailPrice;
    if (wholesaleChanged) product.wholesalePrice = nextWholesalePrice;
    clearPendingPriceFields(product);
  } else {
    // A reschedule replaces the existing pending change. Only prices entered in
    // this request are scheduled; untouched tiers remain live.
    product.pendingRetailPrice = retailChanged ? nextRetailPrice : null;
    product.pendingWholesalePrice = wholesaleChanged ? nextWholesalePrice : null;
    product.priceChangeScheduledAt = scheduledAt;
    product.priceChangeEffectiveAt = effectiveAt;
    product.pendingPriceChangeAudit = audit._id;
  }

  await product.save();

  return {
    product,
    audit,
    isScheduled: !isImmediate,
  };
}

module.exports = {
  PRICE_CHANGE_MODE_IMMEDIATE,
  PRICE_CHANGE_MODE_24H,
  PRICE_CHANGE_MODE_48H,
  PRICE_CHANGE_MODE_CUSTOM,
  PRICE_CHANGE_MODES,
  clearPendingPriceFields,
  applyProductPriceChange,
};
