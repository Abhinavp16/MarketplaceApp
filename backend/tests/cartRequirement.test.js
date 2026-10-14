const assert = require('assert');
const { planCartRequirement, describeCartRequirement } = require('../src/utils/cartRequirement');

const pipe = { name: 'GI Pipe', negotiationEnabled: true, minWholesaleQuantity: 10 };
const cable = { name: 'Cable', negotiationEnabled: true, minWholesaleQuantity: 1 };
const noDeal = { name: 'Panel', negotiationEnabled: false, minWholesaleQuantity: 1 };

// Every valid item becomes a line with its cart quantity.
{
  const { lines, problems } = planCartRequirement(
    [{ productId: 'a', quantity: 10 }, { productId: 'b', quantity: 3 }],
    { a: pipe, b: cable },
  );
  assert.deepStrictEqual(problems, []);
  assert.deepStrictEqual(lines.map((line) => [line.product.name, line.quantity]), [['GI Pipe', 10], ['Cable', 3]]);
}

// Missing products, negotiation turned off and quantities below the wholesale
// minimum are reported (the controller then sends nothing).
{
  const { lines, problems } = planCartRequirement(
    [
      { productId: 'gone', quantity: 1 },
      { productId: 'c', quantity: 1 },
      { productId: 'a', quantity: 5 },
      { productId: 'b', quantity: 1 },
    ],
    { a: pipe, b: cable, c: noDeal },
  );
  assert.deepStrictEqual(problems.map((problem) => problem.code), [
    'PRODUCT_NOT_FOUND',
    'NEGOTIATION_DISABLED',
    'MIN_WHOLESALE_QUANTITY_NOT_MET',
  ]);
  assert.strictEqual(problems[1].name, 'Panel');
  assert.strictEqual(lines.length, 1);
}

// Packet products: minimum is in packets and only whole packets can be sent.
{
  const pack = { name: 'Column Pipe', negotiationEnabled: true, minWholesaleQuantity: 1, priceUnit: 'Packet', packing: '15' };
  assert.deepStrictEqual(planCartRequirement([{ productId: 'p', quantity: 30 }], { p: pack }).problems, []);
  assert.deepStrictEqual(
    planCartRequirement([{ productId: 'p', quantity: 1 }, { productId: 'q', quantity: 20 }], { p: pack, q: pack })
      .problems.map((problem) => problem.code),
    ['MIN_WHOLESALE_QUANTITY_NOT_MET', 'PACK_QUANTITY_REQUIRED'],
  );
}

// A missing or invalid minimum counts as 1.
{
  const { problems } = planCartRequirement(
    [{ productId: 'x', quantity: 1 }],
    { x: { name: 'X', negotiationEnabled: true, minWholesaleQuantity: null } },
  );
  assert.deepStrictEqual(problems, []);
}

// Admin notification text: one product vs several.
{
  const single = describeCartRequirement('Rohan', [{ negotiationNumber: 'NGT-1', productName: 'Cable', quantity: 2 }]);
  assert.strictEqual(single.title, 'New deal request NGT-1');
  assert.strictEqual(single.body, 'Rohan sent a requirement from the cart: 2 × Cable.');

  const many = describeCartRequirement(null, [
    { negotiationNumber: 'NGT-1', productName: 'A', quantity: 1 },
    { negotiationNumber: 'NGT-2', productName: 'B', quantity: 2 },
    { negotiationNumber: 'NGT-3', productName: 'C', quantity: 3 },
    { negotiationNumber: 'NGT-4', productName: 'D', quantity: 4 },
    { negotiationNumber: 'NGT-5', productName: 'E', quantity: 5 },
  ]);
  assert.strictEqual(many.title, '5 new deal requests from cart');
  assert.strictEqual(many.body, 'A wholesaler sent a requirement from the cart: 1 × A, 2 × B, 3 × C and 2 more.');
}

console.log('cartRequirement tests passed');
