const assert = require('assert');

// Brands hidden from one customer on their Customer Profile: that customer
// (retail or wholesaler) doesn't see them, their categories or products, can't
// buy them and isn't told about their price changes; nobody else is affected.
// Runs against a database on this machine only (never the live database):
//
//   CUSTOMER_BRANDS_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/customer_brands_test node tests/customerHiddenBrands.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.RATE_LIMIT_MAX_REQUESTS = '5000';

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

async function run(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const M = require('../src/models');
  const { signAccessToken } = require('../src/utils/jwtTokens');
  const { clearHiddenCatalogCache } = require('../src/utils/customerVisibility');
  const notificationService = require('../src/services/notificationService');
  const { flushDuePriceChangeNotification, QUIET_MS } = require('../src/services/priceChangeNotificationService');

  const pushes = [];
  notificationService.sendToMultipleDevices = async (tokens, message, data) => {
    pushes.push({ tokens: [...tokens], message, data });
    return { successCount: tokens.length, failureCount: 0 };
  };

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  await mongoose.connection.db.dropDatabase();
  await M.PriceChangeNotificationBatch.syncIndexes();

  const brand = (name, extra = {}) => M.Company.create({ name, slug: name.toLowerCase().replace(/\s+/g, '-'), ...extra });
  const brandA = await brand('Brand Alpha');
  const brandB = await brand('Brand Beta');
  const brandC = await brand('Brand Gamma', { hideFromCustomers: true });
  const setup = async (b, label) => {
    const category = await M.Category.create({ name: `${label} Pumps`, slug: `${label.toLowerCase()}-pumps`, company: b._id });
    const product = await M.Product.create({
      name: `${label} Pump`, slug: `${label.toLowerCase()}-pump`, sku: `HB-${label}`, category: category.name, categoryRef: category._id, company: b._id,
      mrp: 1000, retailPrice: 900, wholesalePrice: 800, stock: 100, status: 'active',
    });
    return { category, product };
  };
  const A = await setup(brandA, 'Alpha');
  const B = await setup(brandB, 'Beta');
  const C = await setup(brandC, 'Gamma');
  clearHiddenCatalogCache();

  const user = (role, name, extra = {}) => M.User.create({ name, email: `${name.toLowerCase().replace(/\s+/g, '')}@example.com`, authProvider: 'email', role, isActive: true, ...extra });
  const buyerHidesA = await user('buyer', 'Buyer One', { hiddenBrands: [brandA._id] });
  const buyerPlain = await user('buyer', 'Buyer Two');
  const wholesalerHidesB = await user('wholesaler', 'Dealer One', { hiddenBrands: [brandB._id] });
  const wholesalerPlain = await user('wholesaler', 'Dealer Two');
  const admin = await user('admin', 'Admin');
  const staff = await user('staff', 'Member', { hiddenBrands: [brandA._id] });
  for (const u of [buyerHidesA, buyerPlain, wholesalerHidesB, wholesalerPlain]) {
    await M.DeviceToken.create({ userId: u._id, fcmToken: `token-${u._id}`, platform: 'android', isActive: true });
  }
  const token = (u) => signAccessToken({ userId: String(u._id) }, '10m');

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (method, path, { as, body } = {}) => {
    const res = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json', ...(as ? { Authorization: `Bearer ${token(as)}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
    const text = await res.text();
    let json = {};
    try { json = JSON.parse(text); } catch { /* not JSON */ }
    return { status: res.status, text, body: json };
  };
  const brandNames = async (as) => (await call('GET', '/companies?limit=500', { as })).body.data.map((b) => b.name).sort();
  const searchIds = async (as) => (await call('GET', '/products/search?q=pump', { as })).body.data.map((p) => p.slug).sort();

  try {
    // Retail customer with Alpha hidden: no Alpha, and no Gamma (hidden from all retail).
    assert.deepStrictEqual(await brandNames(buyerHidesA), ['Brand Beta']);
    assert.deepStrictEqual(await searchIds(buyerHidesA), ['beta-pump']);
    assert.strictEqual((await call('GET', `/products/${A.product.slug}`, { as: buyerHidesA })).status, 404);
    assert.strictEqual((await call('GET', `/companies/${brandA._id}`, { as: buyerHidesA })).status, 404);
    assert.strictEqual((await call('GET', `/categories/${A.category._id}`, { as: buyerHidesA })).status, 404);
    let res = await call('POST', '/cart/items', { as: buyerHidesA, body: { productId: String(A.product._id), quantity: 1 } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'PRODUCT_UNAVAILABLE');
    // Other customers are unaffected.
    assert.deepStrictEqual(await brandNames(buyerPlain), ['Brand Alpha', 'Brand Beta']);
    assert.strictEqual((await call('GET', `/products/${A.product.slug}`, { as: buyerPlain })).status, 200);

    // Wholesaler with Beta hidden: sees Alpha and Gamma, not Beta.
    assert.deepStrictEqual(await brandNames(wholesalerHidesB), ['Brand Alpha', 'Brand Gamma']);
    assert.deepStrictEqual(await searchIds(wholesalerHidesB), ['alpha-pump', 'gamma-pump']);
    res = await call('POST', '/cart/items', { as: wholesalerHidesB, body: { productId: String(B.product._id), quantity: 10 } });
    assert.strictEqual(res.status, 400, 'wholesaler cannot buy a brand hidden from them');
    assert.deepStrictEqual(await brandNames(wholesalerPlain), ['Brand Alpha', 'Brand Beta', 'Brand Gamma']);

    // The team is never restricted, even if a list was set on them.
    assert.deepStrictEqual(await brandNames(staff), ['Brand Alpha', 'Brand Beta', 'Brand Gamma']);

    // The customer's app is never told which brands are hidden from them.
    res = await call('GET', '/auth/me', { as: buyerHidesA });
    assert.strictEqual(res.status, 200);
    assert.ok(!('hiddenBrands' in res.body.data), 'not sent to the app');
    assert.ok(!res.text.includes(String(brandA._id)));

    // Admin endpoint.
    res = await call('PUT', `/admin/customers/${buyerPlain._id}/brand-access`, { as: buyerPlain, body: { hiddenBrands: [] } });
    assert.strictEqual(res.status, 403, 'customers cannot change it');
    res = await call('PUT', `/admin/customers/${buyerPlain._id}/brand-access`, { as: admin, body: { hiddenBrands: ['nope'] } });
    assert.strictEqual(res.status, 400);
    res = await call('PUT', `/admin/customers/${buyerPlain._id}/brand-access`, { as: admin, body: { hiddenBrands: [String(new mongoose.Types.ObjectId())] } });
    assert.strictEqual(res.body.error.code, 'BRAND_NOT_FOUND');
    res = await call('PUT', `/admin/customers/${admin._id}/brand-access`, { as: admin, body: { hiddenBrands: [] } });
    assert.strictEqual(res.status, 404, 'only customers and wholesalers');
    res = await call('PUT', `/admin/customers/${buyerPlain._id}/brand-access`, { as: admin, body: { hiddenBrands: [String(brandB._id)] } });
    assert.strictEqual(res.status, 200, res.text);
    assert.deepStrictEqual(res.body.data.hiddenBrands, [String(brandB._id)]);
    assert.deepStrictEqual(await brandNames(buyerPlain), ['Brand Alpha'], 'takes effect on the next request');
    assert.ok(await M.AuditLog.exists({ action: 'customer.hidden_brands_updated', entityId: buyerPlain._id }));
    res = await call('GET', `/admin/customers/${buyerPlain._id}`, { as: admin });
    assert.deepStrictEqual(res.body.data.hiddenBrands.map(String), [String(brandB._id)], 'admin sees the list');
    await call('PUT', `/admin/customers/${buyerPlain._id}/brand-access`, { as: admin, body: { hiddenBrands: [] } });
    assert.deepStrictEqual(await brandNames(buyerPlain), ['Brand Alpha', 'Brand Beta'], 'cleared');

    // Price updates: nobody hears about a brand hidden from them.
    const change = (p, body) => call('PUT', `/admin/products/${p._id}/price-change`, { as: admin, body: { priceChangeMode: 'immediate', ...body } });
    await change(A.product, { retailPrice: 950, wholesalePrice: 850 });
    await change(B.product, { retailPrice: 960, wholesalePrice: 860 });
    const batch = await M.PriceChangeNotificationBatch.findOne({ status: 'pending' }).lean();
    const summary = await flushDuePriceChangeNotification({ now: new Date(batch.lastChangeAt.getTime() + QUIET_MS + 1000) });
    assert.deepStrictEqual(summary.customers, { products: 2, users: 2 });
    const pushTo = (u) => pushes.find((p) => p.tokens.includes(`token-${u._id}`));
    assert.strictEqual(pushTo(buyerHidesA).message.body, 'The price of Beta Pump has changed. Open the app to see it.');
    assert.strictEqual(pushTo(buyerPlain).message.body, 'Prices of 2 products have changed. Open the app to see the latest prices.');
    assert.strictEqual(pushTo(wholesalerHidesB).message.body, 'The price of Alpha Pump has changed. Open the app to see it.');
    assert.strictEqual(pushTo(wholesalerPlain).message.body, 'Prices of 2 products have changed. Open the app to see the latest prices.');
  } finally {
    server.close();
    await mongoose.connection.db.dropDatabase();
    await mongoose.disconnect();
  }
}

async function main() {
  const uri = testDatabaseUri('CUSTOMER_BRANDS_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Customer hidden brands tests skipped: set CUSTOMER_BRANDS_TEST_MONGODB_URI to a local test database');
    return;
  }
  await run(uri);
  console.log('Customer hidden brands tests passed');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
