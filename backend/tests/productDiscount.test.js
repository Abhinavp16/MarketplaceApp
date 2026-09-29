const assert = require('assert');

const {
  applyMrpDiscount,
  buildDiscountContext,
  normalizeDiscountPercent,
  pickDiscountUpdates,
  resolveProductDiscounts,
  stripDiscountFields,
  discountChanged,
  presentDiscountFields,
} = require('../src/utils/productDiscount');
const {
  getPriceForUser,
  getPendingPriceChangeForUser,
  getEffectivePricing,
} = require('../src/utils/productVariants');

const companies = [
  { _id: 'brand-a', name: 'Brand A', customerDiscountPercent: 10, wholesalerDiscountPercent: null },
  { _id: 'brand-b', name: 'Brand B', customerDiscountPercent: 0, wholesalerDiscountPercent: 0 },
];
const categories = [
  { _id: 'pumps', name: 'Pumps', slug: 'pumps', company: 'brand-a', parent: null, wholesalerDiscountPercent: 30 },
  { _id: 'pumps-2hp', name: '2 HP', slug: 'pumps-2-hp', company: 'brand-a', parent: 'pumps', customerDiscountPercent: 5 },
  { _id: 'cable', name: 'Cable', slug: 'cable', company: 'brand-b', parent: null, customerDiscountPercent: 12, wholesalerDiscountPercent: 25 },
  { _id: 'cable-4', name: '4 sqmm', slug: 'cable-4-sqmm', company: 'brand-b', parent: 'cable', customerDiscountPercent: null, wholesalerDiscountPercent: 20 },
  { _id: 'plain', name: 'Plain', slug: 'plain', company: 'brand-c', parent: null },
];
const context = buildDiscountContext({ companies, categories });

// --- Resolution precedence ---
// Brand wins for customers; wholesalers fall through to the parent category.
const pump = { _id: 'p1', company: { _id: 'brand-a', name: 'Brand A' }, categoryRef: 'pumps-2hp', mrp: 1000, retailPrice: 850, wholesalePrice: 700 };
let discounts = resolveProductDiscounts(pump, context);
assert.deepStrictEqual(discounts.buyer, { percent: 10, source: 'brand', sourceId: 'brand-a', sourceName: 'Brand A' });
assert.deepStrictEqual(discounts.wholesaler, { percent: 30, source: 'category', sourceId: 'pumps', sourceName: 'Pumps' });

// Brand 0% = not set -> subcategory first, then parent.
const cable = { _id: 'p2', company: 'brand-b', categoryRef: { _id: 'cable-4', name: '4 sqmm' }, mrp: 1249, retailPrice: 1200, wholesalePrice: 1000 };
discounts = resolveProductDiscounts(cable, context);
assert.strictEqual(discounts.wholesaler.sourceId, 'cable-4');
assert.strictEqual(discounts.wholesaler.percent, 20);
assert.strictEqual(discounts.buyer.sourceId, 'cable');
assert.strictEqual(discounts.buyer.percent, 12);

// Legacy product without categoryRef matches by category name/slug in its brand.
const legacy = { _id: 'p3', company: 'brand-b', category: 'Cable-4-SQMM', mrp: 100 };
assert.strictEqual(resolveProductDiscounts(legacy, context).wholesaler.sourceId, 'cable-4');
// ...but not a same-named category of another brand.
assert.strictEqual(resolveProductDiscounts({ _id: 'p4', company: 'brand-a', category: 'cable' }, context).wholesaler, null);

// Nothing set anywhere.
assert.deepStrictEqual(
  resolveProductDiscounts({ _id: 'p5', company: 'brand-c', categoryRef: 'plain', mrp: 100 }, context),
  { buyer: null, wholesaler: null },
);
assert.deepStrictEqual(resolveProductDiscounts(pump, null), { buyer: null, wholesaler: null });

// Parent cycle does not hang.
const cyclic = buildDiscountContext({
  categories: [
    { _id: 'x', name: 'X', company: 'c', parent: 'y' },
    { _id: 'y', name: 'Y', company: 'c', parent: 'x' },
  ],
});
assert.strictEqual(resolveProductDiscounts({ _id: 'p6', company: 'c', categoryRef: 'x' }, cyclic).buyer, null);

// --- Pricing ---
assert.strictEqual(applyMrpDiscount(1249, 7), 1161.57);
assert.strictEqual(applyMrpDiscount(0, 10), null);
assert.strictEqual(applyMrpDiscount(1000, 0), null);

const pumpDiscounts = resolveProductDiscounts(pump, context);
const buyerPricing = getPriceForUser(pump, 'buyer', null, pumpDiscounts);
assert.strictEqual(buyerPricing.price, 900); // 10% off MRP 1000, replaces retail 850 even though higher
assert.strictEqual(buyerPricing.basePrice, 850);
assert.strictEqual(buyerPricing.retailPrice, 900);
assert.strictEqual(buyerPricing.wholesalePrice, 700); // 30% off MRP
assert.strictEqual(buyerPricing.discountPercent, 10);
assert.strictEqual(buyerPricing.discountSource, 'brand');

const wholesalerPricing = getPriceForUser(pump, 'wholesaler', null, pumpDiscounts);
assert.strictEqual(wholesalerPricing.price, 700);
assert.strictEqual(wholesalerPricing.retailPrice, 900); // suggested selling price stays in sync
assert.strictEqual(wholesalerPricing.discountSource, 'category');
assert.strictEqual(wholesalerPricing.discountSourceName, 'Pumps');

// No MRP -> no discount, normal price.
const noMrp = { ...pump, mrp: 0 };
const noMrpPricing = getPriceForUser(noMrp, 'buyer', null, pumpDiscounts);
assert.strictEqual(noMrpPricing.price, 850);
assert.strictEqual(noMrpPricing.discountPercent, null);

// Without discounts the helper behaves exactly as before.
const plainPricing = getPriceForUser(pump, 'wholesaler');
assert.strictEqual(plainPricing.price, 700);
assert.strictEqual(plainPricing.retailPrice, 850);
assert.strictEqual(plainPricing.discountSource, null);

const effective = getEffectivePricing(pump, pumpDiscounts);
assert.strictEqual(effective.buyer.price, 900);
assert.strictEqual(effective.wholesaler.price, 700);
assert.strictEqual(effective.wholesaler.basePrice, 700);

// Scheduled price change is hidden only for the role whose price comes from a discount.
const scheduled = {
  ...pump,
  pendingRetailPrice: 800,
  pendingWholesalePrice: 650,
  priceChangeEffectiveAt: new Date(Date.now() + 3600 * 1000),
};
const onlyWholesalerDiscount = { buyer: null, wholesaler: pumpDiscounts.wholesaler };
assert.strictEqual(getPendingPriceChangeForUser(scheduled, 'wholesaler', null, onlyWholesalerDiscount), null);
assert.strictEqual(getPendingPriceChangeForUser(scheduled, 'buyer', null, onlyWholesalerDiscount).newPrice, 800);

// --- Admin input handling ---
assert.strictEqual(normalizeDiscountPercent(undefined), undefined);
assert.strictEqual(normalizeDiscountPercent(''), null);
assert.strictEqual(normalizeDiscountPercent(null), null);
assert.strictEqual(normalizeDiscountPercent(0), null);
assert.strictEqual(normalizeDiscountPercent('12.345'), 12.35);
assert.throws(() => normalizeDiscountPercent(101), /between 0 and 100/);
assert.throws(() => normalizeDiscountPercent(-1), /between 0 and 100/);
assert.throws(() => normalizeDiscountPercent('abc'), /between 0 and 100/);
assert.deepStrictEqual(pickDiscountUpdates({ customerDiscountPercent: '5', name: 'x' }), { customerDiscountPercent: 5 });

assert.strictEqual(discountChanged({ customerDiscountPercent: null }, { customerDiscountPercent: 0 }), false);
assert.strictEqual(discountChanged({ customerDiscountPercent: 5 }, { customerDiscountPercent: 6 }), true);

const stripped = stripDiscountFields([{ name: 'A', customerDiscountPercent: 5, wholesalerDiscountPercent: 9, subcategories: [{ name: 'B', wholesalerDiscountPercent: 3 }] }]);
assert.deepStrictEqual(stripped, [{ name: 'A', subcategories: [{ name: 'B' }] }]);

// Admins always get both keys (null when unset); everyone else gets neither.
assert.deepStrictEqual(
  presentDiscountFields({ user: { role: 'admin' } }, [{ name: 'Old brand' }]),
  [{ name: 'Old brand', customerDiscountPercent: null, wholesalerDiscountPercent: null }],
);
assert.deepStrictEqual(presentDiscountFields({ user: { role: 'buyer' } }, { name: 'B', customerDiscountPercent: 5 }), { name: 'B' });
assert.deepStrictEqual(presentDiscountFields({}, { name: 'B', wholesalerDiscountPercent: 5 }), { name: 'B' });

console.log('productDiscount tests passed');
