const assert = require('assert');
const {
  describePack,
  getPackInfo,
  getPackSize,
  getMinimumCustomerQuantity,
  getMinimumWholesaleQuantity,
  isWholePacks,
  roundUpToWholesaleQuantity,
} = require('../src/utils/packSize');

const pipe = { priceUnit: 'Packet', packing: '15', minWholesaleQuantity: 1 };

// Packet + plain piece count = priced per piece, sold in packets.
assert.strictEqual(getPackSize(pipe), 15);
assert.strictEqual(getPackSize({ priceUnit: 'packet', packing: '15 pcs' }), 15);
assert.strictEqual(getPackSize({ priceUnit: 'Pack', packing: '10 Nos.' }), 10);

// Everything else keeps a pack size of 1 (unchanged behaviour).
assert.strictEqual(getPackSize({ priceUnit: 'Packet', packing: '25 pcs/bag; 150 pcs/box' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Packet', packing: '1' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Packet', packing: '' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Piece', packing: '20' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Mtr', packing: '500' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Bundle', packing: '3 bundles' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Bundle', packing: '1' }), 1);
assert.strictEqual(getPackSize({ priceUnit: 'Bundle', packing: '5' }), 1); // no "m": priced per bundle

// Coil / Bundle + length in meters = priced per meter, sold by the coil/bundle.
assert.deepStrictEqual(getPackInfo({ priceUnit: 'Coil', packing: '500 m' }), { size: 500, packUnit: 'coil', contentUnit: 'meter' });
assert.strictEqual(getPackSize({ priceUnit: 'Coil', packing: '500' }), 500);
assert.strictEqual(getPackSize({ priceUnit: 'coil', packing: '500 mtrs' }), 500);
assert.deepStrictEqual(getPackInfo({ priceUnit: 'Bundle', packing: '300 m' }), { size: 300, packUnit: 'bundle', contentUnit: 'meter' });
assert.strictEqual(getPackSize({ priceUnit: 'Bundle', packing: '500mtr' }), 500);
assert.strictEqual(getPackSize({ priceUnit: 'Bundle', packing: '200 Meters' }), 200);
assert.strictEqual(getPackSize({ priceUnit: 'Bundle', packing: '500 mors' }), 1);
assert.deepStrictEqual(getPackInfo({ priceUnit: 'Packet', packing: '15' }), { size: 15, packUnit: 'packet', contentUnit: 'piece' });
assert.deepStrictEqual(getPackInfo({ priceUnit: 'Mtr', packing: '500' }), { size: 1, packUnit: null, contentUnit: null });

assert.strictEqual(describePack({ priceUnit: 'Coil', packing: '500 m' }), 'coils of 500 m');
assert.strictEqual(describePack({ priceUnit: 'Packet', packing: '15' }), 'packets of 15 pieces');

// Customers: loose pieces / cut lengths, at least the admin's minimum.
assert.strictEqual(getMinimumCustomerQuantity({ minCustomerQuantity: 10 }), 10);
assert.strictEqual(getMinimumCustomerQuantity({}), 1);
assert.strictEqual(getMinimumCustomerQuantity({ minCustomerQuantity: 0 }), 1);

// Bundle minimum is in bundles, converted to meters.
assert.strictEqual(getMinimumWholesaleQuantity({ priceUnit: 'Bundle', packing: '500 m', minWholesaleQuantity: 1 }), 500);
assert.strictEqual(isWholePacks({ priceUnit: 'Bundle', packing: '500 m' }, 1000), true);
assert.strictEqual(isWholePacks({ priceUnit: 'Bundle', packing: '500 m' }, 750), false);
assert.strictEqual(getPackSize({}), 1);

// Wholesaler minimum is in packets, converted to pieces.
assert.strictEqual(getMinimumWholesaleQuantity(pipe), 15);
assert.strictEqual(getMinimumWholesaleQuantity({ ...pipe, minWholesaleQuantity: 2 }), 30);
assert.strictEqual(getMinimumWholesaleQuantity({ priceUnit: 'Piece', minWholesaleQuantity: 8 }), 8);
assert.strictEqual(getMinimumWholesaleQuantity({ priceUnit: 'Piece', minWholesaleQuantity: null }), 1);
assert.strictEqual(getMinimumWholesaleQuantity({ priceUnit: 'Piece' }, 10), 10);

// Whole packets only.
assert.strictEqual(isWholePacks(pipe, 30), true);
assert.strictEqual(isWholePacks(pipe, 20), false);
assert.strictEqual(isWholePacks({ priceUnit: 'Piece' }, 7), true);

// Old carts (quantity 1 meaning "1 packet") are raised to a whole packet.
assert.strictEqual(roundUpToWholesaleQuantity(pipe, 1), 15);
assert.strictEqual(roundUpToWholesaleQuantity(pipe, 16), 30);
assert.strictEqual(roundUpToWholesaleQuantity(pipe, 45), 45);
assert.strictEqual(roundUpToWholesaleQuantity({ priceUnit: 'Piece', minWholesaleQuantity: 8 }, 3), 8);
assert.strictEqual(roundUpToWholesaleQuantity({ priceUnit: 'Piece', minWholesaleQuantity: 8 }, 9), 9);

console.log('packSize tests passed');
