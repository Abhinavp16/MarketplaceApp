const assert = require('assert');

const {
  buildCategoryScopeCondition,
  categoryMatchesTerm,
  collectCategoryScope,
  pruneCategoriesWithInaccessibleAncestors,
} = require('../src/services/productSearchService');
const { productValidation } = require('../src/validations');

const categories = [
  { _id: 'root', name: 'Acme Power Cable', slug: 'power-cable', company: 'brand-a', parent: null },
  { _id: 'child', name: '4.0 sqmm', slug: 'power-cable-40-sqmm', company: 'brand-a', parent: 'root' },
  { _id: 'grandchild', name: 'Premium', slug: 'premium', company: 'brand-a', parent: 'child' },
  { _id: 'other', name: '4.0 sqmm', slug: 'other-40-sqmm', company: 'brand-b', parent: null },
];

const scope = collectCategoryScope(categories, 'root');
assert.deepStrictEqual(scope.map((item) => item._id), ['root', 'child', 'grandchild']);
assert.deepStrictEqual(collectCategoryScope(categories, 'missing'), []);
assert.deepStrictEqual(
  pruneCategoriesWithInaccessibleAncestors(categories, [categories[0], categories[2]])
    .map((item) => item._id),
  ['root'],
);
assert.strictEqual(categoryMatchesTerm(categories[0], 'acme'), true);
assert.strictEqual(categoryMatchesTerm(categories[1], '40-sqmm'), true);

const condition = buildCategoryScopeCondition(scope);
assert.deepStrictEqual(condition.$or[0], {
  categoryRef: { $in: ['root', 'child', 'grandchild'] },
});
assert.deepStrictEqual(condition.$or[1], {
  $and: [
    { $or: [{ categoryRef: null }, { categoryRef: { $exists: false } }] },
    {
      $or: [
        { company: 'brand-a' },
        { company: null },
        { company: { $exists: false } },
      ],
    },
    {
      category: {
        $in: [
          /^Acme[-_\s]+Power[-_\s]+Cable$/i,
          /^power[-_\s]+cable$/i,
          /^4\.0[-_\s]+sqmm$/i,
          /^power[-_\s]+cable[-_\s]+40[-_\s]+sqmm$/i,
          /^Premium$/i,
          /^premium$/i,
        ],
      },
    },
  ],
});

const cycleScope = collectCategoryScope([
  { _id: 'a', parent: 'b' },
  { _id: 'b', parent: 'a' },
], 'a');
assert.deepStrictEqual(cycleScope.map((item) => item._id), ['a', 'b']);

const validSearch = productValidation.search.validate({
  q: '',
  categoryId: '6a33d6318d0d58faca6d399e',
  brandId: '6aaa50124f86acc48e8acb07',
});
assert.strictEqual(validSearch.error, undefined);
assert.ok(productValidation.search.validate({ categoryId: 'not-an-id' }).error);

console.log('Product search service tests passed');
