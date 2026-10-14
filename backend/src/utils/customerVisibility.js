const mongoose = require('mongoose');
const { USER_ROLES } = require('./constants');

// Brands and top-level categories can be marked "hide from customers". Then
// only wholesalers and the team see them (and their subcategories and
// products); retail customers and anyone not signed in (app guests, the
// public website) don't.

const SEES_HIDDEN_CATALOG = new Set([USER_ROLES.WHOLESALER, USER_ROLES.ADMIN, USER_ROLES.STAFF]);
const canSeeHiddenCatalog = (user) => SEES_HIDDEN_CATALOG.has(user?.role);

// The hidden lists change rarely; each server process keeps them briefly.
// Admin changes clear this process's copy at once (others within CACHE_MS).
const CACHE_MS = 30 * 1000;
let cached = null;

const idString = (value) => (value?._id ?? value) ? String(value?._id ?? value) : null;

async function loadHiddenCatalog() {
  const { Company, Category } = require('../models');
  const [brands, topCategories] = await Promise.all([
    Company.find({ hideFromCustomers: true }).select('_id').lean(),
    Category.find({ hideFromCustomers: true, parent: null }).select('_id').lean(),
  ]);
  const brandIds = new Set(brands.map((brand) => String(brand._id)));
  const categoryIds = new Set(topCategories.map((category) => String(category._id)));

  // Subcategories (any depth) of hidden categories are hidden too.
  let frontier = [...categoryIds];
  while (frontier.length > 0) {
    const children = await Category.find({ parent: { $in: frontier } }).select('_id').lean();
    frontier = children.map((child) => String(child._id)).filter((id) => !categoryIds.has(id));
    frontier.forEach((id) => categoryIds.add(id));
  }
  return { brandIds, categoryIds };
}

async function getHiddenCatalog() {
  if (cached && Date.now() - cached.at < CACHE_MS) return cached;
  cached = { ...(await loadHiddenCatalog()), at: Date.now() };
  return cached;
}

function clearHiddenCatalogCache() {
  cached = null;
}

// Brands an admin hid from this one customer (Customer Profile). Only for
// customers and wholesalers; the team always sees everything.
const PERSONAL_HIDING_ROLES = new Set([USER_ROLES.BUYER, USER_ROLES.WHOLESALER]);
const personalHiddenBrands = (user) => (
  PERSONAL_HIDING_ROLES.has(user?.role) && Array.isArray(user.hiddenBrands)
    ? new Set(user.hiddenBrands.map(idString).filter(Boolean))
    : new Set()
);

/** What this user must not see, or null when they may see everything. */
async function hiddenCatalogFor(user) {
  const personal = personalHiddenBrands(user);
  const shared = canSeeHiddenCatalog(user) ? null : await getHiddenCatalog();
  const brandIds = new Set([...(shared?.brandIds || []), ...personal]);
  const categoryIds = shared?.categoryIds || new Set();
  return brandIds.size > 0 || categoryIds.size > 0 ? { brandIds, categoryIds } : null;
}

const toObjectIds = (ids) => [...ids].map((id) => new mongoose.Types.ObjectId(id));

/** Conditions that keep hidden products out of a product query (also works in aggregates). */
function hiddenProductConditions(hidden) {
  if (!hidden) return [];
  const conditions = [];
  if (hidden.brandIds.size > 0) conditions.push({ company: { $nin: toObjectIds(hidden.brandIds) } });
  if (hidden.categoryIds.size > 0) conditions.push({ categoryRef: { $nin: toObjectIds(hidden.categoryIds) } });
  return conditions;
}

/** Adds the hidden-catalog rule for this user to a product query (mutates and returns it). */
async function applyCustomerVisibility(query, user) {
  const conditions = hiddenProductConditions(await hiddenCatalogFor(user));
  if (conditions.length > 0) {
    query.$and = [...(Array.isArray(query.$and) ? query.$and : []), ...conditions];
  }
  return query;
}

const isBrandHidden = (brand, hidden) => Boolean(hidden && hidden.brandIds.has(idString(brand)));

const isCategoryHidden = (category, hidden) => Boolean(
  hidden && category && (
    hidden.categoryIds.has(idString(category))
    || hidden.brandIds.has(idString(category.company))
  )
);

const isProductHidden = (product, hidden) => Boolean(
  hidden && product && (
    hidden.brandIds.has(idString(product.company))
    || hidden.categoryIds.has(idString(product.categoryRef))
  )
);

// Banner links look like /brand/<id>, /category/<id> or /product/<id>.
const BANNER_LINK = /^\/(brand|category|product)\/([a-f0-9]{24})(?:[/?#]|$)/i;

/** Banners without the ones that open something hidden from this customer. */
async function withoutHiddenBanners(banners, hidden) {
  if (!hidden || !Array.isArray(banners) || banners.length === 0) return banners;
  const links = banners.map((banner) => String(banner?.linkUrl || '').trim().match(BANNER_LINK));
  const ids = (kind) => [...new Set(links.filter((m) => m && m[1].toLowerCase() === kind).map((m) => m[2].toLowerCase()))];

  const { Category, Product } = require('../models');
  const [categories, products] = await Promise.all([
    ids('category').length ? Category.find({ _id: { $in: ids('category') } }).select('_id company').lean() : [],
    ids('product').length ? Product.find({ _id: { $in: ids('product') } }).select('_id company categoryRef').lean() : [],
  ]);
  const categoryById = new Map(categories.map((c) => [String(c._id), c]));
  const productById = new Map(products.map((p) => [String(p._id), p]));

  return banners.filter((banner, index) => {
    const match = links[index];
    if (!match) return true;
    const kind = match[1];
    const id = match[2].toLowerCase();
    switch (kind.toLowerCase()) {
      case 'brand': return !hidden.brandIds.has(id);
      case 'category': return !isCategoryHidden(categoryById.get(id) || { _id: id }, hidden);
      default: return !isProductHidden(productById.get(id), hidden);
    }
  });
}

module.exports = {
  canSeeHiddenCatalog,
  getHiddenCatalog,
  clearHiddenCatalogCache,
  hiddenCatalogFor,
  hiddenProductConditions,
  applyCustomerVisibility,
  isBrandHidden,
  isCategoryHidden,
  isProductHidden,
  personalHiddenBrands,
  withoutHiddenBanners,
};
