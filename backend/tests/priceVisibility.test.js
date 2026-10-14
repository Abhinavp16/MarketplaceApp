const assert = require('assert');

// Wholesale prices reach only wholesalers and admins. The first part needs no
// database. The second part starts the real API and writes test products and
// users, so it only runs against a database on this machine (never the live
// database in .env):
//
//   PRICE_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/price_test node tests/priceVisibility.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.RATE_LIMIT_MAX_REQUESTS = '1000';

const { pricesForRole, canSeeWholesalePrices } = require('../src/utils/priceVisibility');

const WHOLESALE_KEY = /"(wholesalePrice|pendingWholesalePrice)"/;

function testRoleFilter() {
  const product = {
    price: 100,
    retailPrice: 100,
    wholesalePrice: 80,
    pendingWholesalePrice: 75,
    variants: [{ retailPrice: 100, wholesalePrice: 80 }],
  };

  for (const role of ['guest', 'buyer', 'staff', undefined]) {
    const shown = pricesForRole(product, role);
    assert.ok(!WHOLESALE_KEY.test(JSON.stringify(shown)), `${role} must not get wholesale prices`);
    assert.strictEqual(shown.retailPrice, 100);
    assert.strictEqual(shown.price, 100);
  }
  for (const role of ['wholesaler', 'admin']) {
    assert.ok(canSeeWholesalePrices(role));
    assert.strictEqual(pricesForRole(product, role).wholesalePrice, 80);
  }
  // The original object is left alone.
  assert.strictEqual(product.wholesalePrice, 80);
  assert.strictEqual(product.variants[0].wholesalePrice, 80);
}

// --- API checks against a local test database --------------------------------

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

async function runApiChecks(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const { User, Product, Company, Category, Cart, WebsiteSettings } = require('../src/models');
  const { signAccessToken } = require('../src/utils/jwtTokens');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const settingsExisted = Boolean(await WebsiteSettings.exists({ _id: 'website_settings' }));

  const company = await Company.create({ name: `Price Brand ${suffix}`, slug: `price-brand-${suffix}` });
  const category = await Category.create({ name: `Price Cat ${suffix}`, slug: `price-cat-${suffix}`, company: company._id });
  const productFields = (name, extra = {}) => ({
    name,
    slug: `${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${suffix}`,
    sku: `SKU-${name.replace(/\W/g, '')}-${suffix}`,
    category: category.name,
    categoryRef: category._id,
    company: company._id,
    mrp: 150,
    retailPrice: 120,
    wholesalePrice: 90,
    stock: 100,
    status: 'active',
    isFeatured: true,
    ...extra,
  });
  const active = await Product.create(productFields(`Pricecheck Pump ${suffix}`, {
    pendingRetailPrice: 125,
    pendingWholesalePrice: 95,
    priceChangeScheduledAt: new Date(),
    priceChangeEffectiveAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  }));
  const related = await Product.create(productFields(`Pricecheck Pipe ${suffix}`));
  const draft = await Product.create(productFields(`Pricecheck Draft ${suffix}`, { status: 'draft' }));
  const productIds = [active._id, related._id, draft._id];

  const makeUser = (role) => User.create({
    name: `Price ${role}`,
    email: `price-${role}-${suffix}@example.com`,
    authProvider: 'email',
    role,
    isActive: true,
  });
  const buyer = await makeUser('buyer');
  const wholesaler = await makeUser('wholesaler');
  const admin = await makeUser('admin');
  const userIds = [buyer._id, wholesaler._id, admin._id];
  const tokenFor = (user) => signAccessToken({ userId: String(user._id) }, '10m');
  const tokens = { guest: null, buyer: tokenFor(buyer), wholesaler: tokenFor(wholesaler), admin: tokenFor(admin) };

  const settings = await WebsiteSettings.getSettings();
  const previousProductCategories = settings.productCategories;
  settings.productCategories = [{
    name: `Price Website Cat ${suffix}`,
    productDetails: [{ productId: String(active._id), order: 0 }],
    isActive: true,
  }];
  await settings.save();

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (method, path, { token, body } = {}) => {
    const res = await fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = {};
    try { json = JSON.parse(text); } catch { /* not JSON */ }
    return { status: res.status, text, body: json };
  };

  const productEndpoints = [
    `/products?categoryId=${category._id}`,
    '/products/featured',
    `/products/search?q=${encodeURIComponent(`Pricecheck Pump ${suffix}`)}`,
    `/products/${active.slug}`,
    `/products/${active._id}`,
    `/products/${related._id}/related`,
  ];

  try {
    // Guests and customers never see wholesale prices on any product endpoint.
    for (const role of ['guest', 'buyer']) {
      for (const path of productEndpoints) {
        const res = await call('GET', path, { token: tokens[role] });
        assert.strictEqual(res.status, 200, `${role} ${path}`);
        assert.ok(!WHOLESALE_KEY.test(res.text), `${role} ${path} must not include wholesale prices`);
      }
    }

    // The customer price is still there.
    let res = await call('GET', `/products/${active.slug}`);
    assert.strictEqual(res.body.data.price, 120);
    assert.strictEqual(res.body.data.mrp, 150);
    assert.strictEqual(res.body.data.pendingPriceChange.newPrice, 125, 'customers see their own scheduled price');

    // The detail page only sends public fields.
    for (const internal of ['pendingPriceChangeAudit', 'viewCount', 'orderCount', 'negotiationCount', 'searchTextHindi', 'lowStockThreshold', 'pendingRetailPrice', '__v']) {
      assert.ok(!(internal in res.body.data), `detail must not include ${internal}`);
    }
    for (const field of ['id', '_id', 'name', 'slug', 'sku', 'images', 'stock', 'category', 'company', 'labels', 'minCustomerQuantity', 'notifyMe']) {
      assert.ok(field in res.body.data, `detail keeps ${field}`);
    }

    // Wholesalers and admins still get dealer prices.
    for (const role of ['wholesaler', 'admin']) {
      res = await call('GET', `/products/${active.slug}`, { token: tokens[role] });
      assert.strictEqual(res.body.data.wholesalePrice, 90, `${role} sees the wholesale price`);
      assert.strictEqual(res.body.data.retailPrice, 120, `${role} sees the customer price`);
    }
    res = await call('GET', `/products?categoryId=${category._id}`, { token: tokens.wholesaler });
    const card = res.body.data.find((item) => String(item.id) === String(active._id));
    assert.strictEqual(card.price, 90, 'wholesaler card price is the wholesale price');
    assert.strictEqual(card.wholesalePrice, 90);
    assert.strictEqual(card.pendingPriceChange.newPrice, 95);

    // Draft products: hidden from guests, even by ID; not in a brand's public list.
    res = await call('GET', `/products/${draft.slug}`);
    assert.strictEqual(res.status, 404, 'draft by slug is hidden');
    res = await call('GET', `/products/${draft._id}`);
    assert.strictEqual(res.status, 404, 'draft by ID is hidden from guests');
    res = await call('GET', `/products/${draft._id}`, { token: tokens.buyer });
    assert.strictEqual(res.status, 200, 'a signed-in customer can still open an item from their history');
    assert.ok(!WHOLESALE_KEY.test(res.text));
    res = await call('GET', `/companies/${company._id}/products`);
    assert.strictEqual(res.status, 200);
    assert.ok(!res.body.data.products.some((p) => String(p._id) === String(draft._id)), 'draft not listed publicly');
    res = await call('GET', `/companies/${company._id}/products`, { token: tokens.admin });
    assert.ok(res.body.data.products.some((p) => String(p._id) === String(draft._id)), 'admin still sees drafts');

    // Upcoming dealer price changes are for wholesalers only.
    res = await call('GET', '/products/scheduled-changes', { token: tokens.buyer });
    assert.strictEqual(res.status, 403, 'customers cannot list wholesale price changes');
    res = await call('GET', '/products/scheduled-changes', { token: tokens.wholesaler });
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.data.some((item) => item.newPrice === 95));

    // Related products: the limit is capped.
    res = await call('GET', `/products/${active._id}/related?limit=100000`);
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.data.length <= 20);

    // Public website endpoints.
    for (const path of ['/website/catalog/products', `/website/catalog/products/${active.slug}`, '/website/catalog/home', '/settings/website-content']) {
      res = await call('GET', path);
      assert.strictEqual(res.status, 200, path);
      assert.ok(!WHOLESALE_KEY.test(res.text), `${path} must not include wholesale prices`);
    }
    res = await call('GET', `/website/catalog/products/${active.slug}`);
    assert.strictEqual(res.body.data.retailPrice, 120, 'website still shows the customer price');
    res = await call('GET', '/settings/website-content');
    const linked = res.body.data.productCategories
      .flatMap((cat) => cat.productDetails)
      .find((item) => item.productId === String(active._id));
    assert.strictEqual(linked.retailPrice, 120);

    // Cart: a customer's cart has no wholesale price; a wholesaler's does.
    res = await call('POST', '/cart/items', { token: tokens.buyer, body: { productId: String(related._id), quantity: 1 } });
    assert.strictEqual(res.status, 200, res.text);
    assert.ok(!WHOLESALE_KEY.test(res.text), 'buyer cart must not include wholesale prices');
    res = await call('GET', '/cart', { token: tokens.buyer });
    assert.ok(!WHOLESALE_KEY.test(res.text));
    res = await call('POST', '/cart/items', { token: tokens.wholesaler, body: { productId: String(related._id), quantity: 10 } });
    assert.strictEqual(res.status, 200, res.text);
    assert.ok(res.body.data.items.some((item) => item.product.wholesalePrice === 90));
  } finally {
    server.close();
    await Cart.deleteMany({ userId: { $in: userIds } });
    await User.deleteMany({ _id: { $in: userIds } });
    await Product.deleteMany({ _id: { $in: productIds } });
    await Category.deleteOne({ _id: category._id });
    await Company.deleteOne({ _id: company._id });
    if (settingsExisted) {
      await WebsiteSettings.updateOne({ _id: 'website_settings' }, { $set: { productCategories: previousProductCategories } });
    } else {
      await WebsiteSettings.deleteOne({ _id: 'website_settings' });
    }
    await mongoose.disconnect();
  }
}

async function run() {
  testRoleFilter();
  const uri = testDatabaseUri('PRICE_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Price visibility unit tests passed (API checks skipped: set PRICE_TEST_MONGODB_URI to a local test database)');
    return;
  }
  await runApiChecks(uri);
  console.log('Price visibility tests passed (unit + API)');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
