const assert = require('assert');

// Immediate price changes are announced once, after the admin stops saving
// for 100 seconds (or 10 minutes after the first save at the latest), to the
// customers / wholesalers whose price changed. Push sends are captured, not
// sent. Runs against a database on this machine only (never the live database):
//
//   PRICE_NOTIFY_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/price_notify_test node tests/priceUpdateNotifications.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.RATE_LIMIT_MAX_REQUESTS = '5000';

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

const SECOND = 1000;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const M = require('../src/models');
  const { signAccessToken } = require('../src/utils/jwtTokens');
  const { clearHiddenCatalogCache } = require('../src/utils/customerVisibility');
  const notificationService = require('../src/services/notificationService');
  const { flushDuePriceChangeNotification, QUIET_MS, MAX_WAIT_MS } = require('../src/services/priceChangeNotificationService');

  // Capture pushes instead of sending them.
  const pushes = [];
  notificationService.sendToMultipleDevices = async (tokens, message, data) => {
    pushes.push({ tokens: [...tokens].sort(), message, data });
    return { successCount: tokens.length, failureCount: 0 };
  };

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  await mongoose.connection.db.dropDatabase();
  await M.PriceChangeNotificationBatch.syncIndexes();

  const brand = await M.Company.create({ name: 'Notify Brand', slug: 'notify-brand' });
  const hiddenBrand = await M.Company.create({ name: 'Dealer Only Brand', slug: 'dealer-only-brand', hideFromCustomers: true });
  const category = await M.Category.create({ name: 'Notify Pumps', slug: 'notify-pumps', company: brand._id });
  const hiddenCategory = await M.Category.create({ name: 'Dealer Pumps', slug: 'dealer-pumps', company: hiddenBrand._id });
  clearHiddenCatalogCache();
  const product = (name, extra = {}) => M.Product.create({
    name, nameHindi: `${name} (हिंदी)`, slug: name.toLowerCase().replace(/\s+/g, '-'), sku: `N-${name.replace(/\W/g, '')}`,
    category: category.name, categoryRef: category._id, company: brand._id,
    mrp: 1000, retailPrice: 900, wholesalePrice: 800, stock: 10, status: 'active', ...extra,
  });
  const p1 = await product('Pump One');
  const p2 = await product('Pump Two');
  const p3 = await product('Pump Three');
  const pDealer = await product('Dealer Pump', { company: hiddenBrand._id, categoryRef: hiddenCategory._id, category: hiddenCategory.name });
  const pLater = await product('Pump Later');

  const user = (role, extra = {}) => M.User.create({ name: `${role} ${extra.preferredLanguage || 'en'}`, email: `${role}-${Math.random().toString(36).slice(2)}@example.com`, authProvider: 'email', role, isActive: true, ...extra });
  const buyerEn = await user('buyer');
  const buyerHi = await user('buyer', { preferredLanguage: 'hi' });
  const buyerOff = await user('buyer', { isActive: false });
  const wholesaler = await user('wholesaler');
  const admin = await user('admin');
  for (const u of [buyerEn, buyerHi, buyerOff, wholesaler]) {
    await M.DeviceToken.create({ userId: u._id, fcmToken: `token-${u._id}`, platform: 'android', isActive: true });
  }

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (method, path, { token = signAccessToken({ userId: String(admin._id) }, '10m'), body } = {}) => {
    const res = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: body ? JSON.stringify(body) : undefined });
    return { status: res.status, body: await res.json().catch(() => ({})) };
  };
  const changePrice = (p, body) => call('PUT', `/admin/products/${p._id}/price-change`, { body: { priceChangeMode: 'immediate', ...body } });
  const notifications = (u) => M.Notification.find({ userId: u._id, type: 'price_change_campaign_applied' }).sort({ createdAt: 1 }).lean();
  const pending = () => M.PriceChangeNotificationBatch.findOne({ status: 'pending' }).lean();

  try {
    // A scheduled change keeps its own "Price update scheduled" message and
    // isn't part of the batch.
    assert.strictEqual((await call('PUT', `/admin/products/${pLater._id}/price-change`, { body: { priceChangeMode: 'schedule_24h', retailPrice: 990 } })).status, 200);
    assert.ok(pushes.every((p) => p.data.type === 'price_change_campaign_started'));
    pushes.length = 0;

    // Several saves in a row: nothing is sent yet, everything joins one batch.
    assert.strictEqual((await changePrice(p1, { retailPrice: 950 })).status, 200);
    assert.strictEqual((await changePrice(p2, { wholesalePrice: 820 })).status, 200);
    assert.strictEqual((await changePrice(p3, { retailPrice: 950, wholesalePrice: 850 })).status, 200);
    assert.strictEqual((await changePrice(pDealer, { retailPrice: 960 })).status, 200);
    assert.strictEqual((await changePrice(p1, { retailPrice: 970 })).status, 200, 'same product again');

    let batch = await pending();
    assert.deepStrictEqual(batch.retailProductIds.map(String).sort(), [p1, p3, pDealer].map((p) => String(p._id)).sort());
    assert.deepStrictEqual(batch.wholesaleProductIds.map(String).sort(), [p2, p3].map((p) => String(p._id)).sort());
    assert.strictEqual(await M.PriceChangeNotificationBatch.countDocuments(), 1, 'one batch');
    assert.strictEqual(pushes.length, 0, 'nothing sent while the admin is saving');

    // Still within 100 seconds of the last save: not sent.
    assert.strictEqual(await flushDuePriceChangeNotification({ now: new Date(batch.lastChangeAt.getTime() + 60 * SECOND) }), null);
    assert.strictEqual(pushes.length, 0);

    // 100 seconds after the last save: one message per group and language.
    const summary = await flushDuePriceChangeNotification({ now: new Date(batch.lastChangeAt.getTime() + QUIET_MS + SECOND) });
    assert.deepStrictEqual(summary, { customers: { products: 2, users: 2 }, wholesalers: { products: 2, users: 1 } },
      'customers: 2 products (dealer-only one left out), 2 active buyers; wholesalers: 2 products');
    assert.strictEqual(pushes.length, 3, 'buyers (en), buyers (hi), wholesalers');
    const pushTo = (u) => pushes.find((p) => p.tokens.includes(`token-${u._id}`));
    assert.strictEqual(pushTo(buyerEn).message.title, 'Prices updated');
    assert.strictEqual(pushTo(buyerEn).message.body, 'Prices of 2 products have changed. Open the app to see the latest prices.');
    assert.strictEqual(pushTo(buyerHi).message.title, 'कीमतें बदलीं');
    assert.strictEqual(pushTo(wholesaler).message.body, 'Prices of 2 products have changed. Open the app to see the latest prices.');
    assert.strictEqual(pushTo(buyerEn).data.type, 'price_change_campaign_applied', 'same type the app already shows');
    assert.strictEqual(pushTo(buyerEn).data.productCount, '2');
    assert.ok(!pushes.some((p) => p.tokens.includes(`token-${buyerOff._id}`)), 'switched-off accounts get nothing');
    assert.strictEqual((await notifications(buyerEn)).length, 1, 'also in the notification list');
    assert.strictEqual((await notifications(wholesaler))[0].type, 'price_change_campaign_applied');

    // Never twice.
    assert.strictEqual(await flushDuePriceChangeNotification({ now: new Date(Date.now() + 3600 * SECOND) }), null);
    assert.strictEqual(pushes.length, 3);
    assert.strictEqual((await M.PriceChangeNotificationBatch.findById(batch._id).lean()).status, 'sent');

    // One product: the message names it (Hindi name for Hindi users).
    pushes.length = 0;
    await changePrice(p2, { retailPrice: 930 });
    batch = await pending();
    await flushDuePriceChangeNotification({ now: new Date(batch.lastChangeAt.getTime() + QUIET_MS + SECOND) });
    assert.strictEqual(pushes.length, 2, 'only customers (only the customer price changed)');
    assert.strictEqual(pushTo(buyerEn).message.title, 'Price updated');
    assert.strictEqual(pushTo(buyerEn).message.body, 'The price of Pump Two has changed. Open the app to see it.');
    assert.strictEqual(pushTo(buyerHi).message.body, 'Pump Two (हिंदी) की कीमत बदल गई है। देखने के लिए ऐप खोलें।');

    // Only a dealer-only product changed for customers: customers get nothing.
    pushes.length = 0;
    await changePrice(pDealer, { retailPrice: 965 });
    batch = await pending();
    const quiet = await flushDuePriceChangeNotification({ now: new Date(batch.lastChangeAt.getTime() + QUIET_MS + SECOND) });
    assert.deepStrictEqual(quiet.customers, { products: 0, users: 0 });
    assert.strictEqual(pushes.length, 0);

    // 10-minute cap: an admin still saving 11 minutes on gets the message out anyway.
    pushes.length = 0;
    await changePrice(p1, { retailPrice: 975 });
    const now = new Date();
    await M.PriceChangeNotificationBatch.updateOne({ status: 'pending' }, { $set: { firstChangeAt: new Date(now.getTime() - MAX_WAIT_MS - SECOND), lastChangeAt: new Date(now.getTime() - 10 * SECOND) } });
    assert.ok(await flushDuePriceChangeNotification({ now }), 'sent at the cap even though saves continue');
    assert.strictEqual(pushes.length, 2);

    // Two servers checking at the same moment: sent once.
    pushes.length = 0;
    await changePrice(p3, { retailPrice: 955 });
    batch = await pending();
    const due = new Date(batch.lastChangeAt.getTime() + QUIET_MS + SECOND);
    const results = await Promise.all([flushDuePriceChangeNotification({ now: due }), flushDuePriceChangeNotification({ now: due }), flushDuePriceChangeNotification({ now: due })]);
    assert.strictEqual(results.filter(Boolean).length, 1, 'only one claims the batch');
    assert.strictEqual(pushes.length, 2);

    // On Vercel: the next request after the wait sends it (checked at most every 15 s).
    pushes.length = 0;
    await changePrice(p2, { retailPrice: 940 });
    await M.PriceChangeNotificationBatch.updateOne({ status: 'pending' }, { $set: { lastChangeAt: new Date(Date.now() - QUIET_MS - SECOND) } });
    await sleep(16 * SECOND);
    const guest = await fetch(`${base}/products?limit=1`);
    assert.strictEqual(guest.status, 200);
    assert.strictEqual(pushes.length, 2, 'sent by an ordinary request');
    assert.strictEqual(await pending(), null);

    // The admin panel's nudge: admins only, and only sends when due.
    const buyerToken = signAccessToken({ userId: String(buyerEn._id) }, '10m');
    assert.strictEqual((await call('POST', '/admin/price-updates/flush', { token: buyerToken })).status, 403);
    const nudge = await call('POST', '/admin/price-updates/flush');
    assert.strictEqual(nudge.status, 200);
    assert.strictEqual(nudge.body.data.sent, false);
  } finally {
    server.close();
    await mongoose.connection.db.dropDatabase();
    await mongoose.disconnect();
  }
}

async function main() {
  const uri = testDatabaseUri('PRICE_NOTIFY_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Price update notification tests skipped: set PRICE_NOTIFY_TEST_MONGODB_URI to a local test database');
    return;
  }
  await run(uri);
  console.log('Price update notification tests passed');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
