const mongoose = require('mongoose');
const { ANALYTICS_EVENTS, ANALYTICS_SOURCES } = require('../utils/constants');

const analyticsSchema = new mongoose.Schema({
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },

  eventType: {
    type: String,
    enum: Object.values(ANALYTICS_EVENTS),
    required: true,
  },

  source: {
    type: String,
    enum: Object.values(ANALYTICS_SOURCES),
    default: ANALYTICS_SOURCES.DIRECT,
  },
  sessionId: String,
  deviceInfo: {
    platform: String,
    appVersion: String,
    deviceModel: String,
  },

  // Indexed only by the TTL index below (a plain index on the same key would
  // stop MongoDB from creating the TTL index, so old rows never expired).
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

analyticsSchema.index({ productId: 1, eventType: 1, timestamp: -1 });
analyticsSchema.index({ timestamp: 1 }, { expireAfterSeconds: 7776000 }); // 90 days
analyticsSchema.index({ eventType: 1, timestamp: -1 });
analyticsSchema.index({ userId: 1, timestamp: -1 }, { sparse: true });

module.exports = mongoose.model('Analytics', analyticsSchema);
