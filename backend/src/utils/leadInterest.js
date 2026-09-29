// Lead (potential customer) rules. A lead is one person + one product.
//
// A lead shows on the admin Leads page LEAD_DELAY_MINUTES after the person's
// last view (giving them time to buy on their own) and is deleted
// LEAD_RETENTION_DAYS after that last view. Every re-view restarts both.
const LEAD_DELAY_MINUTES = 10;
const LEAD_RETENTION_DAYS = 5;
const LEAD_PERIOD_OPTIONS = [1, 3, 5];

// One watch-time report covers a single stay on the product page.
const MAX_WATCH_SECONDS_PER_REPORT = 30 * 60;

const LEAD_ROLES = ['buyer', 'wholesaler'];

const isLeadRole = (role) => LEAD_ROLES.includes(role);

const sanitizeWatchSeconds = (value) => {
  const seconds = Math.round(Number(value));
  if (!Number.isFinite(seconds) || seconds < 1) return 0;
  return Math.min(seconds, MAX_WATCH_SECONDS_PER_REPORT);
};

// Accepts 1/3/5 or '1d'/'3d'/'5d'; anything else means the full retention window.
const resolveLeadPeriodDays = (value) => {
  const days = Number.parseInt(String(value ?? ''), 10);
  return LEAD_PERIOD_OPTIONS.includes(days) ? days : LEAD_RETENTION_DAYS;
};

// Hot / Warm / Browsing from repeat views and total time spent on the page.
const INTEREST_THRESHOLDS = Object.freeze({
  hot: { views: 5, watchSeconds: 120 },
  warm: { views: 3, watchSeconds: 45 },
});

const meets = (level, { viewCount = 0, totalWatchSeconds = 0 }) => (
  viewCount >= INTEREST_THRESHOLDS[level].views
  || totalWatchSeconds >= INTEREST_THRESHOLDS[level].watchSeconds
);

const interestLevel = (lead = {}) => {
  if (meets('hot', lead)) return 'Hot';
  if (meets('warm', lead)) return 'Warm';
  return 'Browsing';
};

module.exports = {
  LEAD_DELAY_MINUTES,
  LEAD_RETENTION_DAYS,
  LEAD_PERIOD_OPTIONS,
  MAX_WATCH_SECONDS_PER_REPORT,
  LEAD_ROLES,
  isLeadRole,
  sanitizeWatchSeconds,
  resolveLeadPeriodDays,
  INTEREST_THRESHOLDS,
  interestLevel,
};
