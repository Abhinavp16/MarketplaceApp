const logger = require('../utils/logger');
const { Product, Category } = require('../models');
const { PRODUCT_STATUS } = require('../utils/constants');
const { HINDI_NAME_SWEEP_MINUTES, HINDI_NAME_SWEEP_BATCH } = require('../utils/hindiNames');
const { fillHindiNames } = require('./hindiNameService');
const { normalizeSearchText } = require('../utils/searchQuery');

const SEARCH_TEXT_BATCH = 500;

// Products saved before search normalization existed get their search copy
// of the Hindi name filled in (a few hundred per run).
async function backfillSearchText(limit = SEARCH_TEXT_BATCH) {
  const products = await Product.find({ searchTextHindi: { $exists: false } })
    .select('_id nameHindi')
    .limit(limit)
    .lean();
  if (products.length === 0) return 0;
  await Product.bulkWrite(products.map((product) => ({
    updateOne: {
      filter: { _id: product._id, searchTextHindi: { $exists: false } },
      update: { $set: { searchTextHindi: normalizeSearchText(product.nameHindi) } },
    },
  })), { ordered: false });
  return products.length;
}

// Every HINDI_NAME_SWEEP_MINUTES, fill Hindi names that are still empty or
// broken (e.g. the conversion service was down when the item was saved).
async function runHindiNameSweep() {
  const [products, categories] = await Promise.all([
    fillHindiNames(Product, {
      mode: 'repair',
      limit: HINDI_NAME_SWEEP_BATCH,
      extraFilter: { status: { $ne: PRODUCT_STATUS.ARCHIVED } },
    }),
    fillHindiNames(Category, { mode: 'repair', limit: HINDI_NAME_SWEEP_BATCH }),
  ]);
  const searchText = await backfillSearchText();
  if (products.updated || categories.updated || searchText) {
    logger.info(`[HindiNames] sweep filled ${products.updated} products, ${categories.updated} categories; search text for ${searchText} products`);
  }
  return { products, categories, searchText };
}

let sweepHandle = null;

function startHindiNameScheduler() {
  if (sweepHandle) return sweepHandle;
  const run = () => runHindiNameSweep().catch((error) => logger.error('Hindi name sweep failed:', error));
  sweepHandle = setInterval(run, HINDI_NAME_SWEEP_MINUTES * 60 * 1000);
  // First run shortly after start-up, so it doesn't compete with boot work.
  setTimeout(run, 60 * 1000).unref?.();
  return sweepHandle;
}

module.exports = { startHindiNameScheduler, runHindiNameSweep, backfillSearchText };
