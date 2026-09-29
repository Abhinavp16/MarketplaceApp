const mongoose = require('mongoose');

const priceChangeCampaignSchema = new mongoose.Schema(
  {
    status: {
      type: String,
      enum: ['active', 'completed'],
      default: 'active',
      index: true,
    },
    startAt: {
      type: Date,
      required: true,
    },
    effectiveAt: {
      type: Date,
      required: true,
      index: true,
    },
    includedProductIds: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Product',
      },
    ],
    representativeProductIds: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Product',
      },
    ],
    sentStages: [
      {
        type: String,
      },
    ],
    completedAt: {
      type: Date,
      default: null,
    },
    lastMergedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

priceChangeCampaignSchema.index({ status: 1, effectiveAt: 1 });

module.exports = mongoose.model('PriceChangeCampaign', priceChangeCampaignSchema);
