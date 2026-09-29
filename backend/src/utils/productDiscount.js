const { BadRequestError } = require('./errors');

// Brand/category discounts are a percentage off MRP, set separately for
// customers (buyer role) and wholesalers. Resolution order per role:
// brand -> product's category -> parent categories (nearest first).
// null/0 means "not set" and falls through to the next level.
const DISCOUNT_FIELDS = Object.freeze({
  buyer: 'customerDiscountPercent',
  wholesaler: 'wholesalerDiscountPercent',
});
const DISCOUNT_FIELD_NAMES = Object.freeze(Object.values(DISCOUNT_FIELDS));

const round2 = (value) => Math.round((Number(value) + Number.EPSILON) * 100) / 100;

const idOf = (value) => {
  if (!value) return '';
  return String(value._id || value.id || value);
};

const activePercent = (value) => {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 && number <= 100 ? number : null;
};

// Validates admin input. Returns undefined when the field is absent,
// null when cleared, otherwise a number rounded to 2 decimals.
const normalizeDiscountPercent = (value, fieldName = 'discount') => {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0 || number > 100) {
    throw new BadRequestError(`${fieldName} must be between 0 and 100`, 'INVALID_DISCOUNT_PERCENT');
  }
  return number === 0 ? null : round2(number);
};

const pickDiscountUpdates = (body = {}) => {
  const updates = {};
  for (const field of DISCOUNT_FIELD_NAMES) {
    const normalized = normalizeDiscountPercent(body[field], field);
    if (normalized !== undefined) updates[field] = normalized;
  }
  return updates;
};

const discountSnapshot = (entity = {}) => ({
  customerDiscountPercent: activePercent(entity?.customerDiscountPercent),
  wholesalerDiscountPercent: activePercent(entity?.wholesalerDiscountPercent),
});

const discountChanged = (before = {}, after = {}) => DISCOUNT_FIELD_NAMES
  .some((field) => activePercent(before[field]) !== activePercent(after[field]));

const stripDiscountFields = (entity) => {
  if (!entity || typeof entity !== 'object') return entity;
  if (Array.isArray(entity)) return entity.map(stripDiscountFields);
  const plain = typeof entity.toObject === 'function' ? entity.toObject() : { ...entity };
  for (const field of DISCOUNT_FIELD_NAMES) delete plain[field];
  if (Array.isArray(plain.subcategories)) {
    plain.subcategories = plain.subcategories.map(stripDiscountFields);
  }
  return plain;
};

const canSeeDiscountFields = (req) => req?.user?.role === 'admin';

// For admins, always send both keys (null when unset) so the admin UI can tell
// "no discount" apart from "fields were stripped" (e.g. expired token).
const ensureDiscountFields = (entity) => {
  if (!entity || typeof entity !== 'object') return entity;
  if (Array.isArray(entity)) return entity.map(ensureDiscountFields);
  const plain = typeof entity.toObject === 'function' ? entity.toObject() : { ...entity };
  for (const field of DISCOUNT_FIELD_NAMES) {
    if (plain[field] === undefined) plain[field] = null;
  }
  return plain;
};

const presentDiscountFields = (req, entity) => (
  canSeeDiscountFields(req) ? ensureDiscountFields(entity) : stripDiscountFields(entity)
);

const applyMrpDiscount = (mrp, percent) => {
  const base = Number(mrp);
  const pct = activePercent(percent);
  if (!Number.isFinite(base) || base <= 0 || pct === null) return null;
  return round2(base * (1 - pct / 100));
};

const normalizeLegacyName = (value) => String(value || '')
  .trim()
  .toLowerCase()
  .split(/[-_\s]+/)
  .filter(Boolean)
  .join(' ');

// companies / categories are lean docs with at least
// _id, name, slug, company, parent and the discount fields.
const buildDiscountContext = ({ companies = [], categories = [] } = {}) => {
  const companiesById = new Map();
  for (const company of companies) companiesById.set(idOf(company), company);

  const categoriesById = new Map();
  const legacyIndex = new Map();
  for (const category of categories) {
    categoriesById.set(idOf(category), category);
    const companyKey = idOf(category.company);
    for (const label of [category.name, category.slug]) {
      const key = `${companyKey}|${normalizeLegacyName(label)}`;
      if (!legacyIndex.has(key)) legacyIndex.set(key, category);
    }
  }

  return { companiesById, categoriesById, legacyIndex };
};

const findProductCategory = (product = {}, context) => {
  const refId = idOf(product.categoryRef);
  if (refId && context.categoriesById.has(refId)) {
    return context.categoriesById.get(refId);
  }
  if (!product.category) return null;
  return context.legacyIndex.get(`${idOf(product.company)}|${normalizeLegacyName(product.category)}`) || null;
};

const resolveRoleDiscount = (product, field, context) => {
  const company = context.companiesById.get(idOf(product.company));
  const brandPercent = activePercent(company?.[field]);
  if (brandPercent !== null) {
    return {
      percent: brandPercent,
      source: 'brand',
      sourceId: idOf(company),
      sourceName: company.name || '',
    };
  }

  const visited = new Set();
  let category = findProductCategory(product, context);
  while (category && !visited.has(idOf(category))) {
    visited.add(idOf(category));
    const categoryPercent = activePercent(category[field]);
    if (categoryPercent !== null) {
      return {
        percent: categoryPercent,
        source: 'category',
        sourceId: idOf(category),
        sourceName: category.name || '',
      };
    }
    const parentId = idOf(category.parent);
    category = parentId ? context.categoriesById.get(parentId) : null;
  }

  return null;
};

const resolveProductDiscounts = (product = {}, context = null) => {
  if (!context) return { buyer: null, wholesaler: null };
  return {
    buyer: resolveRoleDiscount(product, DISCOUNT_FIELDS.buyer, context),
    wholesaler: resolveRoleDiscount(product, DISCOUNT_FIELDS.wholesaler, context),
  };
};

module.exports = {
  DISCOUNT_FIELDS,
  DISCOUNT_FIELD_NAMES,
  round2,
  activePercent,
  normalizeDiscountPercent,
  pickDiscountUpdates,
  discountSnapshot,
  discountChanged,
  stripDiscountFields,
  canSeeDiscountFields,
  ensureDiscountFields,
  presentDiscountFields,
  applyMrpDiscount,
  buildDiscountContext,
  resolveProductDiscounts,
};
