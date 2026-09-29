const mongoose = require('mongoose');

const magicLinkTokenSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    index: true,
  },
  tokenHash: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  expiresAt: {
    type: Date,
    required: true,
  },
  used: {
    type: Boolean,
    default: false,
  },
  deliveredAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

// Auto-delete expired tokens
magicLinkTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('MagicLinkToken', magicLinkTokenSchema);
