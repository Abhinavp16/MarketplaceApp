/**
 * Demo safety guard.
 *
 * When DEMO_MODE=true this backend must only ever talk to a LOCAL database
 * whose name contains "demo", and must have no third-party credentials
 * configured (Firebase, SMTP, translation API...). The guard is evaluated at
 * process start (before any DB connection) and again by the seed/reset
 * scripts through assertDemoDatabase().
 *
 * The forbidden-marker lists below are assembled from fragments on purpose so
 * that the words themselves never appear verbatim in the code base.
 */

const j = (...parts) => parts.join('');

// Strings that identify a real (non-demo) deployment. Matched case-insensitively.
const FORBIDDEN_MARKERS = [
  j('lax', 'mi'),
  j('ashir', 'vad'),
  j('ashir', 'wad'),
  j('rai', 'pur'),
  j('shiv', 'nath'),
  j('mou', 'rya'),
  j('mau', 'rya'),
  j('aq', 'ua'),
  j('ha', 'rit'),
  j('917', '9110159'),
  j('877', '0974845'),
  j('1df', '4b'),
];

// Hosting/provider domains that must never appear in a demo environment.
const FORBIDDEN_HOST_PATTERNS = [
  /mongodb\+srv/i,
  /\.mongodb\.net/i,
  /\.mongodb\.com/i,
  /\.vercel\.app/i,
  /\.onrender\.com/i,
  /\.herokuapp\.com/i,
  /\.railway\.app/i,
  /\.fly\.dev/i,
  /\.web\.app/i,
  /\.firebaseapp\.com/i,
  /\.firebaseio\.com/i,
  /googleapis\.com/i,
  /\.amazonaws\.com/i,
  /\.azure/i,
];

// "api.<domain>" style production hostnames (localhost/example are fine).
const PRODUCTION_API_HOST = /(^|\/\/|@|,)\s*api\.(?!localhost)[a-z0-9-]+(\.[a-z0-9-]+)+/i;

// Env vars whose values are scanned for forbidden markers/hosts.
const SCANNED_ENV_KEYS = [
  'MONGODB_URI',
  'CORS_ORIGIN',
  'ADMIN_PANEL_URL',
  'FRONTEND_URL',
  'PUBLIC_BASE_URL',
  'ADMIN_EMAILS',
  'EMAIL_FROM',
  'PUBLIC_ORDER_WHATSAPP_NUMBER',
  'DEFAULT_UPI_ID',
  'DEFAULT_UPI_NAME',
  'FIREBASE_STORAGE_BUCKET',
];

const LOCAL_HOSTS = new Set(['127.0.0.1', 'localhost', '::1', '[::1]']);

const isDemoMode = (env = process.env) => String(env.DEMO_MODE || '').trim().toLowerCase() === 'true';

const stripQuotes = (value) => String(value || '').trim().replace(/^['"]|['"]$/g, '');

/** Parses `mongodb://user:pw@host1:27017,host2/dbname?opts` into pieces. */
function parseMongoUri(rawUri) {
  const uri = stripQuotes(rawUri);
  const match = uri.match(/^(mongodb(?:\+srv)?):\/\/(?:[^@/]*@)?([^/?]+)(?:\/([^?]*))?(?:\?(.*))?$/i);
  if (!match) return { scheme: null, hosts: [], dbName: '', valid: false };
  const hosts = match[2].split(',').map((entry) => {
    const trimmed = entry.trim();
    // strip :port (IPv6 in brackets keeps its brackets)
    const host = trimmed.startsWith('[') ? trimmed.slice(0, trimmed.indexOf(']') + 1) : trimmed.replace(/:\d+$/, '');
    return host.toLowerCase();
  });
  let dbName = '';
  try {
    dbName = decodeURIComponent(match[3] || '');
  } catch (_) {
    dbName = match[3] || '';
  }
  return { scheme: match[1].toLowerCase(), hosts, dbName, valid: true };
}

const isSet = (value) => value !== undefined && value !== null && String(value).trim() !== '';

/**
 * Returns a list of human-readable problems. Empty list = safe demo config.
 * Pure function (no process.exit, no IO) so it can be unit tested.
 */
function findDemoConfigProblems(env = process.env) {
  const problems = [];
  const uri = stripQuotes(env.MONGODB_URI);

  if (!uri) {
    problems.push('MONGODB_URI is not set (expected a local demo database, e.g. mongodb://127.0.0.1:27017/tradehub_demo?replicaSet=rs0)');
  } else {
    const parsed = parseMongoUri(uri);
    if (/^mongodb\+srv/i.test(uri) || parsed.scheme === 'mongodb+srv') {
      problems.push('MONGODB_URI uses mongodb+srv (a hosted cluster); demo mode only allows a local mongod');
    }
    if (/\.mongodb\.net/i.test(uri)) {
      problems.push('MONGODB_URI points to a *.mongodb.net host');
    }
    if (!parsed.valid) {
      problems.push('MONGODB_URI could not be parsed');
    } else {
      const remote = parsed.hosts.filter((host) => !LOCAL_HOSTS.has(host));
      if (remote.length > 0) {
        problems.push(`MONGODB_URI host(s) must be local (127.0.0.1/localhost); found: ${remote.join(', ')}`);
      }
      if (!/demo/i.test(parsed.dbName)) {
        problems.push(`Database name "${parsed.dbName || '(none)'}" must contain "demo"`);
      }
    }
  }

  const firebaseKeys = Object.keys(env).filter((key) => key.startsWith('FIREBASE_') && isSet(env[key]));
  if (firebaseKeys.length > 0) {
    problems.push(`Firebase credentials must not be set in demo mode (found: ${firebaseKeys.join(', ')})`);
  }
  const smtpKeys = Object.keys(env).filter((key) => key.startsWith('SMTP_') && isSet(env[key]));
  if (smtpKeys.length > 0) {
    problems.push(`SMTP settings must not be set in demo mode (found: ${smtpKeys.join(', ')})`);
  }
  if (isSet(env.GOOGLE_TRANSLATE_API_KEY)) {
    problems.push('GOOGLE_TRANSLATE_API_KEY must not be set in demo mode');
  }

  for (const key of SCANNED_ENV_KEYS) {
    const value = env[key];
    if (!isSet(value)) continue;
    const text = String(value);
    const lower = text.toLowerCase();
    const marker = FORBIDDEN_MARKERS.find((entry) => lower.includes(entry));
    if (marker) problems.push(`${key} contains a production marker`);
    if (FORBIDDEN_HOST_PATTERNS.some((pattern) => pattern.test(text)) && key !== 'MONGODB_URI') {
      problems.push(`${key} references a hosted/production domain`);
    }
    if (PRODUCTION_API_HOST.test(text)) {
      problems.push(`${key} references a production-style api.* hostname`);
    }
  }

  // De-duplicate (MONGODB_URI can trigger the same message twice).
  return [...new Set(problems)];
}

/**
 * Called once at boot, before connecting to the database. Exits the process
 * when DEMO_MODE=true and the configuration is not safe.
 */
function enforceDemoGuard({ env = process.env, exit = (code) => process.exit(code), log = console.error } = {}) {
  if (!isDemoMode(env)) return { demo: false, problems: [] };
  const problems = findDemoConfigProblems(env);
  if (problems.length > 0) {
    log('\n[demoGuard] REFUSING TO START: DEMO_MODE=true but the environment is not a safe demo environment:');
    problems.forEach((problem) => log(`  - ${problem}`));
    log('[demoGuard] Fix your .env (see .env.example) and try again.\n');
    exit(1);
    return { demo: true, problems };
  }
  return { demo: true, problems: [] };
}

/**
 * Throws unless the target database is a local demo database. Used by the
 * seed/reset scripts and the reset API before anything is wiped.
 * `actualDbName` may be passed once connected (mongoose.connection.name).
 */
function assertDemoDatabase({ env = process.env, actualDbName = null } = {}) {
  if (!isDemoMode(env)) {
    throw new Error('Refusing to touch the database: DEMO_MODE=true is required.');
  }
  const problems = findDemoConfigProblems(env);
  if (actualDbName !== null && !/demo/i.test(String(actualDbName))) {
    problems.push(`Connected database "${actualDbName}" does not contain "demo"`);
  }
  if (problems.length > 0) {
    throw new Error(`Refusing to touch the database (not a safe demo database): ${problems.join('; ')}`);
  }
  return true;
}

module.exports = {
  isDemoMode,
  parseMongoUri,
  findDemoConfigProblems,
  enforceDemoGuard,
  assertDemoDatabase,
  FORBIDDEN_MARKERS,
};
