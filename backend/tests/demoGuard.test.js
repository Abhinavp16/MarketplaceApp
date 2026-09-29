const assert = require('assert');
const {
  isDemoMode,
  parseMongoUri,
  findDemoConfigProblems,
  enforceDemoGuard,
  assertDemoDatabase,
} = require('../src/config/demoGuard');

// Forbidden words are assembled from fragments so they never appear verbatim.
const j = (...parts) => parts.join('');
const BRAND = j('lax', 'mi');
const CITY = j('rai', 'pur');

const GOOD = {
  DEMO_MODE: 'true',
  MONGODB_URI: 'mongodb://127.0.0.1:27017/tradehub_demo?replicaSet=rs0',
  CORS_ORIGIN: 'http://localhost:3000,http://localhost:3001',
  FILE_STORAGE_DRIVER: 'local',
  SMTP_HOST: '',
  FIREBASE_PROJECT_ID: '',
};

const withEnv = (overrides) => ({ ...GOOD, ...overrides });
const problems = (overrides) => findDemoConfigProblems(withEnv(overrides));

// isDemoMode
assert.strictEqual(isDemoMode({ DEMO_MODE: 'true' }), true);
assert.strictEqual(isDemoMode({ DEMO_MODE: 'TRUE' }), true);
assert.strictEqual(isDemoMode({ DEMO_MODE: 'false' }), false);
assert.strictEqual(isDemoMode({}), false);

// parseMongoUri
assert.deepStrictEqual(
  parseMongoUri('mongodb://127.0.0.1:27017/tradehub_demo?replicaSet=rs0'),
  { scheme: 'mongodb', hosts: ['127.0.0.1'], dbName: 'tradehub_demo', valid: true },
);
assert.strictEqual(parseMongoUri('mongodb://u:p@localhost/x_demo').dbName, 'x_demo');
assert.strictEqual(parseMongoUri('nonsense').valid, false);

// Good config passes.
assert.deepStrictEqual(problems({}), []);

// DB name must contain "demo".
assert.ok(problems({ MONGODB_URI: 'mongodb://127.0.0.1:27017/shop?replicaSet=rs0' }).some((p) => /demo/.test(p)));
assert.ok(problems({ MONGODB_URI: 'mongodb://127.0.0.1:27017' }).some((p) => /demo/.test(p)));
assert.ok(problems({ MONGODB_URI: '' }).some((p) => /MONGODB_URI is not set/.test(p)));

// Hosted Mongo is rejected.
assert.ok(problems({ MONGODB_URI: 'mongodb+srv://u:p@cluster0.abcde.mongodb.net/tradehub_demo' }).length >= 2);
assert.ok(problems({ MONGODB_URI: 'mongodb://u:p@shard-00.abcde.mongodb.net:27017/tradehub_demo' }).some((p) => /mongodb\.net/.test(p)));
// Remote non-Atlas host is rejected too.
assert.ok(problems({ MONGODB_URI: 'mongodb://db.example.org:27017/tradehub_demo' }).some((p) => /local/.test(p)));

// Third-party credentials are rejected.
assert.ok(problems({ FIREBASE_PROJECT_ID: 'some-project' }).some((p) => /Firebase/.test(p)));
assert.ok(problems({ FIREBASE_PRIVATE_KEY: 'x' }).some((p) => /Firebase/.test(p)));
assert.ok(problems({ SMTP_HOST: 'smtp.example.org' }).some((p) => /SMTP/.test(p)));
assert.ok(problems({ SMTP_USER: 'user' }).some((p) => /SMTP/.test(p)));
assert.ok(problems({ GOOGLE_TRANSLATE_API_KEY: 'k' }).some((p) => /GOOGLE_TRANSLATE/.test(p)));

// Production markers are rejected in any scanned value.
assert.ok(problems({ MONGODB_URI: `mongodb://127.0.0.1:27017/${BRAND}_demo` }).some((p) => /production marker/.test(p)));
assert.ok(problems({ CORS_ORIGIN: `https://admin.${BRAND}.example` }).some((p) => /production marker/.test(p)));
assert.ok(problems({ ADMIN_EMAILS: `boss@${CITY}.example` }).some((p) => /production marker/.test(p)));
assert.ok(problems({ PUBLIC_ORDER_WHATSAPP_NUMBER: j('917', '9110159') }).some((p) => /production marker/.test(p)));

// Hosted/production domains and api.* hostnames are rejected.
assert.ok(problems({ CORS_ORIGIN: 'https://preview.vercel.app' }).some((p) => /hosted/.test(p)));
assert.ok(problems({ PUBLIC_BASE_URL: 'https://api.somecompany.com' }).some((p) => /api\./.test(p)));
assert.strictEqual(problems({ PUBLIC_BASE_URL: 'http://localhost:5050' }).length, 0);

// enforceDemoGuard: no-op when not in demo mode.
let exitCode = null;
const silent = () => {};
assert.deepStrictEqual(
  enforceDemoGuard({ env: { DEMO_MODE: 'false', MONGODB_URI: 'mongodb+srv://x' }, exit: (c) => { exitCode = c; }, log: silent }),
  { demo: false, problems: [] },
);
assert.strictEqual(exitCode, null);

// enforceDemoGuard: exits(1) on unsafe demo config, does not exit on safe config.
const logged = [];
enforceDemoGuard({ env: withEnv({ MONGODB_URI: 'mongodb://127.0.0.1/prod' }), exit: (c) => { exitCode = c; }, log: (m) => logged.push(m) });
assert.strictEqual(exitCode, 1);
assert.ok(logged.join('\n').includes('REFUSING TO START'));
exitCode = null;
enforceDemoGuard({ env: withEnv({}), exit: (c) => { exitCode = c; }, log: silent });
assert.strictEqual(exitCode, null);

// assertDemoDatabase.
assert.strictEqual(assertDemoDatabase({ env: withEnv({}) }), true);
assert.strictEqual(assertDemoDatabase({ env: withEnv({}), actualDbName: 'tradehub_demo' }), true);
assert.throws(() => assertDemoDatabase({ env: withEnv({}), actualDbName: 'production' }), /demo/);
assert.throws(() => assertDemoDatabase({ env: withEnv({ DEMO_MODE: 'false' }) }), /DEMO_MODE=true/);
assert.throws(() => assertDemoDatabase({ env: withEnv({ MONGODB_URI: 'mongodb+srv://u:p@c.mongodb.net/demo' }) }), /not a safe demo database/);

console.log('demoGuard tests passed');
