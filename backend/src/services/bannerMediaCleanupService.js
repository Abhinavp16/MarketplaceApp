const logger = require('../utils/logger');
const { Settings } = require('../models');
const { deleteFile, listFiles } = require('../config/storage');
const {
  BANNER_FOLDER,
  replacedBannerPaths,
  usedBannerPaths,
} = require('../utils/bannerMedia');

// Uploads not used by any banner are kept this long before the sweep deletes
// them, so a video uploaded while editing survives until the admin saves.
const UNUSED_UPLOAD_GRACE_MS = 24 * 60 * 60 * 1000;
const SWEEP_INTERVAL_MS = 24 * 60 * 60 * 1000;

async function deletePaths(paths) {
  let deleted = 0;
  for (const storagePath of paths) {
    try {
      if (await deleteFile(storagePath)) deleted += 1;
    } catch (error) {
      logger.warn(`[BannerMedia] could not delete ${storagePath}: ${error.message}`);
    }
  }
  return deleted;
}

// After banners are saved: delete the files of removed / replaced media.
async function deleteReplacedBannerMedia(before, after) {
  const paths = replacedBannerPaths(before, after);
  if (paths.length === 0) return 0;
  const deleted = await deletePaths(paths);
  logger.info(`[BannerMedia] deleted ${deleted} removed banner file(s)`);
  return deleted;
}

// Files in banners/ that no banner uses and that are older than the grace
// period (e.g. uploaded and then cancelled). dryRun only reports them.
async function sweepUnusedBannerMedia({ dryRun = false, now = Date.now(), graceMs = UNUSED_UPLOAD_GRACE_MS } = {}) {
  const settings = await Settings.findById('app_settings').select('heroBanners promoBanners').lean();
  // No settings record: never guess, delete nothing.
  if (!settings) return { total: 0, used: 0, unused: [], expired: [], deleted: 0 };
  const used = usedBannerPaths(settings);
  const files = await listFiles(BANNER_FOLDER);
  const unused = files.filter((file) => !used.has(file.publicId));
  const expired = unused.filter((file) => now - new Date(file.updatedAt).getTime() > graceMs);
  const deleted = dryRun ? 0 : await deletePaths(expired.map((file) => file.publicId));
  if (!dryRun && deleted) logger.info(`[BannerMedia] sweep deleted ${deleted} unused banner file(s)`);
  return {
    total: files.length,
    used: files.length - unused.length,
    unused: unused.map((file) => file.publicId),
    expired: expired.map((file) => file.publicId),
    deleted,
  };
}

let sweepHandle = null;

function startBannerMediaSweepScheduler() {
  if (sweepHandle) return sweepHandle;
  const run = () => sweepUnusedBannerMedia().catch((error) => logger.error('Banner media sweep failed:', error));
  sweepHandle = setInterval(run, SWEEP_INTERVAL_MS);
  sweepHandle.unref?.();
  setTimeout(run, 5 * 60 * 1000).unref?.();
  return sweepHandle;
}

module.exports = {
  deleteReplacedBannerMedia,
  sweepUnusedBannerMedia,
  startBannerMediaSweepScheduler,
  UNUSED_UPLOAD_GRACE_MS,
};
