const { USER_ROLES } = require('./constants');

const escapeRegex = (value = '') => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const normalizeCategoryKey = (value = '') => String(value || '')
  .trim()
  .replace(/[-_]+/g, ' ')
  .replace(/\s+/g, ' ')
  .toLowerCase();

const slugifyCategoryKey = (value = '') => normalizeCategoryKey(value)
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/(^-|-$)/g, '');

const getWholesalerExcludedCategories = (user = {}) => {
  if (user?.role !== USER_ROLES.WHOLESALER) return [];
  const values = user?.businessInfo?.excludedCategories;
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map((value) => String(value || '').trim()).filter(Boolean))];
};

const getCategoryAccessKeys = (value = '') => {
  const raw = String(value || '').trim();
  const normalized = normalizeCategoryKey(raw);
  const slug = slugifyCategoryKey(raw);
  return [...new Set([raw.toLowerCase(), normalized, slug].filter(Boolean))];
};

const isCategoryExcludedForUser = (user = {}, category = '') => {
  const excluded = getWholesalerExcludedCategories(user);
  if (excluded.length === 0) return false;

  const categoryKeys = new Set(getCategoryAccessKeys(category));
  return excluded.some((item) => getCategoryAccessKeys(item).some((key) => categoryKeys.has(key)));
};

const buildExcludedCategoryRegexes = (user = {}) => {
  const excluded = getWholesalerExcludedCategories(user);
  const values = excluded.flatMap((item) => {
    const raw = String(item || '').trim();
    return [raw, normalizeCategoryKey(raw), slugifyCategoryKey(raw)];
  }).filter(Boolean);

  return [...new Set(values)].map((value) => new RegExp(`^${escapeRegex(value)}$`, 'i'));
};

const applyCategoryAccessToProductQuery = (query = {}, user = {}) => {
  const regexes = buildExcludedCategoryRegexes(user);
  if (regexes.length === 0) return query;

  query.$nor = [
    ...(Array.isArray(query.$nor) ? query.$nor : []),
    ...regexes.map((regex) => ({ category: regex })),
  ];
  return query;
};

const filterCategoriesForUser = (categories = [], user = {}) => (
  categories.filter((category) => !isCategoryExcludedForUser(user, category?.name || category?.slug || category?._id))
);

module.exports = {
  normalizeCategoryKey,
  slugifyCategoryKey,
  getWholesalerExcludedCategories,
  isCategoryExcludedForUser,
  applyCategoryAccessToProductQuery,
  filterCategoriesForUser,
};
