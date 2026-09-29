const { Company, Category } = require('../models');
const {
  buildDiscountContext,
  resolveProductDiscounts,
} = require('../utils/productDiscount');

const HAS_DISCOUNT = {
  $or: [
    { customerDiscountPercent: { $gt: 0 } },
    { wholesalerDiscountPercent: { $gt: 0 } },
  ],
};
const DISCOUNT_SELECT = 'name customerDiscountPercent wholesalerDiscountPercent';
const CATEGORY_SELECT = `${DISCOUNT_SELECT} slug company parent`;

const EMPTY_DISCOUNTS = Object.freeze({ buyer: null, wholesaler: null });

// Loads only what is needed: brands with a discount, and the category tree
// only when at least one category has a discount (the tree is needed to walk
// subcategory -> parent).
async function loadDiscountContext() {
  const [companies, discountedCategoryExists] = await Promise.all([
    Company.find(HAS_DISCOUNT).select(DISCOUNT_SELECT).lean(),
    Category.exists(HAS_DISCOUNT),
  ]);

  if (companies.length === 0 && !discountedCategoryExists) return null;

  const categories = discountedCategoryExists
    ? await Category.find({}).select(CATEGORY_SELECT).lean()
    : [];

  return buildDiscountContext({ companies, categories });
}

// Returns Map<productId, { buyer, wholesaler }>. Products need `company`,
// `categoryRef` and `category` loaded (ids or populated docs both work).
async function buildDiscountMap(products = []) {
  const list = (Array.isArray(products) ? products : [products]).filter(Boolean);
  const map = new Map();
  if (list.length === 0) return map;

  const context = await loadDiscountContext();
  for (const product of list) {
    map.set(String(product._id), context ? resolveProductDiscounts(product, context) : EMPTY_DISCOUNTS);
  }
  return map;
}

const discountsFor = (map, product) => (product && map?.get(String(product._id))) || EMPTY_DISCOUNTS;

module.exports = {
  loadDiscountContext,
  buildDiscountMap,
  discountsFor,
  EMPTY_DISCOUNTS,
};
