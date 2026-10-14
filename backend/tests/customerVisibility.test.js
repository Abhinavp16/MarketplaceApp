const assert = require('assert');

// Brands and top-level categories marked "hide from customers": retail
// customers and guests (app and website) never see them, their subcategories
// or their products; wholesalers and the team see everything. Starts the real
// API against a database on this machine only (never the live database in .env):
//
//   VISIBILITY_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/visibility_test node tests/customerVisibility.test.js

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

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const sfx = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const made = { companies: [], categories: [], products: [], users: [] };

  const brandHidden = await M.Company.create({ name: `Vis Hidden Brand ${sfx}`, slug: `vis-hidden-brand-${sfx}`, hideFromCustomers: true });
  const brandShown = await M.Company.create({ name: `Vis Shown Brand ${sfx}`, slug: `vis-shown-brand-${sfx}` });
  made.companies.push(brandHidden._id, brandShown._id);
  const cat = (name, company, extra = {}) => M.Category.create({ name: `${name} ${sfx}`, slug: `${name.toLowerCase().replace(/\s+/g, '-')}-${sfx}`, company: company._id, ...extra });
  const catOfHiddenBrand = await cat('Vis A Pumps', brandHidden);
  const catHidden = await cat('Vis Secret Pipes', brandShown, { hideFromCustomers: true });
  const subOfHidden = await cat('Vis Secret Pipes Sub', brandShown, { parent: catHidden._id });
  const catShown = await cat('Vis Open Wires', brandShown);
  const subOfShown = await cat('Vis Open Wires Sub', brandShown, { parent: catShown._id });
  made.categories.push(catOfHiddenBrand._id, catHidden._id, subOfHidden._id, catShown._id, subOfShown._id);

  const product = (name, company, category) => M.Product.create({
    name: `${name} ${sfx}`, slug: `${name.toLowerCase().replace(/\s+/g, '-')}-${sfx}`, sku: `VIS-${name.replace(/\W/g, '')}-${sfx}`,
    category: category.name, categoryRef: category._id, company: company._id,
    mrp: 100, retailPrice: 90, wholesalePrice: 80, stock: 500, isFeatured: true, status: 'active',
  });
  const pHiddenBrand = await product('Visprod Brand A', brandHidden, catOfHiddenBrand);
  const pHiddenCat = await product('Visprod Secret Top', brandShown, catHidden);
  const pHiddenSub = await product('Visprod Secret Sub', brandShown, subOfHidden);
  const pShown = await product('Visprod Open Sub', brandShown, subOfShown);
  made.products.push(pHiddenBrand._id, pHiddenCat._id, pHiddenSub._id, pShown._id);
  const hiddenProducts = [pHiddenBrand, pHiddenCat, pHiddenSub];

  const user = async (role) => {
    const u = await M.User.create({ name: `Vis ${role}`, email: `vis-${role}-${sfx}@example.com`, authProvider: 'email', role, isActive: true });
    made.users.push(u._id);
    return u;
  };
  const buyer = await user('buyer');
  const wholesaler = await user('wholesaler');
  const admin = await user('admin');
  const staff = await user('staff');
  const token = (u) => signAccessToken({ userId: String(u._id) }, '10m');
  const tokens = { guest: null, buyer: token(buyer), wholesaler: token(wholesaler), admin: token(admin), staff: token(staff) };

  const settings = await M.Settings.getSettings();
  const savedBanners = { hero: settings.heroBanners, promo: settings.promoBanners };
  settings.heroBanners = [
    { title: `vis-brand-${sfx}`, linkUrl: `/brand/${brandHidden._id}` },
    { title: `vis-cat-${sfx}`, linkUrl: `/category/${catHidden._id}` },
    { title: `vis-hidden-product-${sfx}`, linkUrl: `/product/${pHiddenSub._id}` },
    { title: `vis-open-product-${sfx}`, linkUrl: `/product/${pShown._id}` },
    { title: `vis-plain-${sfx}`, linkUrl: 'https://example.com' },
  ];
  settings.promoBanners = [{ title: `vis-promo-subcat-${sfx}`, linkUrl: `/category/${subOfHidden._id}` }];
  await settings.save();
  clearHiddenCatalogCache();

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (method, path, { as = 'guest', body } = {}) => {
    const res = await fetch(base + path, {
      method,
      headers: { 'Content-Type': 'application/json', ...(tokens[as] ? { Authorization: `Bearer ${tokens[as]}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = {};
    try { json = JSON.parse(text); } catch { /* not JSON */ }
    return { status: res.status, text, body: json };
  };
  const mentionsHidden = (text) => hiddenProducts.some((p) => text.includes(String(p._id)) || text.includes(p.slug))
    || text.includes(String(brandHidden._id)) || text.includes(String(catHidden._id)) || text.includes(String(subOfHidden._id));

  try {
    for (const as of ['guest', 'buyer']) {
      // Brands
      let res = await call('GET', '/companies?limit=500', { as });
      assert.ok(!res.body.data.some((b) => String(b._id) === String(brandHidden._id)), `${as}: hidden brand not listed`);
      assert.ok(res.body.data.some((b) => String(b._id) === String(brandShown._id)));
      assert.strictEqual((await call('GET', `/companies/${brandHidden._id}`, { as })).status, 404);
      assert.strictEqual((await call('GET', `/companies/${brandHidden._id}/products`, { as })).status, 404);
      res = await call('GET', `/companies/${brandShown._id}/products`, { as });
      assert.deepStrictEqual(res.body.data.products.map((p) => String(p._id)), [String(pShown._id)], `${as}: brand page lists only visible products`);

      // Categories
      res = await call('GET', `/categories?company=${brandShown._id}`, { as });
      const names = res.body.data.map((c) => c.name);
      assert.ok(!names.includes(catHidden.name) && !names.includes(subOfHidden.name), `${as}: hidden category and its subcategory not listed`);
      assert.ok(names.includes(catShown.name) && names.includes(subOfShown.name));
      res = await call('GET', `/categories/with-subcategories?company=${brandShown._id}`, { as });
      assert.deepStrictEqual(res.body.data.map((c) => c.name), [catShown.name]);
      assert.deepStrictEqual(res.body.data[0].subcategories.map((c) => c.name), [subOfShown.name]);
      for (const hiddenCat of [catHidden, subOfHidden, catOfHiddenBrand]) {
        assert.strictEqual((await call('GET', `/categories/${hiddenCat._id}`, { as })).status, 404, `${as}: ${hiddenCat.name} 404`);
      }
      assert.strictEqual((await call('GET', `/categories/${catHidden._id}/subcategories`, { as })).status, 404);

      // Products
      for (const path of ['/products?limit=50', '/products/featured', `/products/search?q=${encodeURIComponent('Visprod ' + sfx)}`, `/products/${pShown._id}/related`, '/products/categories']) {
        res = await call('GET', path, { as });
        assert.strictEqual(res.status, 200, `${as} ${path}`);
        assert.ok(!mentionsHidden(res.text), `${as} ${path} must not include hidden items`);
      }
      res = await call('GET', `/products/search?q=${encodeURIComponent('Visprod ' + sfx)}`, { as });
      assert.deepStrictEqual(res.body.data.map((p) => String(p.id)), [String(pShown._id)], `${as}: search finds only the visible product`);
      for (const p of hiddenProducts) {
        assert.strictEqual((await call('GET', `/products/${p.slug}`, { as })).status, 404, `${as}: ${p.name} page by slug`);
        assert.strictEqual((await call('GET', `/products/${p._id}`, { as })).status, 404, `${as}: ${p.name} page by id`);
      }
      assert.strictEqual((await call('GET', `/products/${pShown.slug}`, { as })).status, 200);

      // App banners
      res = await call('GET', '/settings/banners', { as });
      const heroTitles = res.body.data.heroBanners.map((b) => b.title);
      assert.deepStrictEqual(heroTitles.filter((t) => t.endsWith(sfx)), [`vis-open-product-${sfx}`, `vis-plain-${sfx}`], `${as}: banners to hidden things dropped`);
      assert.ok(!res.body.data.promoBanners.some((b) => b.title === `vis-promo-subcat-${sfx}`));
    }

    // The website (never signed in)
    let res = await call('GET', '/website/catalog/brands');
    assert.ok(!res.text.includes(String(brandHidden._id)) && res.text.includes(String(brandShown._id)));
    res = await call('GET', `/website/catalog/brands/${brandShown.slug}/categories`);
    assert.ok(!res.text.includes(catHidden.name) && res.text.includes(catShown.name), 'website: hidden category not listed');
    assert.strictEqual((await call('GET', `/website/catalog/brands/${brandHidden.slug}/categories`)).status, 404);
    assert.strictEqual((await call('GET', `/website/catalog/brands/${brandShown.slug}/categories/${catHidden.slug}/products`)).status, 404);
    res = await call('GET', '/website/catalog/products');
    assert.ok(!mentionsHidden(res.text) && res.text.includes(String(pShown._id)), 'website: only visible products');
    for (const p of hiddenProducts) {
      assert.strictEqual((await call('GET', `/website/catalog/products/${p.slug}`)).status, 404, `website: ${p.name}`);
    }

    // Retail customers can't buy hidden products, even with an old link.
    res = await call('POST', '/cart/items', { as: 'buyer', body: { productId: String(pHiddenSub._id), quantity: 1 } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'PRODUCT_UNAVAILABLE');
    res = await call('POST', '/cart/items', { as: 'buyer', body: { productId: String(pShown._id), quantity: 1 } });
    assert.strictEqual(res.status, 200, res.text);
    // A hidden product already in the cart leaves it.
    await M.Cart.updateOne({ userId: buyer._id }, { $push: { items: { productId: pHiddenBrand._id, quantity: 1, priceAtAdd: 90 } } });
    res = await call('GET', '/cart', { as: 'buyer' });
    assert.deepStrictEqual(res.body.data.items.map((i) => String(i.productId)), [String(pShown._id)]);
    assert.strictEqual((await M.Cart.findOne({ userId: buyer._id }).lean()).items.length, 1, 'removed from the saved cart too');

    // Wholesalers and the team see everything.
    for (const as of ['wholesaler', 'admin', 'staff']) {
      res = await call('GET', '/companies?limit=500', { as });
      assert.ok(res.body.data.some((b) => String(b._id) === String(brandHidden._id)), `${as} sees the hidden brand`);
      res = await call('GET', `/categories/with-subcategories?company=${brandShown._id}`, { as });
      assert.ok(res.body.data.some((c) => c.name === catHidden.name), `${as} sees the hidden category`);
      for (const p of hiddenProducts) {
        assert.strictEqual((await call('GET', `/products/${p.slug}`, { as })).status, 200, `${as}: ${p.name}`);
      }
    }
    res = await call('GET', `/products/search?q=${encodeURIComponent('Visprod ' + sfx)}`, { as: 'wholesaler' });
    assert.strictEqual(res.body.data.length, 4, 'wholesaler search finds all four');
    res = await call('GET', '/settings/banners', { as: 'wholesaler' });
    assert.strictEqual(res.body.data.heroBanners.filter((b) => b.title.endsWith(sfx)).length, 5, 'wholesaler gets every banner');
    res = await call('POST', '/cart/items', { as: 'wholesaler', body: { productId: String(pHiddenSub._id), quantity: 10 } });
    assert.strictEqual(res.status, 200, `wholesaler can buy: ${res.text}`);

    // Admin switches: take effect at once; subcategories can't carry the switch.
    res = await call('PUT', `/companies/${brandShown._id}`, { as: 'admin', body: { hideFromCustomers: true } });
    assert.strictEqual(res.status, 200, res.text);
    res = await call('GET', '/companies?limit=500');
    assert.ok(!res.body.data.some((b) => String(b._id) === String(brandShown._id)), 'newly hidden brand disappears at once');
    assert.strictEqual((await call('GET', `/products/${pShown.slug}`)).status, 404, 'and its products');
    assert.ok(await M.AuditLog.exists({ action: 'brand.customer_visibility_updated', entityId: brandShown._id }), 'change is audited');
    await call('PUT', `/companies/${brandShown._id}`, { as: 'admin', body: { hideFromCustomers: false } });
    assert.strictEqual((await call('GET', `/products/${pShown.slug}`)).status, 200, 'shown again');

    res = await call('PUT', `/categories/${subOfShown._id}`, { as: 'admin', body: { hideFromCustomers: true } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'SUBCATEGORY_CANNOT_BE_HIDDEN');
    res = await call('POST', '/categories', { as: 'admin', body: { name: `Vis Bad Sub ${sfx}`, company: String(brandShown._id), parent: String(catShown._id), hideFromCustomers: true } });
    assert.strictEqual(res.status, 400);
    res = await call('PUT', `/categories/${catShown._id}`, { as: 'admin', body: { hideFromCustomers: true } });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual((await call('GET', `/products/${pShown.slug}`)).status, 404, 'hiding a category hides its subcategory products at once');
    res = await call('PUT', `/categories/${catShown._id}`, { as: 'admin', body: { hideFromCustomers: false } });
    assert.strictEqual((await call('GET', `/products/${pShown.slug}`)).status, 200);
    res = await call('PUT', `/companies/${brandShown._id}`, { as: 'admin', body: { hideFromCustomers: 'yes' } });
    assert.strictEqual(res.status, 400, 'only true/false accepted');
    res = await call('PUT', `/companies/${brandShown._id}`, { as: 'buyer', body: { hideFromCustomers: true } });
    assert.strictEqual(res.status, 403, 'customers cannot change it');
  } finally {
    server.close();
    const fresh = await M.Settings.getSettings();
    fresh.heroBanners = savedBanners.hero;
    fresh.promoBanners = savedBanners.promo;
    await fresh.save();
    await M.Cart.deleteMany({ userId: { $in: made.users } });
    await M.AuditLog.deleteMany({ entityId: { $in: [...made.companies, ...made.categories] } });
    await M.User.deleteMany({ _id: { $in: made.users } });
    await M.Product.deleteMany({ _id: { $in: made.products } });
    await M.Category.deleteMany({ $or: [{ _id: { $in: made.categories } }, { company: { $in: made.companies } }] });
    await M.Company.deleteMany({ _id: { $in: made.companies } });
    await mongoose.disconnect();
  }
}

async function main() {
  const uri = testDatabaseUri('VISIBILITY_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Customer visibility tests skipped: set VISIBILITY_TEST_MONGODB_URI to a local test database');
    return;
  }
  await run(uri);
  console.log('Customer visibility tests passed');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
