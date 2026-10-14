const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Account deletion, end to end: app and website requests, admin review,
// completion, reminders. Starts the real API and writes test data, so it only
// runs against a database on this machine (never the live database in .env):
//
//   ACCOUNT_DELETION_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/deletion_test node tests/accountDeletion.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.RATE_LIMIT_MAX_REQUESTS = '1000';

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

const randomPhone = () => `9${String(Math.floor(Math.random() * 1e9)).padStart(9, '7')}`;

async function run(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  process.env.FILE_STORAGE_DRIVER = 'local';
  const uploads = fs.mkdtempSync(path.join(os.tmpdir(), 'deletion-uploads-'));
  process.env.LOCAL_UPLOADS_DIR = uploads;
  // Private media (payment / business proofs) lives outside the public uploads folder.
  const privateMedia = fs.mkdtempSync(path.join(os.tmpdir(), 'deletion-private-'));
  process.env.LOCAL_PRIVATE_DIR = privateMedia;

  const mongoose = require('mongoose');
  const app = require('../src/app');
  const M = require('../src/models');
  const { signAccessToken } = require('../src/utils/jwtTokens');
  const { sendDeletionReminders } = require('../src/services/accountDeletionReminderService');
  const { TERMS_VERSION, PRIVACY_POLICY_VERSION } = require('../src/config/legalAcceptance');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const password = 'Correct-Horse-9';
  const created = { users: [], requests: [] };
  const makeUser = async (fields) => {
    const user = await M.User.create({ authProvider: 'email', isActive: true, ...fields });
    created.users.push(user._id);
    return user;
  };

  const admin = await makeUser({ name: 'Del Admin', email: `del-admin-${suffix}@example.com`, role: 'admin', phone: randomPhone() });
  const member = await makeUser({ name: 'Del Member', username: `delmember${suffix}`, role: 'staff', passwordHash: password });
  const buyerPhone = randomPhone();
  const buyer = await makeUser({ name: 'Asha Buyer', email: `asha-${suffix}@example.com`, phone: buyerPhone, role: 'buyer', passwordHash: password, address: '1 Test Rd, Sample City' });
  const wsPhone = randomPhone();
  const wholesaler = await makeUser({
    name: `Sunrise Test Traders ${suffix}`, email: `rohan-${suffix}@example.com`, phone: wsPhone, role: 'wholesaler', passwordHash: password,
    businessInfo: { businessName: 'Sunrise Test Traders', gstNumber: '22AAAAA0000A1Z5', status: 'accepted', verified: true },
  });
  const product = await M.Product.create({ name: `Del Pump ${suffix}`, sku: `DEL-${suffix}`, category: 'Pumps', mrp: 100, retailPrice: 90, wholesalePrice: 80, stock: 50 });

  for (const user of [buyer, wholesaler]) {
    await M.Cart.create({ userId: user._id, items: [{ productId: product._id, quantity: 1, priceAtAdd: 90 }] });
    await M.DeviceToken.create({ userId: user._id, fcmToken: `tok-${user._id}`, platform: 'android' });
    fs.mkdirSync(path.join(uploads, 'avatars', String(user._id)), { recursive: true });
    fs.writeFileSync(path.join(uploads, 'avatars', String(user._id), 'a.webp'), 'x');
  }
  fs.mkdirSync(path.join(privateMedia, 'private', 'proofs', String(wholesaler._id)), { recursive: true });
  fs.writeFileSync(path.join(privateMedia, 'private', 'proofs', String(wholesaler._id), 'gst.webp'), 'x');
  await M.Negotiation.create({
    wholesalerId: wholesaler._id, productId: product._id, productSnapshot: { name: product.name, price: 80 },
    requestedQuantity: 10, requestedPricePerUnit: 75, requestedTotalPrice: 750, expiresAt: new Date(Date.now() + 864e5),
  });
  // An unrelated admin alert about this wholesaler (e.g. a deal message).
  await M.AdminNotification.create({ title: 'New message', body: `Sunrise Test Traders ${suffix}: hello`, type: 'negotiation_message', actor: { id: wholesaler._id, name: wholesaler.name, role: 'wholesaler' } });

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (method, p, { token, body } = {}) => {
    const res = await fetch(base + p, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: res.status, body: await res.json().catch(() => ({})) };
  };
  const adminToken = signAccessToken({ userId: String(admin._id) }, '10m');
  const memberToken = signAccessToken({ userId: String(member._id) }, '10m');

  try {
    let res = await call('POST', '/auth/login', { body: { email: buyer.email, password } });
    assert.strictEqual(res.status, 200);
    const buyerSession = res.body.data;
    res = await call('POST', '/auth/login-phone', { body: { phone: wsPhone, password } });
    const wsSession = res.body.data;

    // --- In-app request ---
    res = await call('GET', '/auth/account-deletion-request', { token: buyerSession.accessToken });
    assert.strictEqual(res.body.data, null);
    res = await call('POST', '/auth/account-deletion-request', { token: buyerSession.accessToken, body: {} });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.data.status, 'pending');
    const days = (new Date(res.body.data.dueAt) - Date.now()) / 864e5;
    assert.ok(days > 29.9 && days <= 30, 'due in 30 days');
    const firstId = res.body.data.id;
    res = await call('POST', '/auth/account-deletion-request', { token: buyerSession.accessToken, body: {} });
    assert.strictEqual(res.status, 200, 'asking again returns the same request');
    assert.strictEqual(String(res.body.data.id), String(firstId));
    res = await call('POST', '/auth/account-deletion-request/cancel', { token: buyerSession.accessToken });
    assert.strictEqual(res.body.data.status, 'cancelled');
    res = await call('POST', '/auth/account-deletion-request', { token: buyerSession.accessToken, body: {} });
    assert.strictEqual(res.status, 201, 'can ask again after cancelling');
    const buyerRequestId = res.body.data.id;
    created.requests.push(firstId, buyerRequestId);

    // Only admins process requests.
    assert.strictEqual((await call('GET', '/admin/account-deletion-requests', { token: memberToken })).status, 403);
    assert.strictEqual((await call('GET', '/admin/account-deletion-requests', { token: buyerSession.accessToken })).status, 403);

    res = await call('PUT', `/admin/account-deletion-requests/${buyerRequestId}`, { token: adminToken, body: { status: 'in_review' } });
    assert.strictEqual(res.status, 200);
    res = await call('POST', '/auth/account-deletion-request/cancel', { token: buyerSession.accessToken });
    assert.strictEqual(res.status, 404, 'no cancelling once in review');
    res = await call('POST', `/admin/account-deletion-requests/${buyerRequestId}/complete`, { token: adminToken, body: { staffNote: 'Done' } });
    assert.strictEqual(res.status, 200);
    res = await call('POST', `/admin/account-deletion-requests/${buyerRequestId}/complete`, { token: adminToken, body: {} });
    assert.strictEqual(res.status, 409, 'completing twice is refused');

    // The customer is gone.
    res = await call('GET', '/auth/me', { token: buyerSession.accessToken });
    assert.strictEqual(res.body.error.code, 'ACCOUNT_DEACTIVATED');
    assert.strictEqual((await call('POST', '/auth/refresh-token', { body: { refreshToken: buyerSession.refreshToken } })).status, 401);
    assert.strictEqual((await call('POST', '/auth/login', { body: { email: buyer.email, password } })).status, 401);
    assert.strictEqual((await call('POST', '/auth/login-phone', { body: { phone: buyerPhone, password } })).status, 401);
    const goneBuyer = await M.User.findById(buyer._id).select('+passwordHash').lean();
    assert.strictEqual(goneBuyer.name, 'Deleted account');
    assert.ok(goneBuyer.email.endsWith('@deleted.invalid') && goneBuyer.phone.startsWith('deleted-'));
    assert.ok(!goneBuyer.passwordHash && !goneBuyer.address && goneBuyer.isActive === false);
    assert.deepStrictEqual(
      [await M.Cart.countDocuments({ userId: buyer._id }), await M.DeviceToken.countDocuments({ userId: buyer._id })],
      [0, 0],
    );
    assert.ok(!fs.existsSync(path.join(uploads, 'avatars', String(buyer._id))));
    assert.strictEqual(
      await M.AdminNotification.countDocuments({ 'metadata.userId': String(buyer._id) }),
      0,
      "the 'deletion requested' alert with their name and phone is removed",
    );
    res = await call('POST', '/auth/register-phone', {
      body: { name: 'Asha New', phone: buyerPhone, password, termsAccepted: true, privacyPolicyAccepted: true, termsVersion: TERMS_VERSION, privacyPolicyVersion: PRIVACY_POLICY_VERSION },
    });
    assert.strictEqual(res.status, 201, 'the phone number can sign up again');
    created.users.push(res.body.data.user._id || res.body.data.user.id);

    // --- Website request ---
    const before = await M.AccountDeletionRequest.countDocuments({ userId: wholesaler._id });
    res = await call('POST', '/account-deletion-request', { body: { name: 'Wrong Name', phone: wsPhone } });
    assert.strictEqual(res.status, 202);
    const wrongReply = res.body.message;
    assert.strictEqual(await M.AccountDeletionRequest.countDocuments({ userId: wholesaler._id }), before);
    res = await call('POST', '/account-deletion-request', { body: { name: wholesaler.name.toUpperCase(), phone: wsPhone } });
    assert.strictEqual(res.body.message, wrongReply, 'same reply whether or not an account matches');
    const wsRequest = await M.AccountDeletionRequest.findOne({ userId: wholesaler._id, status: 'pending' });
    assert.ok(wsRequest && wsRequest.source === 'website');
    created.requests.push(wsRequest._id);
    await call('POST', '/account-deletion-request', { body: { name: 'Del Admin', phone: admin.phone } });
    assert.strictEqual(await M.AccountDeletionRequest.countDocuments({ userId: admin._id }), 0, 'admins cannot be targeted');

    // Not verified: refused. Verified with the tick: completes in one step.
    res = await call('POST', `/admin/account-deletion-requests/${wsRequest._id}/complete`, { token: adminToken, body: {} });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'DELETION_REQUEST_VERIFICATION_REQUIRED');
    res = await call('PUT', `/admin/account-deletion-requests/${wsRequest._id}`, { token: adminToken, body: { status: 'in_review' } });
    assert.strictEqual(res.status, 400, 'review without the tick is refused');
    res = await call('POST', `/admin/account-deletion-requests/${wsRequest._id}/complete`, { token: adminToken, body: { identityVerified: true } });
    assert.strictEqual(res.status, 200, 'verified website request completes in one step');
    const doneWs = await M.AccountDeletionRequest.findById(wsRequest._id).lean();
    assert.ok(doneWs.identityVerification.verifiedAt, 'verification recorded');
    assert.strictEqual(String(doneWs.identityVerification.verifiedBy), String(admin._id));

    const goneWs = await M.User.findById(wholesaler._id).lean();
    assert.strictEqual(goneWs.businessInfo.gstNumber, null);
    assert.strictEqual(goneWs.isActive, false);
    assert.strictEqual(await M.Negotiation.countDocuments({ wholesalerId: wholesaler._id }), 0);
    assert.ok(!fs.existsSync(path.join(privateMedia, 'private', 'proofs', String(wholesaler._id))));
    assert.strictEqual(await M.AdminNotification.countDocuments({ 'actor.id': wholesaler._id }), 0, 'alerts naming them are removed');
    assert.strictEqual((await call('GET', '/auth/me', { token: wsSession.accessToken })).status, 401);

    // --- Rejection: the customer sees the note ---
    const other = await makeUser({ name: 'Keep Me', email: `keep-${suffix}@example.com`, phone: randomPhone(), role: 'buyer', passwordHash: password });
    res = await call('POST', '/auth/login', { body: { email: other.email, password } });
    const otherToken = res.body.data.accessToken;
    res = await call('POST', '/auth/account-deletion-request', { token: otherToken, body: {} });
    const otherRequest = res.body.data.id;
    created.requests.push(otherRequest);
    await call('PUT', `/admin/account-deletion-requests/${otherRequest}`, { token: adminToken, body: { status: 'rejected', staffNote: 'Open order must be delivered first' } });
    res = await call('GET', '/auth/account-deletion-request', { token: otherToken });
    assert.strictEqual(res.body.data.status, 'rejected');
    assert.strictEqual(res.body.data.staffNote, 'Open order must be delivered first');
    assert.strictEqual((await call('POST', `/admin/account-deletion-requests/${otherRequest}/complete`, { token: adminToken, body: {} })).status, 409);

    // --- Reminders: once when due within 7 days, once when overdue ---
    const remindUser = await makeUser({ name: 'Remind Me', email: `remind-${suffix}@example.com`, phone: randomPhone(), role: 'buyer' });
    const dueSoon = await M.AccountDeletionRequest.create({ userId: remindUser._id, source: 'app', dueAt: new Date(Date.now() + 3 * 864e5), requestedAt: new Date(Date.now() - 27 * 864e5) });
    const overdue = await M.AccountDeletionRequest.create({ userId: remindUser._id, source: 'website', status: 'in_review', dueAt: new Date(Date.now() - 864e5), requestedAt: new Date(Date.now() - 31 * 864e5) });
    const later = await M.AccountDeletionRequest.create({ userId: remindUser._id, source: 'app', dueAt: new Date(Date.now() + 20 * 864e5) });
    created.requests.push(dueSoon._id, overdue._id, later._id);
    const ours = (type) => M.AdminNotification.find({ type, 'metadata.requestId': { $in: [dueSoon, overdue, later].map((r) => String(r._id)) } }).lean();

    let sent = await sendDeletionReminders();
    assert.ok(sent.dueSoon >= 1 && sent.overdue >= 1);
    const soonAlerts = await ours('account_deletion_due_soon');
    const overdueAlerts = await ours('account_deletion_overdue');
    assert.deepStrictEqual(soonAlerts.map((a) => a.metadata.requestId), [String(dueSoon._id)], 'one due-soon alert, for the right request');
    assert.deepStrictEqual(overdueAlerts.map((a) => a.metadata.requestId), [String(overdue._id)], 'one overdue alert');
    assert.match(soonAlerts[0].title, /due in 3 days/);
    assert.strictEqual(overdueAlerts[0].severity, 'urgent');
    for (const alert of [...soonAlerts, ...overdueAlerts]) {
      assert.ok(!alert.body.includes('Remind Me') && !alert.body.includes(remindUser.phone), 'alerts name no one');
    }
    await sendDeletionReminders();
    assert.strictEqual((await ours('account_deletion_due_soon')).length, 1, 'not repeated');
    assert.strictEqual((await ours('account_deletion_overdue')).length, 1, 'not repeated');
    // Completed or rejected requests get no reminders.
    sent = await sendDeletionReminders({ now: new Date(Date.now() + 40 * 864e5) });
    // 40 days on, the due-soon and later requests are overdue too: one alert each.
    assert.strictEqual((await ours('account_deletion_overdue')).length, 3, 'each request gets its own overdue alert');
    assert.strictEqual(await M.AdminNotification.countDocuments({ 'metadata.requestId': String(otherRequest), type: /account_deletion_(due_soon|overdue)/ }), 0);
  } finally {
    server.close();
    await M.AdminNotification.deleteMany({ $or: [{ 'actor.id': { $in: created.users } }, { 'metadata.requestId': { $in: created.requests.map(String) } }, { 'metadata.userId': { $in: created.users.map(String) } }] });
    await M.AccountDeletionRequest.deleteMany({ userId: { $in: created.users } });
    await M.Cart.deleteMany({ userId: { $in: created.users } });
    await M.DeviceToken.deleteMany({ userId: { $in: created.users } });
    await M.Negotiation.deleteMany({ wholesalerId: { $in: created.users } });
    await M.RefreshToken.deleteMany({ userId: { $in: created.users } });
    await M.User.deleteMany({ _id: { $in: created.users } });
    await M.Product.deleteOne({ _id: product._id });
    await mongoose.disconnect();
    fs.rmSync(uploads, { recursive: true, force: true });
    fs.rmSync(privateMedia, { recursive: true, force: true });
  }
}

async function main() {
  const uri = testDatabaseUri('ACCOUNT_DELETION_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Account deletion tests skipped: set ACCOUNT_DELETION_TEST_MONGODB_URI to a local test database');
    return;
  }
  await run(uri);
  console.log('Account deletion tests passed');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
