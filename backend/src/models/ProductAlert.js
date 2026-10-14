const mongoose = require('mongoose');

// "Notify me when available" on a coming-soon product. One per user and
// product; notifiedAt is set when the launch notification has been sent.
const productAlertSchema = new mongoose.Schema({
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
  notifiedAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

productAlertSchema.index({ userId: 1, productId: 1 }, { unique: true });
productAlertSchema.index({ productId: 1, notifiedAt: 1 });

module.exports = mongoose.model('ProductAlert', productAlertSchema);
