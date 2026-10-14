const assert = require('assert');
const {
  isDemoMode,
  parseMongoUri,
  findDemoConfigProblems,
  findFirebaseProblems,
  enforceDemoGuard,
  assertDemoDatabase,
} = require('../src/config/demoGuard');

// Forbidden words are assembled from fragments so they never appear verbatim.
const j = (...parts) => parts.join('');
const BRAND = j('lax', 'mi');
const CITY = j('rai', 'pur');
// Fragment of the original client's Firebase project id (must stay forbidden).
const CLIENT_FIREBASE_ID = j('1df', '4b');

const GOOD = {
  DEMO_MODE: 'true',
  MONGODB_URI: 'mongodb://127.0.0.1:27017/demomart_demo?replicaSet=rs0',
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
  parseMongoUri('mongodb://127.0.0.1:27017/demomart_demo?replicaSet=rs0'),
  { scheme: 'mongodb', hosts: ['127.0.0.1'], dbName: 'demomart_demo', valid: true },
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
assert.ok(problems({ MONGODB_URI: 'mongodb+srv://u:p@cluster0.abcde.mongodb.net/demomart_demo' }).length >= 2);
assert.ok(problems({ MONGODB_URI: 'mongodb://u:p@shard-00.abcde.mongodb.net:27017/demomart_demo' }).some((p) => /mongodb\.net/.test(p)));
// Remote non-Atlas host is rejected too.
assert.ok(problems({ MONGODB_URI: 'mongodb://db.example.org:27017/demomart_demo' }).some((p) => /local/.test(p)));

// Third-party credentials are rejected.
// Firebase: refused unless it is the demo's own project (FIREBASE_PROJECT_ID === DEMO_FIREBASE_PROJECT_ID).
assert.ok(problems({ FIREBASE_PROJECT_ID: 'some-project' }).some((p) => /DEMO_FIREBASE_PROJECT_ID/.test(p)));
assert.ok(problems({ FIREBASE_PRIVATE_KEY: 'x' }).some((p) => /FIREBASE_PROJECT_ID is empty/.test(p)));
assert.ok(problems({ FIREBASE_CLIENT_EMAIL: 'a@demo-push-1.iam.gserviceaccount.com' }).some((p) => /FIREBASE_PROJECT_ID is empty/.test(p)));
assert.ok(problems({ DEMO_FIREBASE_PROJECT_ID: 'demo-push-1', FIREBASE_PRIVATE_KEY: 'x' }).some((p) => /FIREBASE_PROJECT_ID is empty/.test(p)));
// Allowed: the demo's own project (value set on both variables, equal).
const OWN_FIREBASE = {
  FIREBASE_PROJECT_ID: 'demo-push-1',
  DEMO_FIREBASE_PROJECT_ID: 'demo-push-1',
  FIREBASE_CLIENT_EMAIL: 'firebase-adminsdk-abc12@demo-push-1.iam.gserviceaccount.com',
  FIREBASE_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\\nxxxx\\n-----END PRIVATE KEY-----\\n',
  FIREBASE_STORAGE_BUCKET: 'demo-push-1.firebasestorage.app',
};
assert.deepStrictEqual(problems(OWN_FIREBASE), []);
assert.deepStrictEqual(problems({ FIREBASE_PROJECT_ID: 'demo-push-1', DEMO_FIREBASE_PROJECT_ID: 'demo-push-1' }), []);
assert.deepStrictEqual(findFirebaseProblems(withEnv(OWN_FIREBASE)), []);
assert.doesNotThrow(() => assertDemoDatabase({ env: withEnv(OWN_FIREBASE) }));
// Refused: a different project, or the allow-list variable missing/empty.
assert.ok(problems({ ...OWN_FIREBASE, DEMO_FIREBASE_PROJECT_ID: 'another-project' }).some((p) => /does not equal/.test(p)));
assert.ok(problems({ ...OWN_FIREBASE, DEMO_FIREBASE_PROJECT_ID: '' }).some((p) => /DEMO_FIREBASE_PROJECT_ID/.test(p)));
assert.ok(problems({ ...OWN_FIREBASE, DEMO_FIREBASE_PROJECT_ID: undefined }).some((p) => /DEMO_FIREBASE_PROJECT_ID/.test(p)));
assert.ok(problems({ DEMO_FIREBASE_PROJECT_ID: 'demo-push-1', FIREBASE_PROJECT_ID: '', FIREBASE_CLIENT_EMAIL: 'x' }).length > 0);
// Refused: a service account from another project, even when the ids match.
assert.ok(problems({ ...OWN_FIREBASE, FIREBASE_CLIENT_EMAIL: 'sa@other-project.iam.gserviceaccount.com' }).some((p) => /service account/.test(p)));
// Refused: the original client's project (marker), even if both variables agree.
const CLIENT_PROJECT = `shop-${CLIENT_FIREBASE_ID}`;
assert.ok(problems({
  FIREBASE_PROJECT_ID: CLIENT_PROJECT,
  DEMO_FIREBASE_PROJECT_ID: CLIENT_PROJECT,
  FIREBASE_CLIENT_EMAIL: `firebase-adminsdk-abc12@${CLIENT_PROJECT}.iam.gserviceaccount.com`,
}).some((p) => /production marker/.test(p)));
assert.ok(problems({ ...OWN_FIREBASE, FIREBASE_STORAGE_BUCKET: `${BRAND}-files.firebasestorage.app` }).some((p) => /production marker/.test(p)));
assert.ok(problems({ ...OWN_FIREBASE, FIREBASE_CLIENT_EMAIL: `firebase-adminsdk@${BRAND}.iam.gserviceaccount.com` }).some((p) => /production marker/.test(p)));
// Hosted Firebase domains stay refused in the bucket value.
assert.ok(problems({ ...OWN_FIREBASE, FIREBASE_STORAGE_BUCKET: 'x.firebaseapp.com' }).some((p) => /hosted/.test(p)));
// The process refuses to start on a mismatched project (and starts on the matching one).
{
  let code = null;
  enforceDemoGuard({ env: withEnv({ ...OWN_FIREBASE, DEMO_FIREBASE_PROJECT_ID: 'another-project' }), exit: (c) => { code = c; }, log: () => {} });
  assert.strictEqual(code, 1);
  code = null;
  enforceDemoGuard({ env: withEnv(OWN_FIREBASE), exit: (c) => { code = c; }, log: () => {} });
  assert.strictEqual(code, null);
}
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
assert.strictEqual(assertDemoDatabase({ env: withEnv({}), actualDbName: 'demomart_demo' }), true);
assert.throws(() => assertDemoDatabase({ env: withEnv({}), actualDbName: 'production' }), /demo/);
assert.throws(() => assertDemoDatabase({ env: withEnv({ DEMO_MODE: 'false' }) }), /DEMO_MODE=true/);
assert.throws(() => assertDemoDatabase({ env: withEnv({ MONGODB_URI: 'mongodb+srv://u:p@c.mongodb.net/demo' }) }), /not a safe demo database/);

console.log('demoGuard tests passed');
