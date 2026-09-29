const mongoose = require('mongoose');

const PRICE_CHANGE_AUDIT_STATUSES = ['scheduled', 'applied', 'superseded'];
const PRICE_CHANGE_SCHEDULE_TYPES = [
  'immediate',
  'schedule_24h',
  'schedule_48h',
  'custom',
];

const priceChangeAuditSchema = new mongoose.Schema({
  product: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true,
    index: true,
  },
  productName: {
    type: String,
    required: true,
    trim: true,
  },
  productSku: {
    type: String,
    default: '',
    trim: true,
  },
  category: {
    type: String,
    default: '',
    trim: true,
  },
  performedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  performedByName: {
    type: String,
    default: '',
    trim: true,
  },
  previousRetailPrice: {
    type: Number,
    required: true,
    min: 0,
  },
  newRetailPrice: {
    type: Number,
    default: null,
    min: 0,
  },
  previousWholesalePrice: {
    type: Number,
    required: true,
    min: 0,
  },
  newWholesalePrice: {
    type: Number,
    default: null,
    min: 0,
  },
  scheduleType: {
    type: String,
    enum: PRICE_CHANGE_SCHEDULE_TYPES,
    required: true,
  },
  scheduledAt: {
    type: Date,
    required: true,
  },
  effectiveAt: {
    type: Date,
    required: true,
  },
  status: {
    type: String,
    enum: PRICE_CHANGE_AUDIT_STATUSES,
    required: true,
    default: 'scheduled',
    index: true,
  },
  appliedAt: {
    type: Date,
    default: null,
  },
  supersededAt: {
    type: Date,
    default: null,
  },
  supersededBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'PriceChangeAudit',
    default: null,
  },
}, { timestamps: true });

priceChangeAuditSchema.index({ product: 1, createdAt: -1 });
priceChangeAuditSchema.index({ status: 1, effectiveAt: 1 });

module.exports = mongoose.model('PriceChangeAudit', priceChangeAuditSchema);
