const mongoose = require('mongoose');

// Immediate price changes waiting to be announced to app users. Saves are
// collected into one pending batch and sent as a single notification once
// the admin has stopped saving for a while (services/priceChangeNotificationService).
const priceChangeNotificationBatchSchema = new mongoose.Schema({
  status: {
    type: String,
    enum: ['pending', 'sending', 'sent'],
    default: 'pending',
  },
  firstChangeAt: { type: Date, required: true },
  lastChangeAt: { type: Date, required: true },
  // Products whose customer price / wholesale price changed.
  retailProductIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Product' }],
  wholesaleProductIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Product' }],
  claimedAt: { type: Date, default: null },
  sentAt: { type: Date, default: null },
  // What went out: products announced and users reached per group.
  sentSummary: {
    customers: { products: Number, users: Number },
    wholesalers: { products: Number, users: Number },
  },
}, {
  timestamps: true,
});

// At most one batch collects changes at a time.
priceChangeNotificationBatchSchema.index(
  { status: 1 },
  { unique: true, partialFilterExpression: { status: 'pending' } },
);
priceChangeNotificationBatchSchema.index({ status: 1, lastChangeAt: 1 });

module.exports = mongoose.model('PriceChangeNotificationBatch', priceChangeNotificationBatchSchema);
