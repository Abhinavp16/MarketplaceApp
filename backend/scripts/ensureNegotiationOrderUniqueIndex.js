require('dotenv').config();
const mongoose = require('mongoose');
const Order = require('../src/models/Order');

async function run() {
  mongoose.set('autoIndex', false);
  await mongoose.connect(process.env.MONGODB_URI);

  const duplicates = await Order.aggregate([
    { $match: { negotiationId: { $type: 'objectId' } } },
    { $group: { _id: '$negotiationId', count: { $sum: 1 }, orderIds: { $push: '$_id' } } },
    { $match: { count: { $gt: 1 } } },
    { $limit: 20 },
  ]);

  if (duplicates.length > 0) {
    console.error('Cannot create unique negotiation order index: duplicate orders exist.');
    for (const duplicate of duplicates) {
      console.error(`${duplicate._id}: ${duplicate.orderIds.join(', ')}`);
    }
    process.exitCode = 1;
    return;
  }

  const indexes = await Order.collection.indexes();
  const existing = indexes.find((index) => index.key?.negotiationId === 1);
  const desiredPartialFilter = { negotiationId: { $type: 'objectId' } };
  if (existing?.unique && JSON.stringify(existing.partialFilterExpression) === JSON.stringify(desiredPartialFilter)) {
    console.log('Unique partial negotiationId index already exists.');
    return;
  }

  if (existing) await Order.collection.dropIndex(existing.name);
  try {
    await Order.collection.createIndex(
      { negotiationId: 1 },
      {
        name: 'negotiationId_1',
        unique: true,
        partialFilterExpression: desiredPartialFilter,
      },
    );
  } catch (error) {
    if (existing) {
      await Order.collection.createIndex(existing.key, {
        name: existing.name,
        sparse: Boolean(existing.sparse),
      });
    }
    throw error;
  }
  console.log('Created unique partial negotiationId index.');
}

run()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
