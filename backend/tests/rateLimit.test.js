const assert = require('assert');
const jwt = require('jsonwebtoken');

// Rate limiting. The key checks need no database; the sign-in checks start the
// real API and write test users, so they only run against a database on this
// machine (never the live database in .env):
//
//   RATE_LIMIT_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/rl_test node tests/rateLimit.test.js

const TEST_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.JWT_SECRET = TEST_SECRET;
// The general limit is high here so the sign-in limits are what's tested.
process.env.RATE_LIMIT_MAX_REQUESTS = '1000';

const { clientIp, userOrIpKey } = require('../src/middlewares/rateLimits');
const { signAccessToken, signRefreshToken } = require('../src/utils/jwtTokens');

const request = (headers = {}, ip = '203.0.113.7') => ({ headers, ip, socket: {} });

function testKeys() {
  // A made-up token (anyone can write a payload) is counted by IP.
  const fakePayload = Buffer.from(JSON.stringify({ userId: 'attacker-chosen' })).toString('base64url');
  const fake = `x.${fakePayload}.y`;
  assert.strictEqual(userOrIpKey(request({ authorization: `Bearer ${fake}` })), 'ip:203.0.113.7');

  // A token signed with another secret is counted by IP too.
  const forged = jwt.sign({ userId: 'u-forged' }, 'some-other-secret-that-is-long-enough');
  assert.strictEqual(userOrIpKey(request({ authorization: `Bearer ${forged}` })), 'ip:203.0.113.7');

  // A refresh token is not an access token.
  const refresh = signRefreshToken({ userId: 'u1' }, '5m');
  assert.strictEqual(userOrIpKey(request({ authorization: `Bearer ${refresh}` })), 'ip:203.0.113.7');

  // A genuine access token gets the user's own allowance.
  const access = signAccessToken({ userId: 'u1' }, '5m');
  assert.strictEqual(userOrIpKey(request({ authorization: `Bearer ${access}` })), 'user:u1');

  // No token: by IP.
  assert.strictEqual(userOrIpKey(request()), 'ip:203.0.113.7');

  // On Vercel the edge's x-real-ip is the client; elsewhere req.ip.
  process.env.VERCEL = '1';
  assert.strictEqual(clientIp(request({ 'x-real-ip': '198.51.100.4' }, '10.0.0.1')), '198.51.100.4');
  assert.strictEqual(
    clientIp(request({ 'x-vercel-forwarded-for': '198.51.100.9, 10.0.0.2' }, '10.0.0.1')),
    '198.51.100.9',
  );
  delete process.env.VERCEL;
  assert.strictEqual(clientIp(request({ 'x-real-ip': '198.51.100.4' }, '10.0.0.1')), '10.0.0.1');
}

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

async function runSignInChecks(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const { User } = require('../src/models');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const password = 'Correct-Horse-9';
  const buyer = await User.create({
    name: 'Limit Buyer',
    email: `limit-buyer-${suffix}@example.com`,
    passwordHash: password,
    authProvider: 'email',
    role: 'buyer',
    isActive: true,
  });

  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const login = async (email, pass) => {
    const res = await fetch(`${base}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pass }),
    });
    return { status: res.status, body: await res.json().catch(() => ({})) };
  };

  try {
    // A correct sign-in doesn't count as a failure.
    assert.strictEqual((await login(buyer.email, password)).status, 200);

    // 10 wrong passwords for one account, then it pauses, even with the
    // right password.
    for (let i = 0; i < 10; i += 1) {
      assert.strictEqual((await login(buyer.email, 'wrong-password')).status, 401, `attempt ${i + 1}`);
    }
    let res = await login(buyer.email, password);
    assert.strictEqual(res.status, 429, 'account pauses after 10 failures');
    assert.strictEqual(res.body.error.code, 'TOO_MANY_LOGIN_ATTEMPTS');

    // The same IP is limited to 20 sign-in attempts in total (12 used so far),
    // whatever accounts it tries.
    for (let i = 0; i < 8; i += 1) {
      res = await login(`nobody-${i}-${suffix}@example.com`, 'wrong-password');
      assert.strictEqual(res.status, 401, `other account attempt ${i + 1}`);
    }
    res = await login(`nobody-x-${suffix}@example.com`, 'wrong-password');
    assert.strictEqual(res.status, 429, 'IP pauses after 20 attempts');

    // DEMO ONLY: demo mode switches the sign-in limits off.
    process.env.DEMO_MODE = 'true';
    res = await login(buyer.email, password);
    assert.strictEqual(res.status, 200, 'no sign-in lockout in demo mode');
    delete process.env.DEMO_MODE;
  } finally {
    server.close();
    const { RefreshToken } = require('../src/models');
    await RefreshToken.deleteMany({ userId: buyer._id });
    await User.deleteOne({ _id: buyer._id });
    await mongoose.disconnect();
  }
}

async function run() {
  testKeys();
  const uri = testDatabaseUri('RATE_LIMIT_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Rate limit key tests passed (sign-in checks skipped: set RATE_LIMIT_TEST_MONGODB_URI to a local test database)');
    return;
  }
  await runSignInChecks(uri);
  console.log('Rate limit tests passed (keys + sign-in limits)');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
