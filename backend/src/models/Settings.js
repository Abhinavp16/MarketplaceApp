const mongoose = require('mongoose');
const BRAND = require('../config/brand');

const mandatoryUpdateMessage = `A new version of ${BRAND.name} is required. Please update the app to continue.`;

const mobilePlatformSchema = new mongoose.Schema({
  enabled: { type: Boolean, default: false },
  latestVersion: { type: String, trim: true, maxlength: 50, default: '' },
  latestBuildNumber: { type: Number, min: 0, default: 0 },
  storeUrl: {
    type: String,
    trim: true,
    required: true,
  },
  title: { type: String, trim: true, maxlength: 200, default: 'Update Required' },
  message: { type: String, trim: true, maxlength: 1000, default: mandatoryUpdateMessage },
}, { _id: false });

const settingsSchema = new mongoose.Schema({
  _id: {
    type: String,
    default: 'app_settings',
  },

  businessName: {
    type: String,
    default: BRAND.name,
  },
  businessPhone: String,
  businessEmail: String,
  businessAddress: String,

  upiId: {
    type: String,
    required: true,
  },
  upiDisplayName: {
    type: String,
    required: true,
  },

  minOrderAmount: {
    type: Number,
    default: 0,
  },
  defaultBulkMinQuantity: {
    type: Number,
    default: 10,
  },
  negotiationExpiryDays: {
    type: Number,
    default: 7,
  },
  lowStockThreshold: {
    type: Number,
    default: 5,
  },

  features: {
    negotiationsEnabled: { type: Boolean, default: true },
    guestCheckout: { type: Boolean, default: false },
    maintenanceMode: { type: Boolean, default: false },
  },

  mobileApp: {
    android: {
      type: mobilePlatformSchema,
      default: () => ({
        storeUrl: BRAND.storeUrls.android,
      }),
    },
    ios: {
      type: mobilePlatformSchema,
      default: () => ({
        storeUrl: BRAND.storeUrls.ios,
      }),
    },
  },

  heroBanners: [{
    title: { type: String, default: '' },
    subtitle: String,
    tag: String,
    imageUrl: String,
    // Video banners (hero only): button + link only, no title/desc overlay.
    mediaType: {
      type: String,
      enum: ['image', 'video_upload', 'youtube'],
      default: 'image',
    },
    videoUrl: String,
    linkUrl: String,
    buttonText: { type: String, default: 'Shop Now' },
    buttonIcon: { type: String, default: 'ArrowRight' },
    isActive: { type: Boolean, default: true },
    order: { type: Number, default: 0 },
  }],

  promoBanners: [{
    title: { type: String, required: true },
    subtitle: String,
    tag: String,
    imageUrl: String,
    linkUrl: String,
    buttonText: { type: String, default: 'Shop Now' },
    buttonIcon: { type: String, default: 'ArrowRight' },
    isActive: { type: Boolean, default: true },
    order: { type: Number, default: 0 },
  }],

  socialLinks: {
    whatsapp: String,
    instagram: String,
    facebook: String,
  },
  checkout: {
    mode: {
      type: String,
      enum: ['payment', 'whatsapp'],
      default: 'whatsapp',
    },
    orderWhatsappNumber: {
      type: String,
      default: '',
    },
    requireLoginForCheckout: {
      type: Boolean,
      default: true,
    },
    createOrderBeforeRedirect: {
      type: Boolean,
      default: true,
    },
    allowNegotiationCheckout: {
      type: Boolean,
      default: true,
    },
  },


  // Demo environment marker (written by the demo seed; drives /demo/info).
  demo: {
    seededAt: { type: Date, default: null },
    fixtureVersion: { type: String, default: null },
  },

  // Bank Transfer Details
  bankName: String,
  bankAccountNumber: String,
  bankIfscCode: String,
  bankAccountHolderName: String,
  bankTransferEnabled: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

settingsSchema.statics.getSettings = async function () {
  let settings = await this.findById('app_settings');
  
  if (!settings) {
    settings = await this.create({
      _id: 'app_settings',
      businessName: BRAND.name,
      businessPhone: BRAND.phone,
      businessEmail: BRAND.email,
      businessAddress: BRAND.address,
      upiId: process.env.DEFAULT_UPI_ID || 'demo@upi',
      upiDisplayName: process.env.DEFAULT_UPI_NAME || `${BRAND.name} Payments`,
      checkout: {
        mode: 'whatsapp',
        orderWhatsappNumber: process.env.PUBLIC_ORDER_WHATSAPP_NUMBER || '',
        requireLoginForCheckout: true,
        createOrderBeforeRedirect: true,
        allowNegotiationCheckout: true,
      },
    });
  }
  
  return settings;
};

module.exports = mongoose.model('Settings', settingsSchema);
