// Websites allowed to call the API from a browser. The mobile app and
// server-side rendering send no Origin header and are not affected.
//
// Allowed origins come only from the environment: CORS_ORIGIN, ADMIN_PANEL_URL
// and FRONTEND_URL, comma separated exact origins. There are no wildcards.
// localhost is allowed outside production only.

const LOCALHOST_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i;

const listFrom = (value) => String(value || '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/+$/, ''))
  .filter(Boolean);

function allowedOrigins(env = process.env) {
  return [...new Set([
    ...listFrom(env.CORS_ORIGIN),
    ...listFrom(env.ADMIN_PANEL_URL),
    ...listFrom(env.FRONTEND_URL),
  ])];
}

function isAllowedOrigin(origin, env = process.env) {
  if (!origin) return false;
  if (allowedOrigins(env).includes(origin)) return true;
  return env.NODE_ENV !== 'production' && LOCALHOST_ORIGIN.test(origin);
}

module.exports = { allowedOrigins, isAllowedOrigin };
