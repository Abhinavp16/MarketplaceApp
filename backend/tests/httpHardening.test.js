const assert = require('assert');

// CORS, error responses, health checks and body size. The first part needs no
// database. The second part starts the real API and writes test users, so it
// only runs against a database on this machine (never the live database in
// .env):
//
//   HTTP_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/http_test node tests/httpHardening.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
process.env.RATE_LIMIT_MAX_REQUESTS = '1000';
delete process.env.EXPOSE_ERROR_STACK;
delete process.env.CORS_ORIGIN;
delete process.env.ADMIN_PANEL_URL;
delete process.env.FRONTEND_URL;

const { isAllowedOrigin, allowedOrigins } = require('../src/config/corsOrigins');
const errorHandler = require('../src/middlewares/errorHandler');
const { BadRequestError } = require('../src/utils/errors');

function testCorsOrigins() {
  const dev = { NODE_ENV: 'development' };
  const prod = { NODE_ENV: 'production' };

  // No website is built in: with nothing in the environment, none is allowed
  // (localhost aside, outside production).
  for (const env of [dev, prod]) {
    assert.ok(!isAllowedOrigin('https://demo.demomart.example', env), 'no built-in sites');
    // Anyone can make a *.vercel.app site, so none is allowed by default.
    assert.ok(!isAllowedOrigin('https://evil.vercel.app', env));
    assert.ok(!isAllowedOrigin('', env));
  }

  // Sites come from CORS_ORIGIN / ADMIN_PANEL_URL / FRONTEND_URL, exactly.
  const configured = {
    ...prod,
    ADMIN_PANEL_URL: 'https://admin.demomart.example',
    FRONTEND_URL: 'https://demo.demomart.example/',
  };
  assert.ok(isAllowedOrigin('https://admin.demomart.example', configured), 'admin panel from env allowed');
  assert.ok(isAllowedOrigin('https://demo.demomart.example', configured), 'website from env allowed');
  assert.ok(!isAllowedOrigin('https://demo.demomart.example.evil.com', configured));
  assert.ok(!isAllowedOrigin('http://demo.demomart.example', configured), 'plain http is not the site');

  // localhost only outside production.
  assert.ok(isAllowedOrigin('http://localhost:3001', dev));
  assert.ok(!isAllowedOrigin('http://localhost:3001', prod));
  assert.ok(!isAllowedOrigin('http://localhost.evil.com', dev));

  // Exact extra origins from env (a trailing slash is ignored).
  const withPreview = { ...prod, CORS_ORIGIN: 'https://preview-x.example.org/ , https://other.example' };
  assert.ok(isAllowedOrigin('https://preview-x.example.org', withPreview));
  assert.ok(isAllowedOrigin('https://other.example', withPreview));
  assert.ok(!isAllowedOrigin('https://preview-y.example.org', withPreview));
  assert.strictEqual(new Set(allowedOrigins(withPreview)).size, allowedOrigins(withPreview).length);
}

function runHandler(err) {
  let status;
  let body;
  const res = {
    status(code) { status = code; return this; },
    json(payload) { body = payload; return this; },
  };
  errorHandler(err, { path: '/x', method: 'GET' }, res, () => {});
  return { status, body };
}

function testErrorResponses() {
  // Unexpected errors: generic message, no stack, no internal code.
  const internal = new Error('connect ECONNREFUSED cluster0.internal-host.mongodb.net:27017');
  internal.code = 'ECONNREFUSED';
  let { status, body } = runHandler(internal);
  assert.strictEqual(status, 500);
  assert.strictEqual(body.message, 'Something went wrong. Please try again.');
  assert.strictEqual(body.error.code, 'SERVER_ERROR');
  assert.ok(!('stack' in body.error));
  assert.ok(!JSON.stringify(body).includes('internal-host'));

  // Our own errors keep their message and code.
  ({ status, body } = runHandler(new BadRequestError('Enter a valid 10-digit mobile number', 'INVALID_PHONE')));
  assert.strictEqual(status, 400);
  assert.strictEqual(body.message, 'Enter a valid 10-digit mobile number');
  assert.strictEqual(body.error.code, 'INVALID_PHONE');
  assert.ok(!('stack' in body.error));

  // Only an explicit setting shows details (local debugging).
  process.env.EXPOSE_ERROR_STACK = 'true';
  ({ body } = runHandler(new Error('boom')));
  assert.strictEqual(body.message, 'boom');
  assert.ok(body.error.stack.includes('boom'));
  delete process.env.EXPOSE_ERROR_STACK;

  // DEMO ONLY: demo mode never exposes details, whatever the setting says.
  process.env.EXPOSE_ERROR_STACK = 'true';
  process.env.DEMO_MODE = 'true';
  ({ body } = runHandler(new Error('boom')));
  assert.strictEqual(body.message, 'Something went wrong. Please try again.');
  assert.ok(!('stack' in body.error));
  delete process.env.DEMO_MODE;
  delete process.env.EXPOSE_ERROR_STACK;

  // Development mode alone no longer shows stacks.
  const previousEnv = process.env.NODE_ENV;
  process.env.NODE_ENV = 'development';
  ({ body } = runHandler(new Error('boom')));
  assert.ok(!('stack' in body.error));
  process.env.NODE_ENV = previousEnv;
}

// --- API checks against a local test database --------------------------------

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

async function runApiChecks(uri) {
  process.env.MONGODB_URI = uri;
  process.env.NODE_ENV = 'test';
  const mongoose = require('mongoose');
  const app = require('../src/app');
  const { User } = require('../src/models');
  const { signAccessToken } = require('../src/utils/jwtTokens');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const makeUser = (role) => User.create({
    name: `Http ${role}`,
    email: `http-${role}-${suffix}@example.com`,
    authProvider: 'email',
    role,
    isActive: true,
  });
  const buyer = await makeUser('buyer');
  const admin = await makeUser('admin');
  const tokenFor = (user) => signAccessToken({ userId: String(user._id) }, '10m');

  const server = app.listen(0);
  const root = `http://127.0.0.1:${server.address().port}`;
  const base = `${root}/api/v1`;
  const call = async (path, { method = 'GET', headers = {}, body, token } = {}) => {
    const res = await fetch(path.startsWith('http') ? path : base + path, {
      method,
      headers: { ...headers, ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body,
    });
    const text = await res.text();
    let json = {};
    try { json = JSON.parse(text); } catch { /* not JSON */ }
    return { status: res.status, headers: res.headers, text, body: json };
  };

  try {
    process.env.FRONTEND_URL = 'https://demo.demomart.example';
    // CORS: a stranger's site gets a clean 403 with no internals.
    let res = await call('/products/categories', { headers: { Origin: 'https://evil.vercel.app' } });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.error.code, 'CORS_ORIGIN_NOT_ALLOWED');
    assert.ok(!res.text.includes('stack') && !res.text.includes('/Users/'));
    assert.strictEqual(res.headers.get('access-control-allow-origin'), null);

    // A site named in the environment is allowed.
    res = await call('/health/live', { headers: { Origin: 'https://demo.demomart.example' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.headers.get('access-control-allow-origin'), 'https://demo.demomart.example');

    // Requests without an Origin (the app, server-side rendering) still work.
    res = await call('/health/live');
    assert.strictEqual(res.status, 200);

    // Public health checks say only whether things work.
    res = await call('/health');
    assert.strictEqual(res.status, 200);
    assert.deepStrictEqual(Object.keys(res.body).sort(), ['status', 'success', 'timestamp']);
    res = await call(`${root}/health`);
    assert.strictEqual(res.status, 200);
    assert.ok(!('environment' in res.body));
    res = await call('/health/live');
    assert.deepStrictEqual(Object.keys(res.body).sort(), ['status', 'success', 'timestamp']);

    // Details are for admins only.
    res = await call('/health/details');
    assert.strictEqual(res.status, 401);
    res = await call('/health/details', { token: tokenFor(buyer) });
    assert.strictEqual(res.status, 403);
    res = await call('/health/details', { token: tokenFor(admin) });
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.checks.mongodb.ok);

    // JSON bodies over 1 MB are refused cleanly.
    const big = JSON.stringify({ email: 'a@example.com', password: 'x'.repeat(1.2 * 1024 * 1024) });
    res = await call('/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: big });
    assert.strictEqual(res.status, 413);
    assert.strictEqual(res.body.error.code, 'PAYLOAD_TOO_LARGE');

    // Broken JSON is a 400, not a 500 with a parser stack.
    res = await call('/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"email":' });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error.code, 'INVALID_JSON');
    assert.ok(!('stack' in res.body.error));

    // Unknown routes: 404 without a stack.
    res = await call('/no-such-route');
    assert.strictEqual(res.status, 404);
    assert.ok(!('stack' in res.body.error));

    // A bad ID is a 404, not a database error.
    res = await call('/companies/not-an-id', { token: tokenFor(buyer) });
    assert.ok([400, 404].includes(res.status), `bad id status ${res.status}`);
    assert.ok(!res.text.includes('Cast to ObjectId'));
  } finally {
    server.close();
    await User.deleteMany({ _id: { $in: [buyer._id, admin._id] } });
    await mongoose.disconnect();
  }
}

async function run() {
  testCorsOrigins();
  testErrorResponses();
  const uri = testDatabaseUri('HTTP_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('HTTP hardening unit tests passed (API checks skipped: set HTTP_TEST_MONGODB_URI to a local test database)');
    return;
  }
  await runApiChecks(uri);
  console.log('HTTP hardening tests passed (unit + API)');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
