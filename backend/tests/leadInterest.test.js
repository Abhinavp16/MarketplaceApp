const assert = require('assert');

const {
  LEAD_DELAY_MINUTES,
  LEAD_RETENTION_DAYS,
  interestLevel,
  isLeadRole,
  resolveLeadPeriodDays,
  sanitizeWatchSeconds,
} = require('../src/utils/leadInterest');

assert.strictEqual(LEAD_DELAY_MINUTES, 10);
assert.strictEqual(LEAD_RETENTION_DAYS, 5);

// Watch time: whole seconds, 1s..30min per report, junk ignored.
assert.strictEqual(sanitizeWatchSeconds(12.4), 12);
assert.strictEqual(sanitizeWatchSeconds('30'), 30);
assert.strictEqual(sanitizeWatchSeconds(0), 0);
assert.strictEqual(sanitizeWatchSeconds(0.4), 0);
assert.strictEqual(sanitizeWatchSeconds(-5), 0);
assert.strictEqual(sanitizeWatchSeconds('abc'), 0);
assert.strictEqual(sanitizeWatchSeconds(undefined), 0);
assert.strictEqual(sanitizeWatchSeconds(99999), 1800);

// Period: 1/3/5 days (or '1d'/'3d'/'5d'); anything else is the 5-day window.
assert.strictEqual(resolveLeadPeriodDays('1d'), 1);
assert.strictEqual(resolveLeadPeriodDays(3), 3);
assert.strictEqual(resolveLeadPeriodDays('7d'), 5);
assert.strictEqual(resolveLeadPeriodDays(undefined), 5);

// Only customers and wholesalers are leads.
assert.strictEqual(isLeadRole('buyer'), true);
assert.strictEqual(isLeadRole('wholesaler'), true);
assert.strictEqual(isLeadRole('staff'), false);
assert.strictEqual(isLeadRole('admin'), false);

// Interest: views or total watch time.
assert.strictEqual(interestLevel({ viewCount: 1, totalWatchSeconds: 5 }), 'Browsing');
assert.strictEqual(interestLevel({ viewCount: 3, totalWatchSeconds: 0 }), 'Warm');
assert.strictEqual(interestLevel({ viewCount: 1, totalWatchSeconds: 45 }), 'Warm');
assert.strictEqual(interestLevel({ viewCount: 5, totalWatchSeconds: 0 }), 'Hot');
assert.strictEqual(interestLevel({ viewCount: 2, totalWatchSeconds: 120 }), 'Hot');
assert.strictEqual(interestLevel({}), 'Browsing');

console.log('leadInterest tests passed');
