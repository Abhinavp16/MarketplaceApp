const crypto = require('crypto');
const jwt = require('jsonwebtoken');

// Access and refresh tokens are both JWTs. They must never be interchangeable:
// a refresh token (long-lived, revocable in the DB) is refused wherever an
// access token is expected, and only refresh tokens are accepted at
// /auth/refresh-token.

const ALGORITHM = 'HS256';
const TOKEN_TYPES = Object.freeze({ ACCESS: 'access', REFRESH: 'refresh' });
const MIN_SECRET_LENGTH = 32;

// SHA-256 of secrets that are known to be public (they were committed to the
// repository). Stored as hashes so the values aren't repeated here.
const LEAKED_SECRET_HASHES = new Set([
  'a61b76d2bb17e5ca6002eb9c96eeb188097c85be0f820f395648b086c9834dc6',
]);

const sha256 = (value) => crypto.createHash('sha256').update(String(value)).digest('hex');

const accessSecret = () => process.env.JWT_SECRET;
// Optional separate secret for refresh tokens; falls back to JWT_SECRET so
// existing deployments keep working until it is set.
const refreshSecret = () => process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET;

// Every token gets its own id (jti), so two tokens issued for the same user in
// the same second are still different (refresh tokens are unique in the DB).
function signAccessToken(payload, expiresIn) {
  return jwt.sign({ ...payload, type: TOKEN_TYPES.ACCESS }, accessSecret(), {
    algorithm: ALGORITHM,
    expiresIn,
    jwtid: crypto.randomUUID(),
  });
}

function signRefreshToken(payload, expiresIn) {
  return jwt.sign({ ...payload, type: TOKEN_TYPES.REFRESH }, refreshSecret(), {
    algorithm: ALGORITHM,
    expiresIn,
    jwtid: crypto.randomUUID(),
  });
}

/**
 * Verifies a token for API access. Refresh tokens are rejected; access tokens
 * issued before token types existed (no `type`) are still accepted until they
 * expire.
 */
function verifyAccessToken(token) {
  const decoded = jwt.verify(token, accessSecret(), { algorithms: [ALGORITHM] });
  if (decoded.type && decoded.type !== TOKEN_TYPES.ACCESS) {
    throw new jwt.JsonWebTokenError('Token is not an access token');
  }
  return decoded;
}

/** Verifies a refresh token; anything else (e.g. an access token) is rejected. */
function verifyRefreshToken(token) {
  const decoded = jwt.verify(token, refreshSecret(), { algorithms: [ALGORITHM] });
  if (decoded.type !== TOKEN_TYPES.REFRESH) {
    throw new jwt.JsonWebTokenError('Token is not a refresh token');
  }
  return decoded;
}

/**
 * Problems with the JWT configuration: missing, too short, or a value known to
 * be public. Empty when the configuration is safe.
 */
function jwtConfigProblems(env = process.env) {
  const problems = [];
  const secrets = [['JWT_SECRET', env.JWT_SECRET]];
  if (env.JWT_REFRESH_SECRET) secrets.push(['JWT_REFRESH_SECRET', env.JWT_REFRESH_SECRET]);
  for (const [name, value] of secrets) {
    if (!value) {
      problems.push(`${name} is not set`);
    } else if (value.length < MIN_SECRET_LENGTH) {
      problems.push(`${name} must be at least ${MIN_SECRET_LENGTH} characters`);
    } else if (LEAKED_SECRET_HASHES.has(sha256(value))) {
      problems.push(`${name} is a publicly known value and must be replaced`);
    }
  }
  return problems;
}

/** In production, refuses to run with an unsafe JWT configuration. */
function assertJwtConfig(env = process.env) {
  if (env.NODE_ENV !== 'production') return;
  const problems = jwtConfigProblems(env);
  if (problems.length) {
    throw new Error(`Unsafe JWT configuration: ${problems.join('; ')}`);
  }
}

module.exports = {
  TOKEN_TYPES,
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  jwtConfigProblems,
  assertJwtConfig,
};
