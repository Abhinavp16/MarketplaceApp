const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { USER_ROLES, AUTH_PROVIDERS } = require('../utils/constants');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true,
    maxlength: [100, 'Name cannot exceed 100 characters'],
  },
  email: {
    type: String,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true,
    match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
  },
  phone: {
    type: String,
    unique: true,
    sparse: true,
    trim: true,
  },
  address: {
    type: String,
    default: null,
    trim: true,
  },
  avatar: {
    type: String,
    default: null,
  },

  authProvider: {
    type: String,
    enum: Object.values(AUTH_PROVIDERS),
    required: true,
    default: AUTH_PROVIDERS.EMAIL,
  },
  googleId: {
    type: String,
  },
  passwordHash: {
    type: String,
    select: false,
  },
  username: {
    type: String,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true,
    match: [/^[a-z0-9._-]{3,32}$/, 'Username must be 3-32 characters using letters, numbers, dot, underscore, or hyphen'],
  },
  mustChangePassword: {
    type: Boolean,
    default: false,
  },

  role: {
    type: String,
    enum: Object.values(USER_ROLES),
    default: USER_ROLES.BUYER,
  },

  // App language chosen by the customer; used for push/in-app notifications.
  preferredLanguage: {
    type: String,
    enum: ['en', 'hi'],
    default: 'en',
  },

  businessInfo: {
    businessName: { type: String, default: null },
    gstNumber: { type: String, default: null },
    businessAddress: { type: String, default: null },
    contactPerson: { type: String, default: null },
    shopLocation: {
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      placeLabel: { type: String, default: null },
      capturedAt: { type: Date, default: null },
    },
    status: { 
      type: String, 
      enum: ['none', 'pending', 'accepted', 'rejected'], 
      default: 'none' 
    },
    verified: { type: Boolean, default: false },
    verifiedAt: { type: Date, default: null },
    excludedCategories: [{ type: String, trim: true }],
    // Private Firebase object keys. These are never returned to mobile clients.
    proofImageKeys: [{ type: String }],
    // Legacy public URLs retained only until the reviewed migration completes.
    proofImages: [{ type: String }],
  },

  fcmTokens: [{
    type: String,
  }],

  phoneVerified: {
    type: Boolean,
    default: false,
  },
  marketingConsent: {
    type: Boolean,
    default: false,
  },
  consentTimestamp: {
    type: Date,
    default: null,
  },
  termsAcceptedAt: {
    type: Date,
    default: null,
  },
  termsVersion: {
    type: String,
    default: null,
  },
  privacyPolicyAcceptedAt: {
    type: Date,
    default: null,
  },
  privacyPolicyVersion: {
    type: String,
    default: null,
  },

  isActive: {
    type: Boolean,
    default: true,
  },
  lastLoginAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

userSchema.index({ role: 1 });
userSchema.index({ googleId: 1 }, { sparse: true });
userSchema.index({ 'businessInfo.businessName': 'text' });

userSchema.pre('save', async function (next) {
  if (!this.isModified('passwordHash') || !this.passwordHash) {
    return next();
  }

  const salt = await bcrypt.genSalt(12);
  this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
  next();
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.passwordHash);
};

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.passwordHash;
  delete obj.__v;
  if (obj.businessInfo) {
    delete obj.businessInfo.proofImageKeys;
  }
  return obj;
};

module.exports = mongoose.model('User', userSchema);
