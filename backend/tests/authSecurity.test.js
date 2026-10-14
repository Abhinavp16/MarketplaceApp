const assert = require('assert');
const jwt = require('jsonwebtoken');

// Login and token safety. The first part needs no database. The second part
// starts the real API and writes test users, so it only runs against a
// database on this machine (never the live database in .env):
//
//   AUTH_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/auth_test node tests/authSecurity.test.js

const TEST_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.JWT_SECRET = TEST_SECRET;
delete process.env.JWT_REFRESH_SECRET;

const {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  jwtConfigProblems,
  assertJwtConfig,
} = require('../src/utils/jwtTokens');

function testTokenTypes() {
  const access = signAccessToken({ userId: 'u1' }, '5m');
  const refresh = signRefreshToken({ userId: 'u1' }, '5m');
  const legacyAccess = jwt.sign({ userId: 'u1' }, TEST_SECRET, { expiresIn: '5m' });

  assert.strictEqual(verifyAccessToken(access).userId, 'u1');
  assert.strictEqual(verifyAccessToken(legacyAccess).userId, 'u1', 'access tokens from before token types still work');
  assert.throws(() => verifyAccessToken(refresh), /not an access token/, 'a refresh token must not open the API');

  assert.strictEqual(verifyRefreshToken(refresh).userId, 'u1');
  assert.throws(() => verifyRefreshToken(access), /not a refresh token/, 'an access token must not refresh');
  assert.throws(() => verifyRefreshToken(legacyAccess), /not a refresh token/);

  const otherAlgorithm = jwt.sign({ userId: 'u1' }, TEST_SECRET, { algorithm: 'HS512' });
  assert.throws(() => verifyAccessToken(otherAlgorithm), /invalid algorithm/, 'only HS256 is accepted');

  // A separate refresh secret: refresh tokens no longer verify as access tokens
  // and vice versa.
  process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-0123456789-abcdefghij';
  const separateRefresh = signRefreshToken({ userId: 'u1' }, '5m');
  assert.throws(() => verifyAccessToken(separateRefresh));
  assert.strictEqual(verifyRefreshToken(separateRefresh).userId, 'u1');
  delete process.env.JWT_REFRESH_SECRET;
}

function testSecretGuard() {
  assert.deepStrictEqual(jwtConfigProblems({ JWT_SECRET: TEST_SECRET }), []);
  assert.match(jwtConfigProblems({}).join(), /JWT_SECRET is not set/);
  assert.match(jwtConfigProblems({ JWT_SECRET: 'short' }).join(), /at least 32/);
  assert.match(
    jwtConfigProblems({ JWT_SECRET: TEST_SECRET, JWT_REFRESH_SECRET: 'short' }).join(),
    /JWT_REFRESH_SECRET must be at least 32/,
  );

  // Production refuses an unsafe secret; development only reports it.
  assert.throws(() => assertJwtConfig({ NODE_ENV: 'production', JWT_SECRET: 'short' }), /Unsafe JWT configuration/);
  assert.doesNotThrow(() => assertJwtConfig({ NODE_ENV: 'development', JWT_SECRET: 'short' }));
  assert.doesNotThrow(() => assertJwtConfig({ NODE_ENV: 'production', JWT_SECRET: TEST_SECRET }));

  // The known leaked value is recognised by its hash (the value itself is not
  // in this repository any more).
  const source = require('fs').readFileSync(require.resolve('../src/utils/jwtTokens'), 'utf8');
  assert.ok(/LEAKED_SECRET_HASHES[\s\S]*'[0-9a-f]{64}'/.test(source), 'leaked secret hash must be listed');
}

function testNoHardcodedAdminPasswords() {
  const fs = require('fs');
  const path = require('path');
  // The demo has no admin-seeding script at all (accounts come from scripts/demo/seed.js).
  assert.ok(!fs.existsSync(path.join(__dirname, '..', 'src/scripts/seedAdmin.js')), 'no admin seed script ships with the demo');
  for (const removed of ['seedAdmin', 'resetAdmin', 'testLogin', 'testPaymentVerify', 'seedTestUser']) {
    assert.ok(!fs.existsSync(path.join(__dirname, '..', 'scripts', `${removed}.js`)), `scripts/${removed}.js must be gone`);
  }
}

// --- API checks against a local test database --------------------------------

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

async function runApiChecks(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const { User } = require('../src/models');
  const { issueMagicLink } = require('../src/services/magicLinkService');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const phone = (lead) => `${lead}${suffix.slice(-9).padStart(9, '1')}`;
  const password = 'Correct-Horse-9';
  const make = (role, extra = {}) => User.create({
    name: `Auth ${role}`,
    email: `auth-${role}-${suffix}@example.com`,
    passwordHash: password,
    authProvider: 'email',
    role,
    isActive: true,
    ...extra,
  });
  const admin = await make('admin', { phone: phone(9) });
  const buyer = await make('buyer', { phone: phone(8) });
  const wholesaler = await make('wholesaler', { phone: phone(7) });
  const staff = await make('staff', { phone: phone(6), username: `member${suffix}` });
  const createdIds = [admin._id, buyer._id, wholesaler._id, staff._id];

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const call = async (method, path, { body, token } = {}) => {
    const res = await fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: res.status, body: await res.json().catch(() => ({})) };
  };

  try {
    // Outside demo mode admins never get in with a password, by email or by phone.
    delete process.env.DEMO_MODE;
    let res = await call('POST', '/auth/login', { body: { email: admin.email, password } });
    assert.strictEqual(res.status, 401, 'admin password login must be refused');
    assert.strictEqual(res.body.error.code, 'AUTH_INVALID_CREDENTIALS');
    res = await call('POST', '/auth/login-phone', { body: { phone: admin.phone, password } });
    assert.strictEqual(res.status, 401, 'admin phone login must be refused');

    // DEMO ONLY: with DEMO_MODE the demo admin can use the email + password
    // (the demo has no SMTP for magic links). Phone login stays closed to admins.
    process.env.DEMO_MODE = 'true';
    res = await call('POST', '/auth/login', { body: { email: admin.email, password } });
    assert.strictEqual(res.status, 200, 'demo admin password login works in demo mode');
    assert.strictEqual(res.body.data.user.role, 'admin');
    res = await call('POST', '/auth/login-phone', { body: { phone: admin.phone, password } });
    assert.strictEqual(res.status, 401, 'admin phone login stays refused in demo mode');
    delete process.env.DEMO_MODE;

    // Members can't use phone login (it would skip their 6-hour limit).
    res = await call('POST', '/auth/login-phone', { body: { phone: staff.phone, password } });
    assert.strictEqual(res.status, 401, 'member phone login must be refused');

    // Customers and wholesalers still log in.
    res = await call('POST', '/auth/login', { body: { email: buyer.email, password } });
    assert.strictEqual(res.status, 200, 'buyer email login works');
    res = await call('POST', '/auth/login-phone', { body: { phone: wholesaler.phone, password } });
    assert.strictEqual(res.status, 200, 'wholesaler phone login works');
    const { accessToken, refreshToken } = res.body.data;

    // The access token works; the refresh token does not open the API.
    res = await call('GET', '/auth/me', { token: accessToken });
    assert.strictEqual(res.status, 200);
    res = await call('GET', '/auth/me', { token: refreshToken });
    assert.strictEqual(res.status, 401, 'refresh token must not work as an access token');
    assert.strictEqual(res.body.error.code, 'INVALID_TOKEN');

    // Only a refresh token refreshes.
    res = await call('POST', '/auth/refresh-token', { body: { refreshToken: accessToken } });
    assert.strictEqual(res.status, 401, 'access token must not refresh');
    res = await call('POST', '/auth/refresh-token', { body: { refreshToken } });
    assert.strictEqual(res.status, 200, 'refresh token refreshes');

    const wholesalerSession = res.body.data;

    // Signing out with only the refresh token (the access token may have
    // expired) ends the session: that refresh token stops working.
    res = await call('POST', '/auth/login', { body: { email: buyer.email, password } });
    const session = res.body.data;
    res = await call('POST', '/auth/logout', { body: { refreshToken: session.refreshToken } });
    assert.strictEqual(res.status, 200, 'logout without an access token');
    res = await call('POST', '/auth/refresh-token', { body: { refreshToken: session.refreshToken } });
    assert.strictEqual(res.status, 401, 'a signed-out session cannot refresh');
    // A made-up token is ignored; a signed-in user can't end someone else's session.
    res = await call('POST', '/auth/logout', { body: { refreshToken: 'not-a-token' } });
    assert.strictEqual(res.status, 200);
    res = await call('POST', '/auth/logout', { token: session.accessToken, body: { refreshToken: wholesalerSession.refreshToken } });
    assert.strictEqual(res.status, 200);
    res = await call('POST', '/auth/refresh-token', { body: { refreshToken: wholesalerSession.refreshToken } });
    assert.strictEqual(res.status, 200, "another user's session keeps working");

    // Profile: saving the number on file works; a new number must be valid.
    res = await call('PUT', '/auth/profile', { token: accessToken, body: { name: 'Renamed', phone: wholesaler.phone } });
    assert.strictEqual(res.status, 200);
    res = await call('PUT', '/auth/profile', { token: accessToken, body: { phone: '12345' } });
    assert.strictEqual(res.status, 400, 'invalid new phone is refused');
    assert.strictEqual(res.body.error.code, 'INVALID_PHONE');

    // Magic-link admin sessions end after 12 hours, also across refreshes.
    let rawToken;
    await issueMagicLink({
      email: admin.email,
      panelUrl: 'http://admin.test',
      expiryMinutes: 5,
      sendEmail: async (_to, link) => { rawToken = new URL(link).searchParams.get('token'); },
    });
    res = await call('POST', '/auth/magic-link/verify', { body: { token: rawToken } });
    assert.strictEqual(res.status, 200, 'magic link signs the admin in');
    const sessionEnds = new Date(res.body.data.sessionExpiresAt).getTime();
    const twelveHours = 12 * 60 * 60 * 1000;
    assert.ok(Math.abs(sessionEnds - (Date.now() + twelveHours)) < 60 * 1000, 'admin session capped at 12 hours');
    res = await call('POST', '/auth/refresh-token', { body: { refreshToken: res.body.data.refreshToken } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(new Date(res.body.data.sessionExpiresAt).getTime(), sessionEnds, 'refresh keeps the same session end');

    // A token whose session has ended is refused.
    const ended = signAccessToken({ userId: String(admin._id), sessionExpiresAt: new Date(Date.now() - 1000).toISOString() }, '5m');
    res = await call('GET', '/auth/me', { token: ended });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.error.code, 'SESSION_EXPIRED');
  } finally {
    server.close();
    const { RefreshToken, MagicLinkToken } = require('../src/models');
    await RefreshToken.deleteMany({ userId: { $in: createdIds } });
    await MagicLinkToken.deleteMany({ email: admin.email });
    await User.deleteMany({ _id: { $in: createdIds } });
    await mongoose.disconnect();
  }
}

async function run() {
  testTokenTypes();
  testSecretGuard();
  testNoHardcodedAdminPasswords();
  const uri = testDatabaseUri('AUTH_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Auth security unit tests passed (API checks skipped: set AUTH_TEST_MONGODB_URI to a local test database)');
    return;
  }
  await runApiChecks(uri);
  console.log('Auth security tests passed (unit + API)');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
