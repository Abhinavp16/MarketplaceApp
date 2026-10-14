const rateLimit = require('express-rate-limit');
const { verifyAccessToken } = require('../utils/jwtTokens');
const { isDemoMode } = require('../config/demoGuard');

const MINUTE = 60 * 1000;

/**
 * The client's IP address. On Vercel the edge puts the real client address in
 * x-real-ip / x-vercel-forwarded-for (overwriting whatever the client sent);
 * elsewhere (e.g. the VPS behind Caddy) Express's req.ip applies, which honours
 * the `trust proxy` setting.
 */
function clientIp(req) {
  if (process.env.VERCEL) {
    const forwarded = String(req.headers['x-vercel-forwarded-for'] || '').split(',')[0].trim();
    const ip = String(req.headers['x-real-ip'] || '').trim() || forwarded;
    if (ip) return ip;
  }
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

/**
 * Signed-in users get their own allowance (many customers can share one mobile
 * network IP); everyone else is counted by IP. The token's signature is checked,
 * so a made-up token can't buy a fresh allowance.
 */
function userOrIpKey(req) {
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    try {
      const decoded = verifyAccessToken(header.slice(7));
      if (decoded.userId) return `user:${decoded.userId}`;
    } catch {
      // Invalid or expired token: counted by IP below.
    }
  }
  return `ip:${clientIp(req)}`;
}

// DEMO ONLY: repeated sign-ins from one machine (e2e runs, a sales walkthrough
// switching between accounts) must never lock the demo out.
const skipInDemo = () => isDemoMode();

const tooMany = (code, message) => ({ success: false, message, error: { code } });

const limiter = ({ windowMs, limit, keyGenerator, code, message, ...options }) => rateLimit({
  windowMs,
  limit,
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  message: tooMany(code, message),
  ...options,
});

/** Every /api request: 200 per minute per signed-in user or IP. */
const apiLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || MINUTE,
  limit: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 200,
  skip: (req) => req.originalUrl.startsWith('/api/v1/health'),
  keyGenerator: userOrIpKey,
  message: tooMany('RATE_LIMIT_EXCEEDED', 'Too many requests, please try again later.'),
});

/** Sign-in attempts from one IP, successful or not. */
const loginIpLimiter = limiter({
  skip: skipInDemo,
  windowMs: 15 * MINUTE,
  limit: 20,
  keyGenerator: (req) => `login-ip:${clientIp(req)}`,
  code: 'TOO_MANY_LOGIN_ATTEMPTS',
  message: 'Too many sign-in attempts. Please try again in 15 minutes.',
});

/**
 * Failed sign-ins for one account (email, phone or member username), from any
 * IP: after 10 failures the account's sign-in pauses for the rest of the
 * 15 minutes. Successful sign-ins don't count.
 */
const loginAccountLimiter = limiter({
  skip: skipInDemo,
  windowMs: 15 * MINUTE,
  limit: 10,
  skipSuccessfulRequests: true,
  keyGenerator: (req) => {
    const account = String(req.body?.email || req.body?.phone || req.body?.username || '')
      .trim()
      .toLowerCase();
    return account ? `login-account:${account}` : `login-account-ip:${clientIp(req)}`;
  },
  code: 'TOO_MANY_LOGIN_ATTEMPTS',
  message: 'Too many failed sign-in attempts for this account. Please try again in 15 minutes.',
});

const registerLimiter = limiter({
  skip: skipInDemo,
  windowMs: 15 * MINUTE,
  limit: 10,
  keyGenerator: (req) => `register:${clientIp(req)}`,
  code: 'TOO_MANY_REGISTRATIONS',
  message: 'Too many sign-ups from this network. Please try again later.',
});

const refreshLimiter = limiter({
  skip: skipInDemo,
  windowMs: 15 * MINUTE,
  limit: 60,
  keyGenerator: (req) => `refresh:${clientIp(req)}`,
  code: 'RATE_LIMIT_EXCEEDED',
  message: 'Too many requests, please try again later.',
});

const magicLinkLimiter = limiter({
  windowMs: 15 * MINUTE,
  limit: 5,
  keyGenerator: (req) => `magic-link:${clientIp(req)}`,
  code: 'MAGIC_LINK_RATE_LIMITED',
  message: 'Too many magic-link requests. Please try again later.',
});

const couponPreviewLimiter = limiter({
  windowMs: 15 * MINUTE,
  limit: 20,
  keyGenerator: (req) => `coupon:${userOrIpKey(req)}`,
  code: 'RATE_LIMIT_EXCEEDED',
  message: 'Too many coupon checks. Please try again later.',
});

const publicFormLimiter = limiter({
  windowMs: 60 * MINUTE,
  limit: 5,
  keyGenerator: (req) => `form:${clientIp(req)}`,
  code: 'RATE_LIMIT_EXCEEDED',
  message: 'Too many requests, please try again later.',
});

module.exports = {
  clientIp,
  userOrIpKey,
  apiLimiter,
  loginIpLimiter,
  loginAccountLimiter,
  registerLimiter,
  refreshLimiter,
  magicLinkLimiter,
  couponPreviewLimiter,
  publicFormLimiter,
};
