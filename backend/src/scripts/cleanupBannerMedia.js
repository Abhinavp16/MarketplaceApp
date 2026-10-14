// One-time cleanup of banner images / videos left in storage (banners/)
// that no banner uses any more. Files uploaded in the last 24 hours are kept.
//
// Reports only by default; deletes only with --apply.
//
//   node src/scripts/cleanupBannerMedia.js           # report
//   node src/scripts/cleanupBannerMedia.js --apply   # delete unused files
require('dotenv').config();

const mongoose = require('mongoose');
const { getStorageDriver } = require('../config/storage');
const { sweepUnusedBannerMedia } = require('../services/bannerMediaCleanupService');

async function main() {
  const apply = process.argv.includes('--apply');
  await mongoose.connect(process.env.MONGODB_URI);

  const result = await sweepUnusedBannerMedia({ dryRun: !apply });
  console.log(`Storage: ${getStorageDriver()}`);
  console.log(`Banner files: ${result.total} (in use: ${result.used}, unused: ${result.unused.length})`);
  const recent = result.unused.filter((file) => !result.expired.includes(file));
  for (const file of result.expired) console.log(`  ${apply ? 'deleted' : 'unused '}  ${file}`);
  for (const file of recent) console.log(`  kept     ${file} (uploaded in the last 24 hours)`);
  console.log(apply
    ? `\nDeleted ${result.deleted} file(s).`
    : `\nNothing was deleted. Run with --apply to delete the ${result.expired.length} unused file(s).`);

  await mongoose.disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
