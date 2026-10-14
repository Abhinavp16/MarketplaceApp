const assert = require('assert');
const {
  isComingSoon,
  comingSoonPayload,
  hidePriceIfNeeded,
  assertPurchasable,
  purchaseBlockCode,
} = require('../src/utils/productAvailability');

const now = new Date('2026-10-01T10:00:00Z');
const tomorrow = new Date('2026-10-02T10:00:00Z');
const yesterday = new Date('2026-09-30T10:00:00Z');

// Coming soon until the admin turns it off, or the auto-launch date passes.
assert.strictEqual(isComingSoon({ comingSoon: { enabled: true } }, now), true);
assert.strictEqual(isComingSoon({ comingSoon: { enabled: false } }, now), false);
assert.strictEqual(isComingSoon({}, now), false);
assert.strictEqual(isComingSoon({ comingSoon: { enabled: true, autoLaunch: true, expectedDate: tomorrow } }, now), true);
assert.strictEqual(isComingSoon({ comingSoon: { enabled: true, autoLaunch: true, expectedDate: yesterday } }, now), false);
// A date without auto-launch is only shown; the admin launches by hand.
assert.strictEqual(isComingSoon({ comingSoon: { enabled: true, autoLaunch: false, expectedDate: yesterday } }, now), true);

// API payload and hidden prices.
assert.deepStrictEqual(
  comingSoonPayload({ comingSoon: { enabled: true, showPrice: false, expectedDate: tomorrow } }, now),
  { comingSoon: true, expectedDate: tomorrow, priceHidden: true },
);
assert.deepStrictEqual(
  comingSoonPayload({ comingSoon: { enabled: true } }, now),
  { comingSoon: true, expectedDate: null, priceHidden: false },
);
assert.deepStrictEqual(comingSoonPayload({}, now), { comingSoon: false, expectedDate: null, priceHidden: false });
const hidden = hidePriceIfNeeded({ name: 'Pump', price: 9000, mrp: 9800, retailPrice: 9500, wholesalePrice: 9000, discountPercent: 5, pendingPriceChange: { x: 1 }, priceHidden: true });
assert.deepStrictEqual(
  [hidden.price, hidden.mrp, hidden.retailPrice, hidden.wholesalePrice, hidden.discountPercent, hidden.pendingPriceChange, hidden.name],
  [null, null, null, null, null, null, 'Pump'],
);
assert.strictEqual(hidePriceIfNeeded({ price: 10, priceHidden: false }).price, 10);

// Buying is blocked for coming-soon and draft/archived products.
assert.strictEqual(purchaseBlockCode({ status: 'active' }, now), null);
assert.strictEqual(purchaseBlockCode({ status: 'active', comingSoon: { enabled: true } }, now), 'PRODUCT_COMING_SOON');
assert.strictEqual(purchaseBlockCode({ status: 'draft' }, now), 'PRODUCT_UNAVAILABLE');
assert.strictEqual(purchaseBlockCode({ status: 'archived', comingSoon: { enabled: true } }, now), 'PRODUCT_UNAVAILABLE');
assert.strictEqual(purchaseBlockCode(null, now), 'PRODUCT_UNAVAILABLE');
assert.strictEqual(purchaseBlockCode({ name: 'Old record' }, now), null);
assert.throws(() => assertPurchasable({ status: 'active', name: 'Pump', comingSoon: { enabled: true } }, now), (e) => e.code === 'PRODUCT_COMING_SOON' && e.statusCode === 409);
assert.throws(() => assertPurchasable({ status: 'draft', name: 'Pump' }, now), (e) => e.code === 'PRODUCT_UNAVAILABLE');
assert.doesNotThrow(() => assertPurchasable({ status: 'active', comingSoon: { enabled: true, autoLaunch: true, expectedDate: yesterday } }, now));

// The "now available" message is kept in the in-app notification list.
const Notification = require('../src/models/Notification');
const launched = new Notification({ userId: '64b000000000000000000001', title: 'Now available!', body: 'Pump is now available.', type: 'product_launched' });
assert.strictEqual(launched.validateSync(), undefined);

console.log('productAvailability tests passed');
