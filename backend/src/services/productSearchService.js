const categoryId = (category) => String(category?._id || category?.id || '');
const parentId = (category) => String(category?.parent?._id || category?.parent || '');
const legacyCategoryRegex = (value) => {
  const parts = String(value || '').trim().split(/[-_\s]+/).filter(Boolean);
  if (parts.length === 0) return null;
  const escaped = parts.map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  return new RegExp(`^${escaped.join('[-_\\s]+')}$`, 'i');
};

function collectCategoryScope(categories, rootId) {
  const byParent = new Map();
  const byId = new Map();

  for (const category of categories) {
    const id = categoryId(category);
    if (!id) continue;
    byId.set(id, category);
    const parent = parentId(category);
    if (!parent) continue;
    if (!byParent.has(parent)) byParent.set(parent, []);
    byParent.get(parent).push(category);
  }

  const root = byId.get(String(rootId));
  if (!root) return [];

  const result = [];
  const visited = new Set();
  const queue = [root];
  while (queue.length > 0) {
    const category = queue.shift();
    const id = categoryId(category);
    if (!id || visited.has(id)) continue;
    visited.add(id);
    result.push(category);
    queue.push(...(byParent.get(id) || []));
  }
  return result;
}

function pruneCategoriesWithInaccessibleAncestors(allCategories, accessibleCategories) {
  const allIds = new Set(allCategories.map(categoryId).filter(Boolean));
  const accessibleIds = new Set(accessibleCategories.map(categoryId).filter(Boolean));
  let changed = true;

  while (changed) {
    changed = false;
    for (const category of accessibleCategories) {
      const id = categoryId(category);
      const parent = parentId(category);
      if (accessibleIds.has(id) && parent && allIds.has(parent) && !accessibleIds.has(parent)) {
        accessibleIds.delete(id);
        changed = true;
      }
    }
  }

  return accessibleCategories.filter((category) => accessibleIds.has(categoryId(category)));
}

function buildCategoryScopeCondition(categories) {
  if (categories.length === 0) return { _id: { $in: [] } };

  const ids = categories.map((category) => category._id || category.id);
  const legacyByCompany = new Map();
  for (const category of categories) {
    const company = String(category.company?._id || category.company || '');
    if (!company) continue;
    const values = legacyByCompany.get(company) || new Set();
    if (category.name) values.add(category.name);
    if (category.slug) values.add(category.slug);
    legacyByCompany.set(company, values);
  }

  const legacyConditions = [...legacyByCompany.entries()].map(([company, values]) => {
    const categoryPatterns = [...values].map(legacyCategoryRegex).filter(Boolean);
    return {
      $and: [
        { $or: [{ categoryRef: null }, { categoryRef: { $exists: false } }] },
        {
          $or: [
            { company },
            { company: null },
            { company: { $exists: false } },
          ],
        },
        { category: { $in: categoryPatterns } },
      ],
    };
  });

  return {
    $or: [
      { categoryRef: { $in: ids } },
      ...legacyConditions,
    ],
  };
}

function categoryMatchesTerm(category, term) {
  const normalized = term.toLowerCase();
  return [category.name, category.nameHindi, category.slug]
    .filter(Boolean)
    .some((value) => String(value).toLowerCase().includes(normalized));
}

module.exports = {
  buildCategoryScopeCondition,
  categoryMatchesTerm,
  collectCategoryScope,
  pruneCategoriesWithInaccessibleAncestors,
};
