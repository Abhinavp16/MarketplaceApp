const mongoose = require('mongoose');

const ADMIN_NOTIFICATION_TYPES = [
  'order_created',
  'payment_submitted',
  'negotiation_created',
  'negotiation_message',
  'negotiation_countered',
  'negotiation_accepted',
  'negotiation_rejected',
  'stock_low',
  'account_deletion_requested',
  'wholesaler_application',
  'general',
];

const ADMIN_NOTIFICATION_SEVERITIES = ['info', 'warning', 'urgent'];

const adminNotificationSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Notification title is required'],
    trim: true,
    maxlength: [140, 'Title cannot exceed 140 characters'],
  },
  body: {
    type: String,
    required: [true, 'Notification body is required'],
    trim: true,
    maxlength: [500, 'Body cannot exceed 500 characters'],
  },
  type: {
    type: String,
    enum: ADMIN_NOTIFICATION_TYPES,
    default: 'general',
    index: true,
  },
  severity: {
    type: String,
    enum: ADMIN_NOTIFICATION_SEVERITIES,
    default: 'info',
  },
  // Deep link inside the admin panel, e.g. "/orders/abc123".
  link: {
    type: String,
    default: null,
    trim: true,
  },
  actor: {
    id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    name: { type: String, default: '' },
    role: { type: String, default: '' },
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
  // Admin user ids that have read this notification.
  readBy: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  }],
}, {
  timestamps: true,
});

adminNotificationSchema.index({ createdAt: -1 });
adminNotificationSchema.index({ type: 1, createdAt: -1 });

module.exports = mongoose.model('AdminNotification', adminNotificationSchema);
module.exports.ADMIN_NOTIFICATION_TYPES = ADMIN_NOTIFICATION_TYPES;
module.exports.ADMIN_NOTIFICATION_SEVERITIES = ADMIN_NOTIFICATION_SEVERITIES;
