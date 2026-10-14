const logger = require('../utils/logger');
const { Negotiation } = require('../models');
const { NEGOTIATION_STATUS } = require('../utils/constants');

// Declined requirements are kept this long, then removed from the database.
const DECLINED_RETENTION_DAYS = 5;
const SWEEP_INTERVAL_MS = 6 * 60 * 60 * 1000;

// Declined before the cutoff. Older records have no rejectedAt; their last
// update (the decline) is used instead.
function declinedBefore(cutoff) {
  return {
    status: NEGOTIATION_STATUS.REJECTED,
    $or: [
      { rejectedAt: { $lte: cutoff } },
      { rejectedAt: null, updatedAt: { $lte: cutoff } },
    ],
  };
}

async function purgeDeclinedNegotiations({ now = Date.now(), retentionDays = DECLINED_RETENTION_DAYS } = {}) {
  const cutoff = new Date(now - retentionDays * 24 * 60 * 60 * 1000);
  const { deletedCount } = await Negotiation.deleteMany(declinedBefore(cutoff));
  if (deletedCount) logger.info(`[DealDesk] removed ${deletedCount} declined requirement(s) older than ${retentionDays} days`);
  return deletedCount;
}

let sweepHandle = null;

function startDeclinedNegotiationCleanupScheduler() {
  if (sweepHandle) return sweepHandle;
  const run = () => purgeDeclinedNegotiations().catch((error) => logger.error('Declined requirement cleanup failed:', error));
  sweepHandle = setInterval(run, SWEEP_INTERVAL_MS);
  sweepHandle.unref?.();
  setTimeout(run, 3 * 60 * 1000).unref?.();
  return sweepHandle;
}

module.exports = {
  DECLINED_RETENTION_DAYS,
  purgeDeclinedNegotiations,
  startDeclinedNegotiationCleanupScheduler,
};
