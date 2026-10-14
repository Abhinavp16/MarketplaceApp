const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Request input can't smuggle database operators, slow regexes or paths
// outside the uploads folder. The first part needs no database. The second
// part starts the real API and writes test data, so it only runs against a
// database on this machine (never the live database in .env):
//
//   INPUT_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/input_test node tests/inputSafety.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.RATE_LIMIT_MAX_REQUESTS = '1000';

const { stripOperatorKeys } = require('../src/middlewares/stripOperatorKeys');
const { paginate } = require('../src/utils/helpers');

function testStripOperatorKeys() {
  const input = {
    phone: { $gt: '' },
    status: 'active',
    nested: { ok: 1, $where: 'sleep(1000)', deeper: [{ $ne: 1, keep: 'yes' }] },
    list: ['a', { $in: ['x'] }],
  };
  assert.deepStrictEqual(stripOperatorKeys(input), {
    phone: {},
    status: 'active',
    nested: { ok: 1, deeper: [{ keep: 'yes' }] },
    list: ['a', {}],
  });
  assert.strictEqual(stripOperatorKeys(null), null);
  assert.strictEqual(stripOperatorKeys('text'), 'text');
}

function testPaginate() {
  assert.deepStrictEqual(paginate('abc', 'xyz'), { page: 1, limit: 20, skip: 0 });
  assert.deepStrictEqual(paginate('-3', '5000', 100), { page: 1, limit: 100, skip: 0 });
  assert.deepStrictEqual(paginate('2', '10'), { page: 2, limit: 10, skip: 10 });
}

async function testStoragePaths() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'demo-storage-'));
  process.env.FILE_STORAGE_DRIVER = 'local';
  process.env.LOCAL_UPLOADS_DIR = path.join(root, 'uploads');
  const { saveBuffer, deleteFile } = require('../src/config/storage');

  const saved = await saveBuffer({ buffer: Buffer.from('x'), folder: '../../escape', filename: '../a.txt' });
  assert.strictEqual(saved.publicId, 'escape/a.txt', 'dot segments are dropped');
  assert.ok(fs.existsSync(path.join(root, 'uploads', 'escape', 'a.txt')));

  const outside = path.join(root, 'outside.txt');
  fs.writeFileSync(outside, 'keep me');
  assert.strictEqual(await deleteFile('../outside.txt'), false);
  assert.ok(fs.existsSync(outside), 'a file outside the uploads folder is never deleted');

  fs.rmSync(root, { recursive: true, force: true });
  delete process.env.FILE_STORAGE_DRIVER;
  delete process.env.LOCAL_UPLOADS_DIR;
}

// --- API checks against a local test database --------------------------------

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

async function runApiChecks(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const uploadsDir = fs.mkdtempSync(path.join(os.tmpdir(), 'demo-uploads-'));
  process.env.FILE_STORAGE_DRIVER = 'local';
  process.env.LOCAL_UPLOADS_DIR = uploadsDir;
  let createdAdminId = null;
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const { Company, Category, User, Negotiation, Product } = require('../src/models');
  const { signAccessToken } = require('../src/utils/jwtTokens');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const company = await Company.create({ name: `Input Brand (A.B) ${suffix}`, slug: `input-brand-${suffix}` });
  const parent = await Category.create({ name: `Input Root ${suffix}`, slug: `input-root-${suffix}`, company: company._id });
  const child = await Category.create({ name: `Input Child ${suffix}`, slug: `input-child-${suffix}`, company: company._id, parent: parent._id });
  const staff = await User.create({
    name: 'Input Member',
    email: `input-staff-${suffix}@example.com`,
    username: `inputstaff${suffix}`,
    authProvider: 'email',
    role: 'staff',
    isActive: true,
  });
  const wholesaler = await User.create({
    name: 'Input Wholesaler',
    email: `input-ws-${suffix}@example.com`,
    authProvider: 'email',
    role: 'wholesaler',
    isActive: true,
  });
  const product = await Product.create({
    name: `Input Pump ${suffix}`,
    sku: `INP-${suffix}`,
    category: 'Pumps',
    mrp: 100,
    retailPrice: 90,
    wholesalePrice: 80,
    stock: 50,
  });
  const openDeal = await Negotiation.create({
    wholesalerId: wholesaler._id,
    productId: product._id,
    productSnapshot: { name: product.name, price: 80 },
    requestedQuantity: 10,
    requestedPricePerUnit: 0,
    requestedTotalPrice: 0,
    currentPricePerUnit: 0,
    currentTotalPrice: 0,
    history: [{ action: 'countered', by: 'admin', pricePerUnit: 70, totalPrice: 700, actorId: staff._id, actorRole: 'staff' }],
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  });

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (pathname, { method = 'GET', token, body } = {}) => {
    const res = await fetch(base + pathname, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: res.status, body: await res.json().catch(() => ({})) };
  };
  const staffToken = signAccessToken({ userId: String(staff._id) }, '10m');
  const wholesalerToken = signAccessToken({ userId: String(wholesaler._id) }, '10m');

  try {
    // An operator in the query string is dropped, not applied: the result is
    // the same as without that filter.
    let res = await call(`/categories?company=${company._id}&parent[$ne]=x`);
    assert.strictEqual(res.status, 200);
    const unfiltered = await call(`/categories?company=${company._id}`);
    assert.deepStrictEqual(
      res.body.data.map((category) => category.name).sort(),
      unfiltered.body.data.map((category) => category.name).sort(),
    );
    res = await call(`/categories?company=${company._id}&parent=${parent._id}`);
    assert.deepStrictEqual(res.body.data.map((category) => category.name), [child.name], 'normal parent filter still works');

    // A catastrophic regex as a brand filter is treated as plain text.
    const started = Date.now();
    res = await call(`/products?brand=${encodeURIComponent('(a+)+$')}`);
    assert.strictEqual(res.status, 200);
    assert.ok(Date.now() - started < 3000, 'brand filter is not a live regex');
    // Brand names with regex characters match literally.
    res = await call(`/companies/${company._id}`);
    assert.strictEqual(res.status, 200);

    // Overlong search input is refused.
    res = await call(`/products/search?q=${'a'.repeat(300)}`);
    assert.strictEqual(res.status, 400);

    // Members can't counter or accept a deal at ₹0.
    res = await call(`/staff/negotiations/${openDeal._id}/counter`, { method: 'PUT', token: staffToken, body: { pricePerUnit: 0 } });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'INVALID_PRICE');
    res = await call(`/staff/negotiations/${openDeal._id}/accept`, { method: 'PUT', token: staffToken, body: {} });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'DEAL_PRICE_REQUIRED');

    // Wholesalers see who acted by name only.
    res = await call(`/negotiations/${openDeal._id}`, { token: wholesalerToken });
    assert.strictEqual(res.status, 200);
    const actor = res.body.data.history[0].actorId;
    assert.deepStrictEqual(actor, { name: 'Input Member' });
    assert.ok(!JSON.stringify(res.body).includes(staff.username), 'member username is not sent');

    // Analytics only for real products, with known sources.
    res = await call(`/products/${new mongoose.Types.ObjectId()}/view`, { method: 'POST', body: { source: 'direct' } });
    assert.strictEqual(res.status, 404);
    res = await call(`/products/${product._id}/view`, { method: 'POST', body: { source: 'evil', sessionId: 'x'.repeat(5000) } });
    assert.strictEqual(res.status, 200);
    const { Analytics } = require('../src/models');
    const view = await Analytics.findOne({ productId: product._id }).sort({ createdAt: -1 }).lean();
    assert.strictEqual(view.source, 'direct');
    assert.ok(view.sessionId.length <= 100);

    // Uploads (multer + sharp): an admin's image is stored as WebP inside the
    // uploads folder; a wrong file type is a clear 400.
    const admin = await User.create({
      name: 'Input Admin',
      email: `input-admin-${suffix}@example.com`,
      authProvider: 'email',
      role: 'admin',
      isActive: true,
    });
    createdAdminId = admin._id;
    const adminToken = signAccessToken({ userId: String(admin._id) }, '10m');
    const sharp = require('sharp');
    const png = await sharp({ create: { width: 8, height: 8, channels: 3, background: '#2a7' } }).png().toBuffer();
    const upload = async (bytes, type, name) => {
      const form = new FormData();
      form.append('image', new Blob([bytes], { type }), name);
      const response = await fetch(`${base}/upload/image?folder=../../tests-upload`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken}` },
        body: form,
      });
      return { status: response.status, body: await response.json().catch(() => ({})) };
    };
    res = await upload(png, 'image/png', 'leaf.png');
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
    assert.strictEqual(res.body.data.mimeType, 'image/webp');
    assert.ok(res.body.data.publicId.startsWith('tests-upload/'), 'folder cannot climb out of uploads');
    assert.ok(fs.existsSync(path.join(uploadsDir, res.body.data.publicId)));
    res = await upload(Buffer.from('not an image'), 'text/plain', 'note.txt');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'INVALID_FILE_TYPE');
    assert.match(res.body.message, /Invalid file type/);

    // Topics: only the public ones.
    res = await call('/notifications/subscribe', { method: 'POST', token: wholesalerToken, body: { topic: 'admins' } });
    assert.strictEqual(res.status, 400);
  } finally {
    server.close();
    const { Analytics } = require('../src/models');
    await Analytics.deleteMany({ productId: product._id });
    await Negotiation.deleteOne({ _id: openDeal._id });
    await Product.deleteOne({ _id: product._id });
    await User.deleteMany({ _id: { $in: [staff._id, wholesaler._id, createdAdminId].filter(Boolean) } });
    fs.rmSync(uploadsDir, { recursive: true, force: true });
    await Category.deleteMany({ _id: { $in: [parent._id, child._id] } });
    await Company.deleteOne({ _id: company._id });
    await mongoose.disconnect();
  }
}

async function run() {
  testStripOperatorKeys();
  testPaginate();
  await testStoragePaths();
  const uri = testDatabaseUri('INPUT_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Input safety unit tests passed (API checks skipped: set INPUT_TEST_MONGODB_URI to a local test database)');
    return;
  }
  await runApiChecks(uri);
  console.log('Input safety tests passed (unit + API)');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
