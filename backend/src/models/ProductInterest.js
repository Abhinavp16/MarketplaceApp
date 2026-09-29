const mongoose = require('mongoose');
const { LEAD_RETENTION_DAYS } = require('../utils/leadInterest');

// One document per person + product, used for the admin Leads page.
// Repeat views increase viewCount/totalWatchSeconds instead of adding rows.
const productInterestSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true,
  },
  viewCount: { type: Number, default: 0, min: 0 },
  totalWatchSeconds: { type: Number, default: 0, min: 0 },
  firstViewedAt: { type: Date, default: Date.now },
  lastViewedAt: { type: Date, default: Date.now },
  lastCartAddAt: { type: Date, default: null },
}, {
  timestamps: true,
});

productInterestSchema.index({ userId: 1, productId: 1 }, { unique: true });
// Leads expire LEAD_RETENTION_DAYS after the last view; a re-view extends it.
productInterestSchema.index(
  { lastViewedAt: 1 },
  { expireAfterSeconds: LEAD_RETENTION_DAYS * 24 * 60 * 60 },
);

module.exports = mongoose.model('ProductInterest', productInterestSchema);
