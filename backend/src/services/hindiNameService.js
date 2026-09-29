const axios = require('axios');
const { isDemoMode } = require('../config/demoGuard');
const logger = require('../utils/logger');
const { normalizeSearchText } = require('../utils/searchQuery');
const {
  HINDI_NAME_SOURCES,
  buildHindiName,
  isBrokenHindiName,
  localizeUnits,
  normalizeDigits,
  splitForConversion,
} = require('../utils/hindiNames');

// Converts plain English words to Hindi. Uses Google Cloud Translation when
// GOOGLE_TRANSLATE_API_KEY is set, otherwise Google Input Tools
// transliteration (English sounds in Hindi letters).
const cache = new Map();
const REQUEST_TIMEOUT_MS = 5000;

async function translateWithGoogle(text, apiKey) {
  const response = await axios.post(
    'https://translation.googleapis.com/language/translate/v2',
    { q: text, source: 'en', target: 'hi', format: 'text' },
    { params: { key: apiKey }, timeout: REQUEST_TIMEOUT_MS },
  );
  return response.data?.data?.translations?.[0]?.translatedText || null;
}

async function transliterateWithInputTools(text) {
  const response = await axios.get('https://inputtools.google.com/request', {
    params: { text, itc: 'hi-t-i0-und', num: 1 },
    timeout: REQUEST_TIMEOUT_MS,
  });
  const data = response.data;
  if (Array.isArray(data) && data[0] === 'SUCCESS' && typeof data?.[1]?.[0]?.[1]?.[0] === 'string') {
    return data[1][0][1][0];
  }
  return null;
}

async function convertWords(text) {
  const key = String(text || '').trim();
  if (!key) return null;
  // Demo mode is fully offline: never call external translation services.
  if (isDemoMode()) return null;
  if (cache.has(key)) return cache.get(key);

  const apiKey = process.env.GOOGLE_TRANSLATE_API_KEY;
  const result = apiKey
    ? await translateWithGoogle(key, apiKey)
    : await transliterateWithInputTools(key);
  if (result) cache.set(key, result);
  return result;
}

// Returns the Hindi name for an English name. Names made only of numbers and
// codes (e.g. "V-4 2 HP") are returned unchanged. Returns null if the
// conversion service could not be reached (caller retries later).
async function generateHindiName(englishName, { converter = convertWords } = {}) {
  const input = String(englishName || '').trim();
  if (!input) return null;
  const hasWords = splitForConversion(input).some((segment) => segment.protect === false);
  // Only numbers/codes/units: keep them, but write units in Hindi ("10 m" -> "10 मी").
  if (!hasWords) return normalizeDigits(localizeUnits(input));
  try {
    return await buildHindiName(input, converter);
  } catch (error) {
    logger.warn(`[HindiNames] conversion failed for "${input}": ${error.message}`);
    return null;
  }
}

const EMPTY_HINDI = [{ nameHindi: { $exists: false } }, { nameHindi: null }, { nameHindi: '' }];
const BROKEN_HINDI = [{ nameHindi: /_|नुम|प्लेसहोल्डर|[०-९]/ }];

// Fills Hindi names on a model (Product or Category).
//   mode 'missing': empty names only; 'repair': empty or broken names.
//   ids: limit to these documents (used right after a save).
// Updates are conditional on the stored value, so a Hindi name typed by an
// admin in the meantime is never overwritten, and parallel runs are safe.
async function fillHindiNames(model, { mode = 'missing', ids = null, limit = 0, extraFilter = {}, converter } = {}) {
  const query = {
    ...extraFilter,
    $or: mode === 'repair' ? [...EMPTY_HINDI, ...BROKEN_HINDI] : EMPTY_HINDI,
  };
  if (Array.isArray(ids)) query._id = { $in: ids };

  let finder = model.find(query).select('_id name nameHindi').sort({ createdAt: 1 }).lean();
  if (limit > 0) finder = finder.limit(limit);
  const docs = await finder;

  const stats = { processed: docs.length, updated: 0, skipped: 0, failed: 0, failedItems: [] };
  const concurrency = 5;
  for (let i = 0; i < docs.length; i += concurrency) {
    await Promise.all(docs.slice(i, i + concurrency).map(async (doc) => {
      const englishName = String(doc.name || '').trim();
      if (!englishName) {
        stats.skipped += 1;
        return;
      }
      const hindiName = await generateHindiName(englishName, converter ? { converter } : undefined);
      if (!hindiName || isBrokenHindiName(hindiName)) {
        stats.failed += 1;
        stats.failedItems.push({ id: String(doc._id), name: englishName });
        return;
      }
      const update = { nameHindi: hindiName, nameHindiSource: HINDI_NAME_SOURCES.AUTO };
      if (model.schema.path('searchTextHindi')) update.searchTextHindi = normalizeSearchText(hindiName);
      const result = await model.updateOne(
        { _id: doc._id, nameHindi: doc.nameHindi ?? { $in: [null, ''] } },
        { $set: update },
      );
      if (result.modifiedCount > 0) stats.updated += 1;
      else stats.skipped += 1;
    }));
  }
  return stats;
}

// Fire-and-forget generation right after a save; never blocks or fails the request.
function scheduleHindiNameFill(model, id) {
  if (!id) return;
  setImmediate(() => {
    fillHindiNames(model, { mode: 'repair', ids: [id] })
      .catch((error) => logger.warn(`[HindiNames] background fill failed: ${error.message}`));
  });
}

module.exports = {
  convertWords,
  generateHindiName,
  fillHindiNames,
  scheduleHindiNameFill,
};
